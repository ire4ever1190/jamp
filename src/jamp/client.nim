import std/[
  asyncdispatch,
  httpclient,
  json,
  tables,
  strutils,
  jsonutils,
  uri,
  asyncstreams,
  streams,
  importutils,
  net,
  asyncnet,
  strscans
]

import common, auth, utils


type
  BaseJMAPClient[T: HttpClient or AsyncHttpClient] = ref object
    ## Stores the information about the connection to the server
    http: T
    session*: Session
    host*: string
    auth: AuthHandler

  JMAPClient*      = BaseJMApClient[HttpClient]
  AsyncJMAPClient* = BaseJMAPClient[AsyncHttpClient]

template obj[T: ref object](x: typedesc[T]): untyped = typeof(x()[])


proc `=destroy`(client: var JMAPClient.obj) =
  client.http.close()

proc `=destroy`(client: var AsyncJMAPClient.obj) =
  client.http.close()


const userAgent = "Jamp/0.1.0"

proc newBaseClient[T](auth: AuthHandler, host: string): BaseJMAPClient[T] =
  result = new BaseJMAPClient[T]
  result.auth = auth
  var defaultHeaders = newHttpHeaders {
    "Content-Type": "application/json"
  }
  auth(defaultHeaders)
  result.http = when T is HttpClient:
      newHttpClient(userAgent, headers = defaultHeaders)
    else:
      newAsyncHttpClient(userAgent, headers = defaultHeaders)
  result.host = host

proc newJMAPClient*(auth: AuthHandler, hostname: string): JMAPClient =
  ## Creates a new JMAP client. If hostname is left blank then it
  ## will try and auto discover the hostname (This may fail)
  result = newBaseClient[HttpClient](auth, hostname)

proc newAsyncHttpClient*(auth: AuthHandler, hostname: string): AsyncJMAPClient =
  ## see newJMAPClient_
  result = newBaseClient[AsyncHttpClient](auth, hostname)


proc startSession*(client: JMAPClient | AsyncJMAPClient, insecure=false) {.multisync.} =
  ## Creates the session to the server.
  ## Must be called before anything else so that the client is
  ## authenticated.
  ##
  ## * **insecure**: Make this true to use http instead of https. Only recommended for testing against local server
  let resp = await client.http.request(
    (if insecure: "http://" else: "https://") & client.host & "/.well-known/jmap",
  )
  if resp.code.is2xx:
    try:
      client.session = resp.body.await().parseJson().to(Session)
    except JsonParsingError:
      raise (ref IOError)(msg: await resp.body)
  elif resp.code == Http401:
    raise (ref JMapError)(msg: "Auth details are incorrect")
  else:
    raise (ref JMapError)(msg: await resp.body)

func `$`*(req: JMAPRequest): string =
  req.toJson().pretty()

func pretty*(resp: JMAPResponse): string =
  resp.toJson().pretty()

proc checkResp(resp: Response | AsyncResponse): Future[JsonNode] {.multisync.} =
  ## Checks a JMAP response that it had no errors. If nothing fails
  ## then it returns the JSON stored in the response. If something went
  ## wrong then it throws a JMAP exception
  let body = await resp.body
  if resp.code.is2xx:
    result = body.parseJson()
  elif resp.code == Http401:
    raise (ref AuthorisationError)(msg: "Authorisation required, check details are correct")
  elif resp.isJson():
    ## Get better error message stored inside
    let json = body.parseJson()
    raise (ref JMAPError)(msg: json["detail"].str & "\n" & json.pretty())
  else:
    ## Likely isn't json so just use the body as the exception
    raise (ref JMAPError)(msg: $resp.code & " " & body)

proc hasSession*(client: BaseJMAPClient): bool =
  ## Returns true if the client has a current session
  client.session.state != ""

proc request*(client: JMAPClient | AsyncJMAPClient, req: JMAPRequest): Future[JMAPResponse] {.multisync.} =
  ## Perform a raw request to the JMAP server
  assert client.hasSession(), "Session doesn't exist. You might've forgotten to call startSession()"
  # Add auth info
  echo $req.toJson(
      ToJsonOptions(enumMode: joptEnumString)
    )
  let resp = await client.http.request(
    client.session.apiUrl,
    HttpPost,
    body = $req.toJson(
      ToJsonOptions(enumMode: joptEnumString)
    )
  )
  # Check the response
  if resp.code.is2xx:
    let j = resp.body.await().parseJson()
    result.fromJson(j, JOptions(
      allowExtraKeys: true,
      allowMissingKeys: true
    ))
  elif resp.code == Http401:
    raise (ref JMAPError)(msg: "Authorization required, check details are correct")
  elif resp.isJson():
    # If its JSON then we can get a better error msg
    let j = resp.body.await().parseJson()
    raise (ref JMAPError)(msg: j["detail"].str)
  else:
    raise (ref JMAPError)(msg: await resp.body)

