##[
  JMAP has 6 standard methods

  - get_: Used to get data of a certain type
  - changes <https://jmap.io/spec-core.html#changes`_: Efficiently get new items since to match new state on server after a series of updates
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
  jsonutils,
  macros
]

import common

type
  JPar*[T: not ResultReference] = T or ResultReference
    ## Means that the parameter can either be `T` or a reference to the result
    ## of another method

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

  CopyResponse*[T] = ref object of RootObj 
    ## Response from Copy method.
    ## **Created** might contain a slimmed down version of the full type, always check the spec to see
    fromAccountId*, accountId*: string
    oldState*: Option[string]
    newState*: string
    created*: Option[Table[string, T]]
    notCreated*: Option[Table[string, SetError]]

  QueryResponse* = ref object of RootObj
    ## Response from a query
    accountId*: string
    queryState*: string
    canCalculateChanges*: bool
    position*: uint
    ids*: seq[string]
    total*, limit*: Option[uint]

  QueryChangesResponse* = ref object of RootObj
    accountId*: string
    oldQueryState*, newQueryState*: string
    total*: Option[uint]
    removed*: seq[string]
    added*: seq[AddedItem]

  AddedItem* = object
    id*: string
    index*: uint

  Comparator* = object
    ## Used to compare two properties for sorting
    ##
    ## * **property**: Property on the object to use for comparison
    ## * **collation**: Algorithm to use for comparing order of strings. Check server for which algorithms it supports
    property*: string
    isAscending*: bool
    collation*: Option[string]

  Operator* = enum
    ## Operators for use with FilterOperator_.
    ## **Just** means a condition on its own
    And = "AND"
    Or  = "OR"
    Not = "NOT"
    Just

  FilterOperator* = ref object
    case operator*: Operator
    of And..Not:
      conditions*: seq[FilterOperator]
    of Just:
      condition*: FilterCondition

  FilterCondition* = distinct JsonNode
    ## Spec defined properties that can be used for conditions
    # Is a distinct JsonNode since the objects are semi complex and basically entirely Option[T]
    # Also means we can define helpers without knowing what the Condition will look like

  PatchObject* = Table[string, JsonNode]
    
  Base* = object
    ## Namespace for default methods

{.experimental: "dynamicBindSym".} 

using _: typedesc[Base]

# Filter operator helpers

template makeOp(name: untyped, op: Operator) =
  func name*(a, b: FilterOperator): FilterOperator =
    if (a.operator == Just and b.operator == op) or (a.operator == op and b.operator == Just):
      # Merge the none operater onto it
      result = if a.operator == op: a else: b
      result.conditions &= (if a.operator == op: b else: a)
    else:
      result = FilterOperator(
        operator: op,
        conditions: @[a, b]
      )

makeOp(`or`, Or)
makeOp(`and`, And)

func `not`*(op: FilterOperator): FilterOperator =
  ## Makes filter do opposite of what it does
  result = FilterOperator(
    operator: Not,
    conditions: @[op]
  )

func newFilter*(conditions: JsonNode): FilterOperator =
  ## Creates new filter using conditions given. Should be checked

  FilterOperator(
    operator: Just,
    condition: FilterCondition(conditions)
  )


const toJOpts = ToJsonOptions(
  enumMode: joptEnumString,
  jsonNodeMode: joptJsonNodeAsRef
)

func toJsonHook*(op: FilterOperator): JsonNode =
  case op.operator
  of Just:
    result = op.condition.JsonNode
  else:
    result = newJObject()
    result["operator"] = %op.operator
    result["conditions"] = op.conditions.toJson(toJOpts)

func initComparator*(property: string, isAscending = true, collation = ""): Comparator {.raises: [].} = 
  ## Creates a new comparator to be used in JMAP methods
  result.property = property
  result.isAscending = isAscending
  if collation != "":
    result.collation = some collation



template isRef*(param: JPar): bool =
  ## Returns true if **param** is a ResultReference_
  param is ResultReference

# Can't call it `isNil` since then it would resolve to systems isNil instead and error
func eqNil*(param: JPar): bool {.inline, raises: [].} =
  ## Returns true if **param** is `nil`.
  ## If `T` is a non nillable type (e.g. `string`) then it always returns false
  runnableExamples:
    assert not JPar[string]("string").eqNil
    assert JPar[string](defaultVal).eqNil
  #==#
  when compiles(param == nil):
    result = param == nil
  else:
    result = false


proc `[]=`*(data: JsonNode, key: string, param: JPar) =
  ## Adds a param to the data. This automatically prefixes the key with `#`
  ## if **param** is a ResultReference_
  mixin toJson
  data[(if param.isRef and not param.eqNil: "#" else: "") & key] = param.toJson(toJOpts)

