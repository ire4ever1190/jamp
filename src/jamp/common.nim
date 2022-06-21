import std/[
  json,
  tables,
  jsonutils
]

const jsonOptions = JOptions(
  allowExtraKeys: true,
  allowMissingKeys: false
)

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
    
  Invocation* = object
    ## An invocation represents a method call against the JMAP server
    name*: string
    arguments*: Table[string, JsonNode]
    id*: string

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
