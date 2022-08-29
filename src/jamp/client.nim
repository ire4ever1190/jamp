import std/[
  asyncdispatch,
  httpclient,
  base64,
  json,
  tables,
  jsonutils,
  uri
]

import common, auth


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
  let defaultHeaders = newHttpHeaders {
    "Content-Type": "application/json"
  }
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


proc startSession*(client: JMAPClient | AsyncJMAPClient) {.multisync.} =
  ## Creates the session to the server.
  ## Must be called before anything else so that the client is
  ## authenticated
  let resp = await client.http.request("https://" & client.host & "/.well-known/jmap")
  try:
    client.session = resp.body.await().parseJson().to(Session)
  except JsonParsingError:
    raise (ref IOError)(msg: await resp.body)

func `$`*(req: JMAPRequest): string =
  req.toJson().pretty()


proc request*(client: JMAPClient | AsyncJMAPClient, req: JMAPRequest): Future[JMAPResponse] {.multisync.} =
  ## Perform a raw request to the JMAP server
  assert client.session.state != "", "Session doesn't exist. You might've forgotten to call startSession()"
  var extraHeaders = newHttpHeaders()
  client.auth(extraHeaders)
  let resp = await client.http.request(
    client.session.apiUrl,
    HttpPost,
    body = $req.toJson(),
    headers = extraHeaders
  )
  let body = await resp.body()
  if resp.code.is2xx:
    let j = resp.body.await().parseJson()
    result.fromJson(j, JOptions(
      allowExtraKeys: true,
      allowMissingKeys: false
    ))
  elif resp.headers["Content-Type"] == "application/json":
    # If its JSON then we can get a better error msg
    let j = resp.body.await().parseJson()
    raise (ref JMAPError)(msg: j["detail"].str)
  else:
    raise (ref JMAPError)(msg: body)

export uri
