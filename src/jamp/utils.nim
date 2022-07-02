import std/[
  strutils,
  macros
]

##[
  Contains utils for library. Mostly for internal use
]##

func isNumeric*(x: openArray[char]): bool =
  ## Returns true if `x` is fully made of digits
  runnableExamples:
    assert "0912".isNumeric
    assert not "l".isNumeric
  #==#
  result = true
  for c in x:
    if c notin Digits:
      return false
      
func isEmpty*(obj: NimNode): bool =
  ## Returns true if object is of type nnkEmpty
  obj.kind == nnkEmpty

func isSeq*(x: NimNode): bool =
  ## Checks if a NimNode is a seq[T]
  result = x.kind == nnkBracketExpr and x.len == 2 and x[0].eqIdent("seq")

func getParam*(obj: NimNode, key: string): NimNode =
  obj.expectKind(nnkObjectTy)
  result = newEmptyNode()
  for param in obj[2]:
    if param.eqIdent(key):
      return param

func hasParam*(obj: NimNode, key: string): bool =
  ## Returns true if object has a parameter
  result = obj.getParam(key).kind != nnkEmpty


func getFullType*(obj: NimNode): NimNode =
  ## Fully gets the ObjectTy or symbol (if type like string of int) of an type.
  ## Doesn't recurse through seq[T] though
  result = obj.getType()
  while result.kind notin {nnkSym, nnkObjectTy}:
    if result[0].eqIdent("typeDesc"):
      result = result[1].getFullType()
    elif result[0].eqIdent("ref"):
      result = result[1].getFullType()
    elif result.kind == nnkBracketExpr:
      # This means it is something like seq[string]
      if result.isSeq:
        break
      else:
        result = result[1]
    else:
      result = result[0].getFullType()
