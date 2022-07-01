##[
  Implements core spec which only has `Core/echo`_ which is useful for checking if authenticated
]## 

import std/[
  json,
  tables
]

import ../common

const
  coreCapability = "urn:ietf:params:jmap:core"

type
  Core* = object

proc echo*(c: typedesc[Core], args: JsonNode): Call[JsonNode] =
  result.needed = coreCapability
  result.invocation = newInvocation(
    "Core/echo",
    args,
  )
