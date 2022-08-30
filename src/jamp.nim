##[
  Jamp is a client library to use [JMAP](https://jmap.io) with your mail server (if it supports it).

  The next few sections will show the basic principles of JMAP and how to use the library. For more
  in depth examples visit the [examples page](../documents.html)

  Methods
  =======

  A method refers to what you can call against the JMAP server (It is also called an [invocation](https://jmap.io/spec-core.html#the-invocation-data-type)).
  It has a name, arguments, and an ID (so you can get its result from the response. This library wraps
  methods in a `Call[T]` which stores

   - Expected return type (`T`)
   - What it requires the server to support
   - ID, name, and arguments

  When generating your own wrappers for JMAP specs it is best to return `Call[T]` so that the other procs in this
  library know how to handle it.

  Requests
  ========

  A request is multiple calls joined together. These calls are able to reference the result of other calls within
  the same request which saves having to make multiple requests. To reference other requests you need to pass
  a ResultReference_ as the parameter which contains ID and path of a call to use. Jamp implements helpers like reuse_
  to simplify this process

  Responses
  =========

  A reponse contains responses for all methods that were called. If a method failed then its name will be `"error"` but
  its ID will stay the same. By keeping the `Call` around you can easily access these response values and check them
]##

runnableExamples "-d:ssl -r:off":
  import std/sequtils
  
  let client = newJMAPClient(basicAuth("our@email.com", "password"), "host")
  client.startSession()
  let
    query = Email.query("1234")
    get = Email.get(
      "1234",
      ids = query.reuseIt(ids[])
    )
  var req = JMAPRequest()
  req &= query
  req &= get
  let resp = client.request(req)
  # We can get our values back using the calls
  assert resp.ok(query)
  assert resp.ok(get)
  echo "Total emails: ", resp[query].ids.len
  assert resp[query].ids == resp[get].list.mapIt(it.id)

when not defined(ssl):
  {.error: "JAMP requires ssl to be enabled (via -d:ssl or switch(\"d\", \"ssl\"))".}

import std/[json, jsonutils]
  
import jamp/[
  client,
  common,
  jsonptr,
  helpers,
  methods,
  auth
]

import jamp/specs/[
  mail,
  core
]
export mail, core


export jsonptr
export client
export common
export helpers
export json
export jsonutils
export methods
export auth
