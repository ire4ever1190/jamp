##[
  Implments the `mail spec <https://jmap.io/spec-mail.html>`_ which enables the capabilities of 
    - `urn:ietf:params:jmap:mail`
    - `urn:ietf:params:jmap:submission`
    - `urn:ietf:params:jmap:vacationresponse`

  Use this module if you want to perform any mail related operations
]##

import std/json

import mail/common as mc
import ../methods
import ../common
export mail

type
  MailGet* = object of GetResponse[JsonNode]

using m: typedesc[Email]

proc get*(m; accountId: JPar[string], ids: JPar[seq[string]] = defaultVal, 
          properties: JPar[seq[string]] = @["id"]): Call[MailGet] =
  ## Same as base get.
  let args = Base.get(accountId, ids, properties)
  result.needed = mailCapability
  result.invocation = newInvocation(
    "Email/get",
    args
  )

proc query*(m; accountId: JPar[string], filter: JPar[FilterOperator | EmailFilter] = defaultVal,
            sort: JPar[seq[Comparator]] = defaultVal, position: JPar[int] = 0,
            anchor: JPar[string] = defaultVal, anchorOffset: JPar[int] = 0,
            limit: JPar[uint] = defaultVal, calculateTotal: JPar[bool] = false, 
            collapseThreads: JPar[bool] = false): Call[QueryResponse] =
  ## Query emails stored on server.
  ##
  ## * **collapseThreads**: Only one email per thread will be returned if true
  # let args = Base.query[EmailFilter](accountId, filter, sort, position, anchor, anchorOffset, limit, calculateTotal)
  let args = Base.query(accountId)
  args["collapseThreads"] = collapseThreads
  result.needed = mailCapability
  result.invocation = newInvocation(
    "Email/query",
    args
  )

export mc
