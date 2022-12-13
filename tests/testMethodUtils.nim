import jamp
import std/[
  tables,
  jsonutils,
  tables
]
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

suite "Argument passing":
  type
    Foo = object

  test "Simple passing":
    proc get(_: typedesc[Foo]; accountId: JPar[string], ids: JPar[seq[string]] = defaultVal,
             properties: JPar[seq[string]] = @["id"]): JsonNode =
      Base.passArgs(get)

    check Foo.get("test")["accountId"].str == "test"

  test "Can pass to generic function":
    proc set(_: typedesc[Foo]; accountId: JPar[string], ifInState: JPar[string] = defaultVal,
                 create: JPar[Table[string, Foo]] = defaultVal,
                 update: JPar[Table[string, PatchObject]] = defaultVal,
                 destroy: JPar[seq[string]] = defaultVal): JsonNode =
      Base.passArgs(set, Foo)
    check set(Foo, "test", destroy = @["test"])["destroy"] == %* @["test"]

suite "Filter operators":
  # OR and AND use a template for implementation so they work the same
  test "OR two conditions":
    let filter = newFilter(%* {"foo": "bar"}) or newFilter(%* {"hello": "world"})
    check:
      filter.operator == Or
      filter.conditions.len == 2

  test "OR filter and condition":
    var filter = newFilter(%* {"foo": "bar"}) or newFilter(%* {"hello": "world"})
    filter = filter or newFilter(%* {"a": "b"})
    check:
      filter.operator == Or
      filter.conditions.len == 3

  test "OR two OR filters":
    var
      filterA = newFilter(%* {"foo": "bar"}) or newFilter(%* {"hello": "world"})
      filterB = newFilter(%* {"bar": "baz"}) or newFilter(%* {"another": "one"})
      filter = filterA or filterB

    check:
      filter.operator == Or
      filter.conditions.len == 2
      filter.conditions[0] == filterA
      filter.conditions[1] == filterB

  test "OR AND & OR filters":
    var
      filterA = newFilter(%* {"foo": "bar"}) or newFilter(%* {"hello": "world"})
      filterB = newFilter(%* {"bar": "baz"}) and newFilter(%* {"another": "one"})
      filter = filterA or filterB

    check:
      filter.operator == Or
      filter.conditions.len == 2
      filter.conditions[0] == filterA
      filter.conditions[1] == filterB

  test "NOT condition":
    let
      condition = newFilter(%* {"foo": "bar"})
      filter = not condition

    check:
      filter.operator == Not
      filter.conditions[0] == condition
