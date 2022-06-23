import std/strutils

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