proc request*[T](client: JMAPClient | AsyncJMAPClient, call: Call[T]): Future[T] {.multisync.} =
  ## Simplifer version of request which works for a single call.
  ## Recommended to use `proc request[T](JMAPClient, seq[Call[T]]): JMAPResponse`_ over this if making multiple
  ## requests
  var req: JMAPRequest
  req &= call
  let resp = client.request(req)
  return resp[call]

type
  EventHandler* = proc (event: string, changed: StateChange)

proc streamEvents*(client: JMAPClient | AsyncJMAPClient, handler: EventHandler) {.multisync.} =
  let url = client.session.eventSourceUrl.multiReplace({
    "{types}": "*",
    "{closeafter}": "no",
    "{ping}": "5"
  })
  # We use a new client so it wont interfere with any other API calls
  let streamClient = newHttpClient(headers = client.http.headers)
  defer: close streamClient
  # We want to handle body streaming ourselves (Normal HTTP client doesn't support streaming)
  privateAccess(typeof(client.http))
  streamClient.getBody = false
  let resp = streamClient.request(url)
  # TODO: Support non chunked
  doAssert resp.headers
    .getOrDefault("Transfer-Encoding") == "chunked", "JAMP currently only supports chunked streams"
  var
    lastID = "" # Last event ID. Send this on reconnect to get missed updates
    lastChange = StateChange() # Keep track of state. We only want to send diff to client

  when client is JMAPClient:
    while true:
      let chunkLengthLine = streamClient.socket.recvLine()
      if chunkLengthLine == "":
        # TODO: Perform reconnection
        break
      elif chunkLengthLine.isEmptyOrWhiteSpace:
        continue
      let chunkLength = chunkLengthLine.parseHexInt() + 2 # We want to read the \r\n at the end
      echo "Reading ", chunkLength
      let data = streamClient.socket.recv(chunkLength)
      # Now parse the event
      var
        currEvent = ""
        currData = ""
        emptyLines = 0
      for line in data.splitLines:
        if line.isEmptyOrWhiteSpace:
          inc emptyLines
          # Events end with two new lines
          if emptyLines < 2: continue
          if currData != "":
            currData.setLen(currData.len - 1) # Strip the final newline

          if currEvent in ["", "ping"]:
            continue
          # Get changes and then only run the handler for new types that have changed
          echo currData
          let changes = currData.parseJson()["changed"].to(StateChange)
          var
            newChanges = StateChange()
            someChange = false # We don't want to send empty update
          # Find the difference
          for account, changes in changes:
            if account notin lastChange: continue
            newChanges[account] = initTable[string, string]()
            for typ, state in changes:
              let oldState = lastChange[account].getOrDefault(typ, state)
              if oldState != state:
                # We send old state so the user can perform Foo/changes with it
                newChanges[account][typ] = oldState
                someChange = true
          lastChange = changes
          if someChange:
            handler(currEvent, newChanges)
          # Event handled, reset state
          currEvent.setLen(0)
          currData.setLen(0)
          emptyLines = 0
        else:
          emptyLines = 0
          let (ok, key, data) = line.scanTuple("$*: $*")
          assert ok, "Failed to parse event line: " & line
          case key
          of "event":
            currEvent = data
          of "id":
            lastID = key
          of "data":
            currData &= data & "\n"
          else:
            # Fastmail seems to have a line like
            # : new event source connection
            # Which I don't understand
            discard
proc downloadBlob*(client: JMAPClient | AsyncJMAPClient, accountID, blobID: string,
                  contentType = "file/any", name = "download"): Future[string] {.multisync.} =
  ## Used to download a blob.
  ## You shouldn't need to change the optional parameters
  let url = client.session.downloadUrl.multiReplace(
    ("{accountId}", accountID),
    ("{blobId}", blobID),
    ("{type}", contentType),
    ("{name}", name)
  )
  result = await client.http.getContent(url)

proc uploadBlob*(client: JMAPClient | AsyncJMAPClient, accountID, contentType, blob: string): Future[Blob] {.multisync.} =
  ## Uploads a blob of data to the server. If uploading a file from disk then use [uploadFile]
  let url = client.session.uploadUrl.replace("{accountId}", accountId)
  let resp = await client.http.request(url, HttpPost, blob, newHttpHeaders {
    "Content-Type": contentType
  })
  result.fromJson(await resp.checkResp())
    
export uri
