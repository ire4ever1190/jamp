
import std/[
  macros,
  times
]

import common
import utils


##[
  Helpers for working with JMAP methods
]##


func reuse*(inv: Invocation, path: string): ResultReference {.raises: [].} =
  ## Pass this has a parameter to a JMAP call and it will allow
  ## you to reuse value from previous call. See **TODO LINK JSONPTR MODULE** for information
  ## about path
  result = ResultReference(
    resultOf: inv.id,
    name: inv.name,
    path: path
  )

func reuse*(call: Call, path: string): ResultReference {.inline, raises: [].} =
  ## Helper function for reuse_ for use with Call_
  runnableExamples:
    let
      query = Mail.query("1234")
      get = Mail.get(
        ids = query.reuse("/ids/*")
      )
  #==#
  result = call.invocation.reuse(path)

macro reuseIt*(call: Call, path: untyped): ResultReference =
  ## Like reuse_ except the type is automatically passed in to a call to point_
  runnableExamples:
    let 
      query = Mail.query("1234")
      get = Mail.get(
        "1234",
        ids = query.reuseIt(ids[])
      )
  #==#
  result = newCall(
    ident"reuse",
    call,
    newCall("point", nnkDotExpr.newTree(call, ident"T"), path)
  )

proc formatDate*(date: DateTime): string =
  ## Returns date in the format that JMAP expects for `Date <https://jmap.io/spec-core.html#the-date-and-utcdate-data-types>`_
  result = date.format("yyyy-MM-dd'T'hh:mm:sszzz")
  
proc formatUTCDate*(date: DateTime): string =
  ## Returns date in the format that JMAP expects for `UTCDate <https://jmap.io/spec-core.html#the-date-and-utcdate-data-types>`_
  result = date.utc.format("yyyy-MM-dd'T'hh:mm:ss'Z'")

macro props*(x: typedesc, props: varargs[untyped]): seq[string] =
  ## Build a list of props from a type. Useful for having typesafe
  ## method for passing props to a method
  runnableExamples:
    type
      Person = object
        name: string
        age: int
        alive: bool
    assert Person.props(name, alive, age) == @["name", "age", "alive"]
  #==#
  let obj = x.getFullType()
  var stringArr = nnkBracket.newTree()
  for prop in props:
    if prop.kind != nnkIdent:
      "Argument needs to be an identifer".error(prop)
    let propName = $prop
    if obj.hasParam(propName):
      stringArr &= newLit(propName)
    else:
      (propName & " doesn't exist on " & $x).error(prop)
  result = stringArr.prefix("@")
