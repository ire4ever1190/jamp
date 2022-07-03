import jamp

import std/[
  unittest,
  json
]

test "Passing reference to previous using helper":
  let 
    query = Email.query("1234")  
    get = Email.get("1234", ids = query.reuseIt(ids[]))
  check get.invocation.arguments == %* {
      "accountId": "1234",
      "#ids": {
        "resultOf": query.id,
        "name": "Email/query",
        "path": "/ids/*"
      },
      "properties": @["id"]
    }
  
suite "Build property list":
  type
    Person = object
      name: string
      age: int
      something: bool
      
  test "Get properties":
    check Person.props(name, something) == @["name", "something"]

  test "Passing property that doesn't exist":
    check not compiles(Person.props(l))

  test "Passing non ident":
    check not compiles(Person.props(echo ""))
