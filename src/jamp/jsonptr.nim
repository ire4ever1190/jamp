import std/[
  macros,
  strutils
]

import utils

##[
  `JSON pointer <https://www.packetizer.com/rfc/rfc6901/>`_ is a way for specifying a path to a value inside a JSON object.
  A pointer works by having a series of parameters to go through that are seperated by `/`. If accessing an index then you 
  put the index after the `/`.
]##
runnableExamples:
  type
    Person = ref object
      name: string
      friends: seq[Person]
      
  let data = Person(
    name: "John",
    friends: @[
      Person(
        name: "Jane",
        friends: @[]
      )
    ]
  )
##[
  Using `Person` has an example. You can access John's name via `"/name"`:nim:, get Jane's name via `"/name/0/name"`:nim:, get all of 
  John's friends via `"/friends/*"`:nim:, and all of his friends names via `"/friends/*/name"`:nim:. Those last two examples (using `*`) are not
  part of the standard JSON pointer spec but are allowed in JMAP.

  This module implements a few helpers for working with JSON pointers such as point_ which gives type safe construction of pointers
]##

type
  PointNodeKind = enum
    Param
    Index

  PointNode = object
    name: NimNode # Stored has NimNode so we can error it if it doesn't exist
    case kind: PointNodeKind
    of Param: discard
    of Index:
      index: BiggestInt # -1 means *

func pointerReplacements(x: string): string =
  ## Performs needed replacements to make string safe for pointer
  x.multiReplace(
    ("~", "~0"),
    ("/", "~1")
  )

func makePoint*(curr: NimNode): seq[PointNode] =
  ## Goes through all the parameter accesses and flattens it down
  ## into a sequence to make it easier to work with
  if curr.kind != nnkDotExpr:
    case curr.kind
    of nnkBracketExpr:
      let index = if curr.len == 2: curr[1].intVal else: -1
      result &= PointNode(
        name: curr[0],
        kind: Index,
        index: index
      )
    of nnkIdent:
      result &= PointNode(
        name: curr,
        kind: Param
      )
    of nnkBracket:
      let index = if curr.len == 1: curr[0].intVal else: -1
      result &= PointNode(
        name: curr,
        kind: Index,
        index: index
      )
    of nnkAccQuoted:
      # Quoted parameters need to have their multiple
      # components joined into one ident
      var quotedName: string
      for id in curr:
        quotedName &= id.strVal
      let newIdent = ident(quotedName)
      newIdent.copyLineInfo(curr)
      result &= PointNode(
        name: newIdent,
        kind: Param
      )
    else:
      "Invalid JSON pointer syntax".error(curr)
  else:
    result &= makePoint(curr[0])
    result &= makePoint(curr[1])




macro point*(kind: typedesc, path: untyped): string = 
  ## Creates a `JSON pointer <https://www.packetizer.com/rfc/rfc6901/>`_ for a type.
  ## This is slightly different to that RFC in that it supports `*` for referring to every
  ## item in an array
  ## Recommended over writing the pointer manually since this provides compile time
  ## checking that the path is valid.
  runnableExamples:
    type
      Person = object
        name: string
        friends: seq[Person]
        age: int
    assert Person.point(name) == "/name"
    assert Person.point(friends[]) == "/friends/*" 
    assert Person.point(friends[0].name) == "/friends/0/name"
  #==#
  var 
    pathString: string
    curr = kind.getFullType()
    i = 0 
  for comp in path.makePoint():
    pathString &= "/"
    let 
      param = if comp.name.kind == nnkIdent: curr.getParam($comp.name) else: curr
      paramType = if not param.isEmpty(): 
          param.getFullType()
        elif curr.isSeq and i == 0:
          kind
        else:
          newEmptyNode()
    if comp.name.kind == nnkIdent and param.isEmpty():
      # TODO: Specify the object it is trying to get the parameter for
      # Might not be possible?
      ($comp.name & " doesn't exist for object").error(comp.name)
    case comp.kind
    of Index:
      if paramType.kind != nnkBracketExpr or not paramType[0].eqIdent("seq"):
        "Array access can only be one on seq[T] parameters".error(comp.name)
      # If its the first component and its an array then
      # it doesn't need a name
      if comp.name.kind != nnkIdent:
        if not (curr.isSeq and i == 0):
          "Array access must have array parameter specified".error(comp.name)
      else:
        pathString &= pointerReplacements($comp.name)
        pathString &= "/"
      # Use * to mean every index
      pathString &= (if comp.index != -1: $comp.index else: "*")
      curr = paramType[1].getFullType()
    of Param:
      pathString &= pointerReplacements($comp.name)
      curr = paramType.getFullType()
      
    inc i
      
  result = newLit pathString  
