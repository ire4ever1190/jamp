when not defined(ssl):
  {.error: "JAMP requires ssl to be enabled (via -d:ssl or switch(\"d\", \"ssl\"))".}

import std/[json, jsonutils]
  
import jamp/[
  client,
  common,
  jsonptr,
  helpers,
  methods
]

import jamp/specs/[
  mail,
  core
]

export jsonptr
export client
export common
export mail
export core
export helpers
export json
export jsonutils
export methods
