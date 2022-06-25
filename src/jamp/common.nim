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
    arguments*: Table[string, JsonNode]
    id*: string

  Call*[T] = object
    ## Wrapper around Invocation_ that stores the needed
    ## capability and the type it returns
    needed*: string # Capabilty needed
    invocation*: Invocation
    

  JMAPRequest* = object
    `using`*: seq[string]
    methodCalls*: seq[Invocation]

  ResultReference* = object
    resultOf*, name*, path*: string

  JMAPResponse* = object
    methodResponses*: seq[Invocation]
    sessionState*: string

  JMAPError* = object of CatchableError

  UnknownCapabilityError* = object of JMAPError
    ## The client included a capability in the “using” property of the request that the server does not support.

  LimitError* = object of JMAPError
    ## The request was not processed as it would have exceeded one of the request limits defined on the capability object.

# Hooks
    
proc toJsonHook*(call: Invocation): JsonNode =
  result = newJArray()
  result &= %call.name
  result &= %call.arguments
  result &= %call.id

proc fromJsonHook*(call: var Invocation, data: JsonNode) =
  call = Invocation(
    name: data[0].str,
    arguments: data[1].to(Table[string, JsonNode]),
    id: data[2].str
  )

# Helpers
func add*(request: var JMAPRequest, call: Call) =
  ## Adds a call to the request
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

proc newInvocation*(name: string, args: Table[string, JsonNode], id = ""): Invocation =
  ## Creates a new invocation.
  ## If you don't provide an ID then it will auto generate one
  result = Invocation(
    name: name,
    arguments: args,
    id: if id != "": id else: $genNanoID()
  )
