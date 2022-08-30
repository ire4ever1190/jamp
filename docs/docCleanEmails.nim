import examplemaker/dsl

title("Email cleaner", "Writing a script to delete old emails using jamp")
author("Jake Leahy")

text """
  In this example we will make a small script that will remove emails that are older than a certain date.
  This will show how to
   - Connect to a JMAP server
   - Make querys
   - Make requests
   - Alter data
"""

text """
  We start by importing the library, making our client, then starting our session with the server
"""

codeBlock:
  import jamp
  const
    # You need to get this info yourself somehow
    accountID = "1234" # ID of the account we are operating against
    trashID   = "4567" # ID of the trash mailbox
    
  let client = newJMAPClient(basicAuth("our@email.com", "password"), "host")
  client.startSession()

text """
  Next we will make our filters to remove emails from. We will just make a simple filter
  that deletes emails from notification senders that are older than certain days.
"""

codeBlock:
  import std/times
  
  const deleteFrom = {
    "notifications@instructure.com": 4.days,
    "notifications@github.com": 7.days,
    "notifications@indeed.com": 4.days
  }

  # We then combine them into a filter that JMAP understands
  var deleteFilter = FilterOperator(operator: Or)
  let currTime = now()
  for (author, offset) in deleteFrom:
    deleteFilter = deleteFilter or newFilter(%* {
      "from": author,
      "before": (currTime - offset).formatUTCDate()
    })

text """
  Has shown above the filter can be joined together using normal boolean operators
"""

text """
  Now that we have a filter, we need to query the server and get the emails.
  In JMAP we call methods on the server and multiple methods can be sent at once. We can also
  tell the server to reuse a previous method call to save us having to make multiple requests.

  We are going to build our request by making a **query** using our filter made before and then passing
  that result into a **get** method so we can get the needed info
"""

codeBlock:
  let
    query = Email.query(
      accountID,
      # We don't want to delete emails already in trash
      filter = deleteFilter and newFilter(%* {
        "inMailboxOtherThan": @[trashID]
      })
    )
    get = Email.get(
      accountID,
      # We reuse the IDs that will be returned
      # from the query request
      ids = query.reuseIt(ids[]),
      properties = @["id", "mailboxIds"]
    )

text """
  Now that we have built the methods, we still need to send them.
  We do this by making a request object and adding the methods to it. Internally
  this builds up a request object which knows the needed capabilities to send to the server
"""

codeBlock:
  var req = JMAPRequest()
  req &= query
  req &= get
  var resp = client.request(req)

  # Make sure they completed successfully
  assert resp.ok(query), "Query method failed"
  assert resp.ok(get), "Get method failed"

text """
  Now we have the id of each Email that passed the filter along with the mailboxes that it is apart of.
  With that we can build a `PathObject` to move it out of its current mailboxes and into the trash
"""

codeBlock:
  import std/tables
  
  var toDelete: Table[string, PatchObject]
  for email in resp[get]["list"]:
    var patch: PatchObject
    for mailbox, _ in email["mailboxIds"]:
      # Remove it from current inbox
      patch["mailboxIds/" & mailbox] = newJNull()
    # Add it to the trash
    patch["mailboxIds/" & trashID] = %true
    # Set the patch for the email
    toDelete[email["id"].str] = patch

text """
  Now that we have the patch made, we can apply it to the server with the **set** method by
  building a request like we did before and sending it off
"""

codeBlock:
  let delete = Email.set(
    accountId,
    update = toDelete
  )

  req = JMAPRequest()
  req &= delete

  resp = client.request(req)
  assert resp.ok(delete), "Deleting failed"

text """
  Once you run that, if nothing fails, then any emails from those addresses and older than those days should be in
  your trash instead of your inbox. 

  Now that you understand the basics of JMAP and using Jamp you should be able to go off and build something even cooler
"""

details "Full code":
  showFullCode()
