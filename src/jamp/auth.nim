import std/[
  httpcore,
  base64
]

##[
  Contains implementations for different forms of authentication. These can be used with the 
  client to specify how you want the client to authenticate with the server
]##

# This seems needlessly complex, TODO: Remember the reason I did this

type
  AuthHandler* = proc (headers: var HttpHeaders)
    ## Proc which gets ran before every request.
    ## Gets passed headers which should be modified to authenticate the request


proc basicAuth*(username, password: string): AuthHandler =
  ## Authenticate using HTTP basic auth
  let authValue = "Basic " & encode(username & ":" & password)
  result = proc (headers: var HttpHeaders) =
    headers["Authorization"] = authValue


proc bearerAuth*(token: string): AuthHandler =
  ## Authenticate using HTTP bearer token
  let authValue = "Bearer " & token
  result = proc (headers: var HttpHeaders) =
    headers["Authorization"] = authValue
