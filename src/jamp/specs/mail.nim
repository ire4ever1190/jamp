##[
  Implments the `mail spec <https://jmap.io/spec-mail.html>`_ which enables the capabilities of
    - `urn:ietf:params:jmap:mail`
    - `urn:ietf:params:jmap:submission`
    - `urn:ietf:params:jmap:vacationresponse`

  Use this module if you want to perform any mail related operations
]##

import std/[json, options, strutils, tables]

import ../methods
import ../common

import core

const
  mailCapability* = "urn:ietf:params:jmap:mail"
  submissionCapability* = "urn:ietf:params:jmap:submission"
  vacationCapability* = "urn:ietf:params:jmap:vacationresponse"

type
  Email* = object
  EmailFilter* = object
  MailGet* = GetResponse[JsonNode]

#
# Email
#

using m: typedesc[Email]

proc get*(m; accountId: JPar[string], ids: JPar[seq[string]] = defaultVal,
          properties: JPar[seq[string]] = @["id"],
          bodyProperties: JPar[seq[string]] = @["partId", "blobId", "size", "name", "type", "charset", "disposition", "cid", "language", "location"],
          fetchTextBodyValues: JPar[bool] = false, fetchHTMLBodyValues: JPar[bool] = false): Call[MailGet] =
  ## Same as base get.
  let args = Base.get(accountId, ids, properties)
  args.addParams(bodyProperties, fetchHTMLBodyValues, fetchTextBodyValues)
  result.needed = @[mailCapability, coreCapability]
  result.invocation = newInvocation(
    "Email/get",
    args
  )

proc query*(m; accountId: JPar[string], filter: JPar[FilterOperator] = defaultVal,
            sort: JPar[seq[Comparator]] = defaultVal, position: JPar[int] = 0,
            anchor: JPar[string] = defaultVal, anchorOffset: JPar[int] = 0,
            limit: JPar[uint] = defaultVal, calculateTotal: JPar[bool] = false,
            collapseThreads: JPar[bool] = false): Call[QueryResponse] =
  ## Query emails stored on server.
  ##
  ## * **collapseThreads**: Only one email per thread will be returned if true
  # let args = Base.query[EmailFilter](accountId, filter, sort, position, anchor, anchorOffset, limit, calculateTotal)
  let args = Base.query(accountId, filter, sort, position, anchor, anchorOffset, limit, calculateTotal)
  args["collapseThreads"] = collapseThreads
  result.needed = @[mailCapability, coreCapability]
  result.invocation = newInvocation(
    "Email/query",
    args
  )

proc setVal*(m; accountId: JPar[string], ifInState: JPar[string] = defaultVal,
          create: JPar[Table[string, Email]] = defaultVal, update: JPar[Table[string, PatchObject]] = defaultVal,
          destroy: JPar[seq[string]] = defaultVal): Call[SetResponse[Email]] =
  let args = Base.setVal[:Email](accountId, ifInState, create, update, destroy)
  result.needed = @[mailCapability, coreCapability]
  result.invocation = newInvocation(
    "Email/set",
    args
  )

#
# Mailbox
#

type
  MailboxRight = enum
    readItems
    addItems
    removeItems
    setSeen
    setKeywords
    createChild
    rename
    delete
    submit

  Mailbox* = object
    id*, name*: string
    parentId*, role*: Option[string]
    sortOrder*, totalEmails*, unreadEmails*, totalThreads*, unreadThreads*: uint
    myRights*: set[MailboxRight]
    isSubscribed*: bool

func fromJson*(rights: var set[MailboxRight], data: JsonNode) =
  for right in MailboxRight:
    let key = "may" & capitalizeAscii($right)
    if key in data:
      rights.incl right

using mb: typedesc[Mailbox]


proc get*(mb; accountId: JPar[string], ids: JPar[seq[string]] = defaultVal,
          properties: JPar[seq[string]] = @["id"]): Call[GetResponse[Mailbox]] =
  let args = Base.get(accountId, ids, properties)
  result.needed = @[mailCapability, coreCapability]
  result.invocation = newInvocation(
    "Mailbox/get",
    args
  )


proc query*(mb; accountId: JPar[string], filter: JPar[FilterOperator | EmailFilter] = defaultVal,
            sort: JPar[seq[Comparator]] = defaultVal, position: JPar[int] = 0,
            anchor: JPar[string] = defaultVal, anchorOffset: JPar[int] = 0,
            limit: JPar[uint] = defaultVal, calculateTotal: JPar[bool] = false,
            sortAsTree: JPar[bool] = false, filterAsTree: JPar[bool] = false): Call[QueryResponse] =
  let args = Base.query(accountId, filter, sort, position, anchor, anchorOffset, limit, calculateTotal)
  args.addParams(sortAsTree, filterAsTree)
  result.needed = @[mailCapability, coreCapability]
  result.invocation = newInvocation(
    "Mailbox/query",
    args
  )
