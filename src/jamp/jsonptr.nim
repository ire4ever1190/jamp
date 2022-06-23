import std/macros

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
    kind: PointNodeKind
    

func makePoint*(curr: NimNode): seq[string] =
  if curr.kind in {nnkIdent, nnkBracketExpr}:
    case curr.kind
    of nnkIdent:
      result &= $curr
    of nnkBracketExpr:
      result &= $curr[0]
      result &= $curr[1].intVal
    else: discard
  else:
    result &= makePoint(curr[0])
    result &= makePoint(curr[1])

func getFullType(obj: NimNode): NimNode =
  ## Fully gets the ObjectTy or symbol (if type like string of int) of an type
  result = obj.getType()
  while result.kind notin {nnkSym, nnkObjectTy}:
    if result[0].eqIdent("typeDesc"):
      result = result[1].getFullType()
    elif result[0].eqIdent("ref"):
      result = result[1].getFullType()
    elif result.kind == nnkBracketExpr:
      # This means it is something like seq[string]
      break
    else:
      result = result[0].getFullType()

func getParam(obj: NimNode, key: string): NimNode =
  obj.expectKind(nnkObjectTy)
  result = newEmptyNode()
  for param in obj[2]:
    if param.eqIdent(key):
      return param

func hasParam(obj: NimNode, key: string): bool =
  ## Returns true if object has a parameter
  result = obj.getParam(key).kind != nnkEmpty


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
    assert Person.point(friends) == "/friends/*" 
  #==#
  var pathString: string
  var curr = kind.getFullType()
  let components = path.makePoint()
  var i = 0
  while i < components.len:
    # Add the current component
    let comp = components[i]
    let param = curr.getParam(comp)
    if param.kind == nnkEmpty:
      (comp & " doesn't exist").error(path)
    pathString &= "/" & comp
    # Check if the component added was an array access
    # If so then we need to add the correct index access
    let paramType = param.getFullType()
    if paramType.kind == nnkBracketExpr:
      if i < components.len - 1 and components[i + 1].isNumeric:
        pathString &= "/" & components[i + 1]
        inc i
      else:
        pathString &= "/*"        
      curr = paramType[1].getFullType()
    else:
      curr = paramType
    inc i
  result = newLit pathString




when isMainModule:
  type
    PersonObj = object
      name: string
      age: int
      test: seq[string]
    L = seq[string]
    Person = ref PersonObj
    
  macro foo(x, y: typedesc) = 
    assert x.getFullType == y.getFullType
  foo(PersonObj, Person)
  static:
    macro l(x: typedesc) = echo x.getFullType().treeRepr
    l(L)
    
  
