import jamp/methods
import jamp/common
import unittest
import json

# Test that the jmapMethod macro generates correct code

test "Normal parameters":
  check JsonNode.baseGet("1234", @["1", "2"]) == %* {
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

test "Passing reference to previous result":
  check JsonNode.baseGet("1234", ResultReference(
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
