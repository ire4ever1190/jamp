import std/[
  json,
  tables,
  jsonutils,
  sets,
  macros,
  options
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
    needed*: seq[string] # Capabilities needed
    invocation*: Invocation
    

  JMAPRequest* = object
    `using`*: seq[string]
    methodCalls*: seq[Invocation]

  ResultReference* = ref object # Made ref so parameters can be nil
    ## Used to refer to a previous method in the same request
    ##
    ## * **resultOf**: ID of the call to reference
    ## * **name**: Name of the call e.g. `"Core/Echo"`
    ## * **path**: [json pointer](jsonptr.html) of the value to reuse
    resultOf*, name*, path*: string

  JMAPResponse* = object
    methodResponses*: seq[Invocation]
    sessionState*: string

  SetError* = object
    `type`*: string
    description*: Option[string]

  JMAPError* = object of CatchableError

  CallError* = object of JMAPError
    ## Raised if trying to access a call which failed. Check with ok_ first
    ## before accessing call to avoid
    kind*: string

  AuthorisationError* = object of JMAPError
    ## Raised when there are problems with authenticating

  Blob* =  object
    ## Stores information about a [blob](https://jmap.io/spec-core.html#binary-data)
    accountId*, id*, fileType*: string
    size*: uint

const
  # from here https://jmap.io/spec-core.html#the-id-data-type 
  allowedIDCharacters = {'a'..'z'} + {'A'..'Z'} + {'0'..'9'} + {'-', '_'}

# Hooks

# An invocation needs to be an array so we need to make the JSON be an array instead
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

proc fromJsonHook*(blob: var Blob, data: JsonNode) =
  blob = Blob(
    accountId: data["accountId"].str,
    id: data["blobId"].str,
    fileType: data["type"].str,
    size: data["size"].num.uint
  )

proc toJsonHook*(blob: Blob): JsonNode =
  result = %* {
    "accountId": blob.accountId,
    "blobId": blob.id,
    "type": blob.fileType,
    "size": blob.size
  }

# Helpers

func addUsing*(request: var JMAPRequest, capability: string) =
  ## Adds a needed capability to the request.
  ## Not needed if Call specifies needed capabilities
  if capability notin request.`using`:
    request.`using` &= capability

func add*(request: var JMAPRequest, call: Call) {.raises: [].} =
  ## Adds a call to the request.
  ## Automatically adds the needed capabilities to the request
  runnableExamples "-d:ssl":
    import jamp
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
  # Don't add the needed if its already present.
  # Pretty sure the server wont error but saves some bandwidth
  for need in call.needed:
    request.addUsing(need)
  request.methodCalls &= call.invocation

# TODO: Raise error if call failed (Have {} which returns JNull if failed)
func `[]`*(resp: JMAPResponse, id: string): JsonNode {.raises: [KeyError].} =
  ## Gets the response data for an ID. If there are multiple responses for the
  ## method then all the returns values are joined together
  result = newJObject()
  for invocation in resp.methodResponses:
    if invocation.id == id:
      for key, value in invocation.arguments:
        result[key] = value
          
  if result.len == 0:
    raise (ref KeyError)(msg: id & " was not found in the response")


func ok*(invoc: Invocation): bool {.inline.} =
  ## Returns false if the invocation is an error
  result = invoc.name != "error"

func ok*(resp: JMAPResponse, id: string): bool =
  ## Returns true if call associated with ID had no error
  result = true
  for invocation in resp.methodResponses:
    if invocation.id == id and not invocation.ok:
      return false

func ok*(resp: JMAPResponse, call: Call): bool =
  ## Returns true if the call didn't return an error
  result = resp.ok(call.id)


proc `[]`*[T](resp: JMAPResponse, call: Call[T]): T {.inline.} =
  ## Gets response data for a call.
  ## Automatically parses the json and converts to the calls response type.
  ## Will throw an exception if trying to get value from 
  for invocation in resp.methodResponses:
    if invocation.id == call.id and not invocation.ok:
      raise (ref CallError)(msg: 
        invocation.arguments["description"].str, 
        kind: invocation.arguments["type"].str
      )

  result.fromJson(resp[call.id], JOptions(
    allowExtraKeys: true,
    allowMissingKeys: true
  ))

func id*(call: Call): string {.inline, raises: [].} =
  ## Returns invocation ID
  result = call.invocation.id


proc newInvocation*(name: string, args: sink JsonNode, id = ""): Invocation =
  ## Creates a new invocation.
  ## If you don't provide an ID then it will auto generate one.
  ##
  ## ID must only contain URL safe characters (A-Za-z0-9_-) and is recommended that it starts
  ## with an alpha character to be safe
  if id != "":
    # Check ID matches spec
    assert id.len >= 1 and id.len <= 255, "ID is too big"
    for c in id:
      assert c in allowedIDCharacters, "Invalid character '" & $c & "'"
        
  assert args.kind == JObject, "args must be a JSON object"
  result = Invocation(
    name: name,
    arguments: args,
    id: if id != "": id else: ("i" & $genNanoID())
  )

proc initCall*[T](needed: seq[string], name: string, args: sink JsonNode, id = ""): Call[T] =
  ## Creates a new call.
  ##
  ## * **needed**: Is the capabilities needed by the server to perform the method
  ## * **id**: ID to use for the call. If blank then a random one is generated
  result = Call[T](
    needed: needed,
    invocation: newInvocation(name, args, id)
  )
