import std/[
  asyncdispatch,
  httpclient,
  base64,
  json,
  tables,
  jsonutils
]

import common


type
  BaseJMAPClient[T: HttpClient or AsyncHttpClient] = ref object
    ## Stores the information about the connection to the server 
    http: T 
    session: Session
    hostname, username*, password: string

  JMAPClient*      = BaseJMApClient[HttpClient]
  AsyncJMAPClient* = BaseJMAPClient[AsyncHttpClient]

template obj[T: ref object](x: typedesc[T]): untyped = typeof(x()[])

proc `=destroy`(client: var JMAPClient.obj) =
  client.http.close()
proc `=destroy`(client: var AsyncJMAPClient.obj) =
  client.http.close()


const userAgent = "Jamp/0.1.0"

proc newBaseClient[T](username, password: string, hostname = ""): BaseJMAPClient[T] =
  result = new BaseJMAPClient[T]
  result.username = username
  result.password = password
  let defaultHeaders = newHttpHeaders {
    "Authorization": "Basic " & encode(username & ":" & password),
    "Content-Type": "application/json"
  }
  result.http = when T is HttpClient:
      newHttpClient(userAgent, headers = defaultHeaders) 
    else:
      newAsyncHttpClient(userAgent, headers = defaultHeaders)
      
  if hostname != "":
    result.hostname = hostname

  
proc newJMAPClient*(username, password: string, hostname = ""): JMAPClient =
  ## Creates a new JMAP client. If hostname is left blank then it 
  ## will try and auto discover the hostname (This may fail)
  result = newBaseClient[HttpClient](username, password, hostname)

proc newAsyncHttpClient*(username, password: string, hostname = ""): AsyncJMAPClient =
  result = newBaseClient[AsyncHttpClient](username, password, hostname)

func url(client: BaseJMAPClient, path: string): string =
  ## Makes a URL with the clients hostname and a path.
  ## Path must be prefixed with /
  result = "https://"
  result &= client.hostname
  result &= path
  
proc startSession*(client: JMAPClient | AsyncJMAPClient) {.multisync.} =
  ## Creates the session to the server.
  ## Must be called before anything else so that the client is
  ## authenticated
  let resp = await client.http.request(client.url("/.well-known/jmap"))
  client.session = resp.body.await().parseJson().to(Session)

proc request*(client: JMAPClient | AsyncJMAPClient, req: JMAPRequest): Future[JMAPResponse] {.multisync.} =
  ## Perform a raw request to the JMAP server
  let resp = await client.http.request(client.session.apiUrl, HttpPost, body = $req.toJson())
  echo resp.body.await().parseJson().pretty()
