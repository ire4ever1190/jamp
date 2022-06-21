# Small implementation of https://www.rfc-editor.org/rfc/rfc6901.html
# Includes the additions from JMAP where you can refer to every element in an array
import std/macros

macro point*(kind: typedesc, path: untyped = nil): string = 
  result = newLit "l"

