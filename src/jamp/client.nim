import std/[
  asyncdispatch,
  httpclient,
  json,
  tables,
  strutils,
  jsonutils,
  uri
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
    raise (ref JMAPError)(msg: json["detail"].str)
  else:
    ## Likely isn't json so just use the body as the exception
    echo resp.headers
    raise (ref JMAPError)(msg: body)

proc request*(client: JMAPClient | AsyncJMAPClient, req: JMAPRequest): Future[JMAPResponse] {.multisync.} =
  ## Perform a raw request to the JMAP server
  assert client.session.state != "", "Session doesn't exist. You might've forgotten to call startSession()"
  # Add auth info
  when defined(jmapDebug):
    echo "Sending body: " & req.toJson().pretty()
  let resp = await client.http.request(
    client.session.apiUrl,
    HttpPost,
    body = $req.toJson()
  )
  when defined(jmapDebug):
    let body = await resp.body()
    echo "Got response: ", body
  # Check the response
  result.fromJson(await resp.checkResp(), JOptions(
    allowExtraKeys: true,
    allowMissingKeys: false
  ))

proc request*[T](client: JMAPClient | AsyncJMAPClient, call: Call[T]): Future[T] {.multisync.} =
  ## Simplifer version of request which works for a single call.
  ## Recommended to use `proc request[T](JMAPClient, seq[Call[T]]): JMAPResponse`_ over this if making multiple
  ## requests
  var req: JMAPRequest
  req &= call
  let resp = client.request(req)
  return resp[call]

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
