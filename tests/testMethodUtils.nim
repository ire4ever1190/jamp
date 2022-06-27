import jamp/methods
import jamp/common
import unittest
import std/options
import json

# Test that the jmapMethod macro generates correct code

test "Normal parameters":
  check Base.get("1234", @["1", "2"]) == %* {
    "accountId": "1234",
    "ids": @["1", "2"],
    "properties": @["id"]
  }

test "addParam":
  var
    foo = %"hello"
    fooIsRef = true
    data = newJObject()
    
  data.addParam(foo, foo)
  assert "#foo" in data

  fooIsRef = false
  data.addParam(foo, foo)
  assert "foo" in data
  
  fooIsRef = true
  data.addParam(foo)
  assert "#foo" in data

test "Call with pass":
  type
    Foo = object
  proc bar(_: typedesc[Foo], x, b: int, l: string) = 
    check:
      x == 9
      b == 4
      l == "foo"
  let
    x = 9
    b = 4
    l = "foo"
  callWithPass(Foo, bar)


test "Passing reference to previous result":
  check Base.get("1234", ResultReference(
    resultOf: "5678",
    name: "Foo/get",
    path: "/test/*"
  )) == %* {
    "accountId": "1234",
    "#ids": {
      "resultOf": "5678",
      "name": "Foo/get",
      "path": "/test/*"
    },
    "properties": @["id"]
  }

test "Creating a new method":
  type
    Foo = object
  proc get[Foo](x: int): Call[Option[string]] {.jmapMethod(Base).} =
    result.needed = "bar"

  check Foo.get("1234", 9).needed == "bar"
