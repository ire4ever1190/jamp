import std/[
  json,
  tables,
  jsonutils,
  sets
]

import anano


type
  CoreCapabilities* = object
    ## See 'capabilites' section `here <https://jmap.io/spec-core.html#the-jmap-session-resource>`_
    maxSizeUpload*: uint
    maxConcurrentUpload*: uint
    maxSizeRequest*: uint
    maxCallsInRequest*: uint
    maxObjectsInGet*: uint
    maxObjectsInSet*: uint
    collationAlgorithms*: seq[string]

  Account* = object
    name*: string
    isPersonal*: bool
    isReadOnly*: bool
    accountCapabilities: Table[string, JsonNode]
    
  Session* = object
    username*: string
    apiUrl*: string
    downloadUrl*: string
    uploadUrl*: string
    eventSourceUrl*: string
    state*: string
    accounts*: Table[string, Account]
    capabilities*: Table[string, JsonNode]
    
  Invocation* = ref object
    ## An invocation represents a method call against the JMAP server
    name*: string
    arguments*: JsonNode
    id*: string

  Call*[T] = object
    ## Wrapper around Invocation_ that stores the needed
    ## capability and the type it returns
    needed*: string # Capabilty needed
    invocation*: Invocation
    

  JMAPRequest* = object
    `using`*: seq[string]
    methodCalls*: seq[Invocation]

  ResultReference* = ref object # Made ref so parameters can be nil
    resultOf*, name*, path*: string

  JMAPResponse* = object
    methodResponses*: seq[Invocation]
    sessionState*: string

  JMAPError* = object of CatchableError

  UnknownCapabilityError* = object of JMAPError
    ## The client included a capability in the “using” property of the request that the server does not support.

  LimitError* = object of JMAPError
    ## The request was not processed as it would have exceeded one of the request limits defined on the capability object.

  PathObject* = Table[string, JsonNode]
    ## Mapping of Json pointers to updated versions of the objects

const
  # from here https://jmap.io/spec-core.html#the-id-data-type 
  allowedIDCharacters = {'a'..'z'} + {'A'..'Z'} + {'0'..'9'} + {'-', '_'}

# Hooks
    
proc toJsonHook*(call: Invocation): JsonNode =
  result = newJArray()
  result &= %call.name
  result &= %call.arguments
  result &= %call.id

proc fromJsonHook*(call: var Invocation, data: JsonNode) =
  call = Invocation(
    name: data[0].str,
    arguments: data[1],
    id: data[2].str
  )

# Helpers

func add*(request: var JMAPRequest, call: Call) =
  ## Adds a call to the request.
  ## Automatically adds the needed capabilities to `using`
  runnableExamples:
    import jmap/specs/core
    var req: JMAPRequest
    # Build the request with your needed calls
    req &= Core.echo(%* {
      "foo": "bar"
    })
    req &= Core.echo(%* {
      "data": 9
    })
    # Send the request off with the client
  #==#
  if call.needed notin request.`using`:
    request.`using` &= call.needed
  request.methodCalls &= call.invocation

func `[]`*(resp: JMAPResponse, id: string): Table[string, JsonNode] =
  ## Gets the response data for an ID. If there are multiple responses for the
  ## method then all the returns values are joined together
  for invocation in resp.methodResponses:
    for key, value in invocation.arguments:
      result[key] = value

func id*(call: Call): string {.inline.} =
  ## Returns invocation ID
  result = call.invocation.id

func reuse*(inv: Invocation, path: string): ResultReference =
  ## Pass this has a parameter to a JMAP call and it will allow
  ## you to reuse value from previous call. See **TODO LINK JSONPTR MODULE** for information
  ## about path
  result = ResultReference(
    resultOf: inv.id,
    name: inv.name,
    path: path
  )

func reuse*(call: Call, path: string): ResultReference {.inline.} =
  ## Helper function for reuse_ for use with Call_
  result = call.invocation.reuse(path)

proc newInvocation*(name: string, args: sink JsonNode, id = ""): Invocation =
  ## Creates a new invocation.
  ## If you don't provide an ID then it will auto generate one.
  ## ID must only contain URL safe characters (A-Za-z0-9_-) and is recommended that it starts
  ## with an alpha character to be safe
  if id != "":
    # Check ID matches spec
    assert id.len >= 1 and id.len <= 255, "ID is too big"
    for c in id:
      assert c in allowedIDCharacters, "Invalid character '" & $c & "'"
        
  assert args.kind == JObject, "args must be a string: Json object"
  result = Invocation(
    name: name,
    arguments: args,
    
    id: if id != "": id else: ("i" & $genNanoID())
  )

func initCall*[T](needed, name: string, args: sink JsonNode, id = ""): Call[T] =
  ## Creates a new call.
  ##
  ## * **needed** is the capabilities needed by the server to perform the method
  result = Call[T](
    needed: needed,
    invocation: newInvocation(name, args, id)
  )
