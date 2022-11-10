import std/[osproc, unittest, sequtils, options]
import jamp

import jamp/specs/core


test "Unauthorised requests are handled":
  try:
    let client = newJMAPClient(basicAuth("alice@example.org", "incorrect"), "127.0.0.1:80")
    client.startSession(insecure=true)
    check false
  except JMapError as e:
    check e.msg == "Auth details are incorrect"
  
  
let client = newJMAPClient(basicAuth("alice@example.org", "aliceSecret"), "127.0.0.1:80")
test "Start session":
  client.startSession(insecure=true)

test "Connection works":
  let body = %* {
    "foo": "bar" 
  }
  let echo = Core.echo(body)
  var request: JMAPRequest
  request &= echo
  let resp = client.request(request)
  check resp[echo] == body

proc findId(name: string): string =
  ## Finds ID for account that has name
  for id, account in client.session.accounts:
    if account.name == name:
      return id

let
  groupID = findId("everyone")
  accountID = findId("Alice")

suite "Mailboxes":
  test "Get":
    let boxes = client.request(
      Mailbox.get(accountID, properties = Mailbox.props(id, name))
    )
    check boxes.list.mapIt(it.name) == @["Inbox", "Deleted Items", "Drafts", "Sent Items", "Junk Mail"]

# echo client.request(Email.query(accountID))[]

suite "Blobs":
  test "Downloading blob":
    let
      query = Email.query(accountID, filter = newFilter(%* {
        "hasAttachment": true,
        "subject": "Attachment test"
      }))
      get = Email.get(accountID, ids = query.reuseIt(ids[]), properties = @["id", "attachments"])

    var req: JMAPRequest
    req &= query
    req &= get
    let resp = client.request(req)
    echo resp[get].list
    let blobID = resp[get].list[0]["attachments"][0]["blobId"].str
    check client.downloadBlob(accountID, blobID) == "Hello world\n" 

  test "Uploading blob":
    let
      blobData = "Hello world"
      blob = client.uploadBlob(accountID, "text/plain", blobData)
    check:
      blob.accountID == accountID
      blob.fileType == "text/plain"
      blob.size == blobData.len.uint

  test "Copying blob":
    const blob = "hello wolrd"
    let
      origBlob = client.uploadBlob(groupID, "text/plain", blob)
      resp = client.request(Blob.copy(groupID, accountID, @[origBlob.id]))
      newID = resp.copied.get()[origBlob.id]
    check client.downloadBlob(accountID, newID) == blob
