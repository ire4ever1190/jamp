##[
  JMAP has 6 standard methods

  - `get <https://jmap.io/spec-core.html#get>`_: Used to get data of a certain type
  - `changes <https://jmap.io/spec-core.html#changes`_: Efficiently get new items since to match new state on server after a series of updates
  - `set <https://jmap.io/spec-core.html#set>`_: Used to create, update, and destroy objects of a certain type
  - `copy <https://jmap.io/spec-core.html#copy>`_: Used to move records between accounts
  - `query <https://jmap.io/spec-core.html#query`_: Used to search for records that match a query
  - `queryChanges <https://jmap.io/spec-core.html#querychanges`_: Used to update state of cached query

  Certain specs may support some or all of these methods.

  This module doesn't implement them but contains base versions and helpers that enable you to write them for different
  types without needing to define everything (But Jamp does contain specs for core and mail already). So no need to touch
  this module unless you are developing the library or want to extend the library to contain more specs
]##

import std/[
  options,
  tables,
  json,
  macros
]

import common

type
  GetResponse*[T] = ref object of RootObj
    ## Basic response from a **get** method, contains list of records retrieved.
    ## **state** can be used to cache information from this, if the state changes
    ## though then you must invalidate your entire cache or get the new changes
    accountId*: string
    state*: string
    list*: seq[T]
    notFound*: seq[string]

  ChangesResponse* = ref object of RootObj
    ## Contains the changes that have occured since oldState. IDs returned in this
    ## can be retrieved to update cache.
    ## If **hasMoreChanges** is true then the **changes** method should be called again with **newState**
    ## to get more changes
    accountId*: string
    oldState*, newState*: string
    hasMoreChanges*: bool
    created*, updated*, destroyed*: seq[string]
    
  SetResponse* = ref object of RootObj
    ## Shows information about what operations were successful/failed    
    accountId*: string
    oldState*: Option[string]
    newState*: string
    created*: Option[Table[string, string]]
    updated*: Option[Table[string, Option[string]]]
    destroyed*: Option[seq[string]]
    notCreated*, notUpdated*, notDestroyed*: Option[Table[string, SetError]]
    

  SetError* = object
    ## Error object that is in SetResponse_ when a record fails to be created, updated, or destroyed
    `type`*: string
    description: Option[string]

  CopyResponse*[T] = object
    ## Response from Copy method.
    ## **Created** might contain a slimmed down version of the full type, always check the spec to see
    fromAccountId*, accountId*: string
    oldState*: Option[string]
    newState*: string
    created*: Option[Table[string, T]]
    notCreated*: Option[Table[string, SetError]]

  QueryResponse* = object
    ## Response from a query
    accountId*: string
    queryState*: string
    canCalculateChanges*: bool
    position*: uint
    ids*: seq[string]
    total*, limit*: Option[uint]

  QueryChangesResposne* = object
    accountId*: string
    oldQueryState*, newQueryState*: string
    total*: Option[uint]
    removed*: seq[string]
    added*: seq[AddedItem]

  AddedItem* = object
    id*: string
    index*: uint


