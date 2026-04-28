import std/[osproc, unittest, sequtils, options, strutils, algorithm, tables, times]
import jamp

import pkg/[anano, casserole]

import jamp/specs/core


test "Unauthorised requests are handled":
  try:
    let client = newJMAPClient(basicAuth("alice", "incorrect"), "127.0.0.1:80")
    client.startSession(insecure=true)
    check false
  except JMapError as e:
    check e.msg == "Auth details are incorrect"


let client = newJMAPClient(basicAuth("alice", "aliceSecret"), "127.0.0.1:80")

test "Start session":
  client.startSession(insecure=true)

if not client.hasSession():
  # Still start session. Helpful if running tests other than "Start Session"
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
  var names: seq[string]
  for id, account in client.session.accounts:
    names &= account.name
    if account.name == name:
      return id
  raise (ref KeyError)(msg: "Can't find " & name & " [Available: " & names.join(", ") & "]")

let
  accountID = findId("alice")

suite "Mailboxes":
  test "Get":
    let boxes = client.request(
      Mailbox.get(accountID, properties = Mailbox.props(id, name))
    )
    check sorted(boxes.list.mapIt(it.name)) == @["Deleted Items", "Drafts", "Inbox", "Junk Mail", "Sent Items"]



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

  test "Copying blob":
    const blob = "hello wolrd"
    let
      origBlob = client.uploadBlob(accountID, "text/plain", blob)
      resp = client.request(Blob.copy(accountID, accountID, @[origBlob.id]))
      newID = resp.copied.get()[origBlob.id]
    check client.downloadBlob(accountID, newID) == blob

proc deleteEmail(id: string) =
  let req = Email.setVal(accountId, destroy = @[id])
  assert id in client.request(req).destroyed.get()


suite "Mail":
  let inbox = block:
    let boxes = client.request(
      Mailbox.get(accountID, properties = Mailbox.props(id, name))
    )
    var inbox = ""
    for box in boxes.list:
      if box.name == "Inbox":
        inbox = box.id
    assert inbox != ""
    inbox

  let testEmail = client.uploadBlob(accountID, "application/mbox", "tests/testdata/eml/4.eml".readFile())

  test "Importing mail":
    let
      id = $genNanoId()
      # Import it
      resp = client.request(
        EMail.importMail(accountID, emails = {
          id: EmailImport(
            blobId: testEmail.id,
            mailboxIds: @{
              $inbox: true
            }.toTable(),
            receivedAt: now()
          )
        }.toTable)
      )
    # Check it was created
    let newId = resp.created.get()[id]["id"].to(string)
    defer: deleteEmail(newId)

    # And see if we can get it
    let
      getRequest = Email.get(accountID, @[newId])
      getResp = client.request(
        getRequest
      )
    check getResp.list[0]["id"].to(string) == newId

  test "Changes":
    # Get initial state
    let state = client.request(Email.get(accountId)).state

    # Change the state
    let newId = client.request(
      Email.importMail(accountID, emails = {
        "foo": EmailImport(
          blobId: testEmail.id,
          mailboxIds: @{
            $inbox: true
          }.toTable(),
          receivedAt: now()
        )
      }.toTable)
    ).created.get()["foo"]["id"].to(string)
    defer: deleteEmail(newId)

    # Changes should just have that
    let changes = client.request(Email.changes(accountId, state))
    check changes.created.len > 0

  test "Query Changes":
    # Get initial state from first query
    let filter = newFilter(%* {
      "subject": "Dummy Email"
    })
    let state = client.request(Email.query(accountId, filter = filter)).queryState

    # Change the state
    let newId = client.request(
      Email.importMail(accountID, emails = {
        "foo": EmailImport(
          blobId: testEmail.id,
          mailboxIds: @{
            $inbox: true
          }.toTable(),
          receivedAt: now()
        )
      }.toTable)
    ).created.get()["foo"]["id"].to(string)
    defer: deleteEmail(newId)

    # Changes should just have that
    let changes = client.request(Email.queryChanges(accountId, state, filter=filter))
    check changes.added.len > 0
