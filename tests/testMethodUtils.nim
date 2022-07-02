import jamp/methods
import jamp/specs/mail
import jamp/common
import jamp/jsonptr
import unittest
import std/options
import json

test "Normal parameters":
  check Base.get("1234", @["1", "2"]) == %* {
    "accountId": "1234",
    "ids": @["1", "2"],
    "properties": @["id"]
  }

test "addParam":
  var
    foo = ResultReference()
    data = newJObject()
    
  data["foo"] = foo
  assert "#foo" in data

  data["test"] = true
  assert "test" in data

  data["default"] = JPar[string](defaultVal)
  assert "default" in data

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