macro passArgs*(ns: typedesc, name: typed): JsonNode =
  ## Passes variables from current proc into another. Useful for calling base methods
  runnableExamples "-d:ssl":
    import jamp
    
    type Foo = object

    proc get*(_: typedesc[Foo]; accountId: JPar[string], ids: JPar[seq[string]] = defaultVal, 
              properties: JPar[seq[string]] = @["id"]): Call[string] =
      let args = Base.passArgs(get)
      # Add extra params if needed
      result.invocation = newInvocation(
        "Foo/get",
        args
      )
  #==#
  var prc = newEmptyNode()
  # Force the symbol to be a closed choice and then look for the proc  
  let toLookup = (if name.kind == nnkSym: bindSym(ident $name) else: name)
  for possible in toLookup:
    let params = possible.getImpl()[2]
    if params.len > 0:
      for param in params:
        let kind = param.getType()
        if kind.kind == nnkBracketExpr and kind[1].eqIdent(ns):
          prc = possible
          break
          
  assert prc.kind != nnkEmpty, "Couldn't find " & $name & " for " & $ns
  result = nnkCall.newTree(prc, ns)
  for param in prc.getImpl().params[2..^1]:
    result &= ident($param[0])

macro addParams*(data: JsonNode, params: varargs[untyped]) =
  ## Adds multiple params to **data** with their key being the name of the paramter
  runnableExamples "-d:ssl":
    import jamp
    import std/json
    
    let
      name: JPar[string] = "hello"
      age: JPar[int] = ResultReference()
    var data = newJObject()
    data.addParams(name, age)
    
    assert "name" in data
    assert "#age" in data
  #==#
  result = newStmtList()
  let sym = bindSym("addParam")
  for param in params:
    let key = newLit $param
    result.add quote do:
      `data`[`key`] = `param`

#
# Base versions
# 



const defaultVal* = ResultReference(nil)
  ## Use this to specify that the server should use the default value for the parameter
  # I ran into a compiler error if I used nil so I instead use this which doesn't error =)

# {.push raises: [].}

proc get*(_; accountId: JPar[string], ids: JPar[seq[string]] = defaultVal, 
          properties: JPar[seq[string]] = @["id"]): JsonNode =
  ## Base version of get defined in the `core spec <https://jmap.io/spec-core.html#get>`_.
  ## Response for call will likely be in the form of GetResponse_
  result = newJObject()
  result.addParams(accountId, ids, properties)

proc changes*(_; accountId: JPar[string], sinceState: JPar[string], maxChanges: JPar[uint] = defaultVal): JsonNode =
  ## Base version of changes defined in the `core spec <https://jmap.io/spec-core.html#changes>`_.
  ## Response for call will likely be in the form of ChangesResponse_
  assert maxChanges > 0, "maxChanges must be greater than 0"
  result = newJObject()
  result.addParams(accountId, sinceState, maxChanges)

proc query*(_; accountId: JPar[string], filter: JPar[FilterOperator] = defaultVal,
            sort: JPar[seq[Comparator]] = defaultVal, position: JPar[int] = 0,
            anchor: JPar[string] = defaultVal, anchorOffset: JPar[int] = 0,
            limit: JPar[uint] = defaultVal, calculateTotal: JPar[bool] = false): JsonNode =
  ## Used to query the server for large sets of data. From `core spec <https://jmap.io/spec-core.html#query>`_.
  ##
  ## * **filter**: Set of filters to query with. `Q` is a spec defined object for querying
  ## * **sort**: List of comparators to use. If the first returns `true` then the second is used etc...
  ## * **position**: Starting index of first ID in results. If negative that it counts from the end (python style indexing)
  ## * **anchor**: If provided then **position** is ignored and the first ID in results will be **anchor**
  ## * **anchorOffset**: Offset from **anchor** to start results at
  ## * **calculateTotal**: Returns total amount of items in response. Is slow for large data/filters so be careful
  result = newJObject()
  result.addParams(accountId, filter, sort, position, anchor, anchorOffset, limit, calculateTotal)

proc set*(_; accountId: JPar[string], ifInState: JPar[string] = defaultVal,
          create: JPar[Table[string, JsonNode]], update: JPar[Table[string, PatchObject]], 
          destroy: JPar[seq[string]]): JsonNode =
  ## Used to create, update, and destroy records of a certain type
  result = newJObject()
  result.addParams(accountId, ifInState, create, update, destroy)

# {.pop.};
  
export toJson
export json
export tables
