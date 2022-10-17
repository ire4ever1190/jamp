import std/[osproc, unittest, sequtils]
import jamp

import jamp/specs/core


let (ip, _) = execCmdEx("podman inspect test-mail -f '{{ .NetworkSettings.IPAddress }}'")


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

let accountID = client.session.accounts.keys().toSeq[0]

suite "Mailboxes":
  test "Get":
    let boxes = client.request(
      Mailbox.get(accountID, properties = Mailbox.props(id, name))
    )
    check boxes.list.mapIt(it.name) == @["Inbox", "Deleted Items", "Drafts", "Sent Items", "Junk Mail"]

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