macro jmapMethod*(base: typed, prc: untyped) =
  ## Modifies the parameters of the proc so that it can take both normal parameters
  ## and references to other methods results (via ResultReference_). 
  ## 
  ## .. Note:: The parameters will be provided to you has `JsonNode` and will lose type info
  ##
  ## Indepth example if we are making a **get** method for record **Foo**
  runnableExamples:
    type
      Foo = object
      
    block:
      # Our Foo getter extends the standard getter so we specify that
      proc get[Foo](extraProp: string): Call[Foo] {.jmapMethod(get).} =
        # extraProp is JsonNode in the body
        # There also exists variable extraPropIsRef if its a reference to another methods result
        # args is also injected which contains the args from the base method (get in this case)
        args.addParam(extraProp, extraProp)
        result = initCall(
          "urn:ietf:params:jmap:core",
          "Foo/get",
          args
        )
    block:
      # This will generate approximately 
      # The wrapper function which gives typesafe interface
      proc get(_: typedesc[Foo], accountId: string | ResultReference, #[params from base get]# 
              extraProp: string | ResultReference): Call[Foo] {.inline.} =
        getRaw(accountId, accountId is ResultReference, extraProp, extraProp is ResultReference)
      # Raw version which performs all the processing
      proc getRaw(
                  accountId: JsonNode, accountIdIsRef: bool, #[ other params from base get]#
                  extraProp: JsonNode, extraPropIsRef: bool
                ) =
        args = get(accoutnId, accountIdIsRef, #[other params]#)
        args.addParam(extraProp, extraProp)
        result = initCall(
            "urn:ietf:params:jmap:core",
            "Foo/get",
            args
        )

      # This allows it to be called like so
      let call = Foo.get("1234567", "extraProp")
  #==#
  # TODO: Copy documentation
  let rawProcName = ident($prc.name & "Raw")
  var 
    wrapperProc = copy prc
    # Have the wrapper call the raw version of the proc which only takes JSON nodes
    # and a parameter to specify if the parameter is a reference
    wrapperBody = nnkCall.newTree(rawProcName)
    rawProc = copy prc
    rawParams = nnkFormalParams.newTree(prc.params[0])
  
  # Create a new series of parameters that can be their original type
  # or a reference to the result of another method
  for param in wrapperProc[3]:
    if param.kind == nnkIdent: continue
    param[^2] = infix(param[^2], "|", ident"ResultReference")
    # Add the raw version of the parameters
    for id in param[0 ..< ^2]:
      # Add the two parameters to the raw proc
      rawParams &= newIdentDefs(id, ident"JsonNode")
      rawParams &= newIdentDefs(ident($id & "IsRef"), ident"bool")
      # Add the passing of the parameter along with specifying if the
      # parameter was a reference before converting to json
      wrapperBody &= id.prefix("%")
      # A parameter is considered a reference if its of type ResultReference
      # and it isn't nil (Since nil is usually used to mean default parameter)
      wrapperBody.add quote do:
        (when `id` is ResultReference: not `id`.isNil
        else: false)
      
  # Move the generic parameter into a typedesc parameter to make it idomatic
  if wrapperProc[2].kind == nnkEmpty:
    "Missing record specifier e.g. get[Mailbox](params...)".error(wrapperProc)
    
  wrapperProc[3].insert(1, newIdentDefs(ident"_", nnkBracketExpr.newTree(
    ident"typedesc",
    wrapperProc[2][0][0]
  )))
  wrapperProc[2] = newEmptyNode()
  
  rawProc.params = rawParams
  rawProc.name = ident($rawProc.name & "Raw")
  
  wrapperProc.body = wrapperBody
  wrapperProc.addPragma(ident"inline")
  
  result = newStmtList(
    rawProc,
    wrapperProc
  )
  echo result.toStrLit

type MailBox = object

template addParam*(json: JsonNode, param: untyped, val: JsonNode) =
  ## Adds the parameter to Json variable. If it detects that the variable is meant to be 
  ## a reference then it sets the key to be correct. See jmapMethod_ for actual example of usage
  json[(if `param IsRef`: "#" else: "") & astToStr(param)] = val

template addParam*(json: JsonNode, param: untyped) =
  ## Overload for addParam_ when both **param** and **val** are the same
  json.addParam(param, param)

proc baseGet*[JsonNode](accountId: string, ids: seq[string] = nil, properties: seq[string] = @["id"]): JsonNode {.jmapMethod(nil).} =
  ## Basic version of get defined in the `core spec <https://jmap.io/spec-core.html#get>`_.
  result = newJObject()
  assert id != nil, "account ID must be specified in `get`"
  result.addParam(accountId)
  result.addParam(ids)
  result.addParam(properties)
  


# proc get(id: string, ids: seq[string], properties = @["id"]) = discard

# proc get(id: string | ResultReference, ids: seq[string] | ResultReference, properties: seq[string] | ResultReference = @["id"]): JsonNode = discard


proc get(id: JsonNode, idIsRef: bool, ids: JsonNode, idsIsRef: bool): JsonNode =
  let idKey = if idIsRef: "#id" else: "id"
  result["idKey"] = id

