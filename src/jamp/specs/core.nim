##[
  Implements core spec which only has `Core/echo`_ which is useful for checking if authenticated
]## 

import std/[
  json,
  tables,
  options
]

import ../common

const
  coreCapability* = "urn:ietf:params:jmap:core"

type
  Core* = object

  CopyResponse* = object
    ## Response from copying blobs between accounts.
    ##
    ## * **copied**: The mapping of blob IDs from original account to blobs in new account
    fromAccountId*, accountId*: string
    copied: Option[Table[string, string]]
    notCopied: Option[Table[string, SetError]]

proc echo*(c: typedesc[Core], args: JsonNode): Call[JsonNode] =
  ## Returns the JSON data sent. Useful for testing connection works
  result.needed = @[coreCapability]
  result.invocation = newInvocation(
    "Core/echo",
    args,
  )

proc copy*(b: typedesc[Blob], srcAccount, destAccount: string, blobs: seq[string]): Call[CopyResponse] =
  ## Copies blobs from **srcAccount** to **destAccount**. This is recommended over downloading and reuploading
  ## the blobs
  let body = %* {
    "fromAccountId": srcAccount,
    "accountId": destAccount,
    "blobIds": blobs
  }
  result.needed = @[coreCapability]
  result.invocation = newInvocation(
    "Blob/copy",
    body
  )
