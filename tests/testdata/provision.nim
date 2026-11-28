import std/[httpclient, json, os, osproc, strutils, tables, times, uri, strformat]
import jamp

const stalwartCapability = "urn:stalwart:jmap"

let
  recoveryUrl   = getEnv("RECOVERY_URL", "http://localhost:8080")
  apiUrl        = getEnv("API_URL", "http://127.0.0.1:80")
  containerName = getEnv("CONTAINER_NAME", "test-mail")
  image         = getEnv("IMAGE", "stalwartlabs/stalwart:v1.2.1")
  configPath    = getEnv("CONFIG_PATH", getCurrentDir() / "tests/testdata/config.json")
  dataVolume    = getEnv("DATA_VOLUME", "test-mail-data")
  emlDir        = currentSourcePath().absolutePath().parentDir() / "eml"

let
  recoveryHost = parseUri(recoveryUrl)
  apiHost      = parseUri(apiUrl)

# Only use stalwart stuff in here, no need to shove in library

proc xcall(name: string, args: JsonNode, id = ""): Call[JsonNode] =
  ## Calls a Stalwart management method (x:* namespace)
  initCall[JsonNode](@[coreCapability, stalwartCapability], name, args, id)

proc xset(name: string,
          create: Table[string, JsonNode] = initTable[string, JsonNode](),
          update: Table[string, JsonNode] = initTable[string, JsonNode](),
          destroy: seq[string] = @[],
          id = ""): Call[JsonNode] =
  ## Wrapper for Stalwart's management `x:*/set` methods
  ## (x:Domain/set, x:SystemSettings/set, x:Account/set, ...)
  let args = newJObject()
  if create.len > 0: args["create"] = create.toJson()
  if update.len > 0: args["update"] = update.toJson()
  if destroy.len > 0: args["destroy"] = %destroy
  xcall(name, args, id)

#
# Helpers
#

proc newClient(user, pass: string): HttpClient =
  var headers = newHttpHeaders()
  basicAuth(user, pass)(headers)
  return newHttpClient(headers = headers)

proc waitFor(host: Uri, user, pass: string) =
  ## Polls the session endpoint until the server responds
  let http = newClient(user, pass)
  for i in 1 .. 30:
    try:
      if http.get(host / "jmap/session").code.is2xx:
        return
    except CatchableError:
      if i < 30:
        discard
    sleep 2000

proc primaryAccount(host: Uri, user, pass, capability: string): string =
  ## The library's Session type doesn't include primaryAccounts so fetch it raw
  let http = newClient(user, pass)
  http.getContent(host / "jmap/session").parseJson()["primaryAccounts"][capability].str

proc run(cmd: string, args: varargs[string]) =
  let process = startProcess(cmd, args = args, options = {poStdErrToStdOut, poUsePath})
  let (lines, exCode) = process.readLines
  if exCode != 0:
    let output = lines.join("\n")
    raise (ref OSError)(msg: fmt"{cmd} failed ({exCode}): {output}")

proc show(resp: JMAPResponse, calls: varargs[Call[JsonNode]]) =
  ## Prints each call's response. resp[call] raises if the call errored
  for call in calls:
    echo fmt"{call.invocation.name} [{call.id}]: {resp[call].pretty}"

proc stopContainer() =
  run("docker", "stop", containerName)
  run("docker", "rm", containerName)
proc startContainer(recovery = false) =
  run("docker", "run", "-d", "--network=host", "--user=root",
      "-v", fmt"{configPath}:/etc/stalwart/config.json:ro",
      "-v", fmt"{dataVolume}:/var/lib/stalwart",
      "-e", fmt"STALWART_PUBLIC_URL={apiUrl}",
      "-e", fmt"STALWART_RECOVERY_MODE={recovery.ord}",
      "-e", "STALWART_RECOVERY_ADMIN=admin:admin",
      "--name", containerName,
      image)

proc main() =
  startContainer(true)
  echo fmt"Waiting for recovery API on {recoveryUrl}..."
  waitFor(recoveryHost, "admin", "admin")
  echo "Recovery API is up"

  let admin = newJMAPClient(basicAuth("admin", "admin"), recoveryHost)
  admin.startSession()

  echo "Applying base config (domain, settings, http listener)..."
  let
    domain = xset("x:Domain/set", id = "c1", create = {
      "dom": %* {
        "name": "example.org",
        "certificateManagement": %* {"@type": "Manual"},
        "dkimManagement": %* {"@type": "Automatic"},
        "dnsManagement": %* {"@type": "Manual"}
      }
    }.toTable)
    settings = xset("x:SystemSettings/set", id = "c2", update = {
      "singleton": %* {
        "defaultHostname": "127.0.0.1",
        "defaultDomainId": "#dom"
      }
    }.toTable)
    authSettings = xset("x:Authentication/set", id = "c3", update = {
      "singleton": %* {"minPasswordLength": 1, "minPasswordStrength": "zero"}
    }.toTable)
    listener = xset("x:NetworkListener/set", id = "c4", create = {
      "http80": %* {
        "name": "http80",
        "protocol": "http",
        "bind": %* {"0.0.0.0:80": true, "[::]:80": true},
        "useTls": false,
        "implicitTls": false
      }
    }.toTable)
  var req: JMAPRequest
  req &= domain
  req &= settings
  req &= authSettings
  req &= listener
  let baseResp = admin.request(req)
  baseResp.show(domain, settings, authSettings, listener)
  let domainId = baseResp[domain]["created"]["dom"]["id"].str
  echo "Domain id: ", domainId

  echo "Reloading settings (password policy)..."
  discard admin.request(xset("x:Action/set", id = "c1", create = {
    "r": %* {"@type": "ReloadSettings"}
  }.toTable))
  sleep 2000

  echo "Creating accounts..."
  let accounts = xset("x:Account/set", id = "c1", create = {
    "alice": %* {
      "@type": "User",
      "name": "alice",
      "domainId": domainId,
      "description": "Alice",
      "credentials": %* {"0": %* {"@type": "Password", "secret": "aliceSecret"}},
      "roles": %* {"@type": "User"}
    },
    "bob": %* {
      "@type": "User",
      "name": "bob",
      "domainId": domainId,
      "description": "Bob",
      "credentials": %* {"0": %* {"@type": "Password", "secret": "bobSecret"}},
      "roles": %* {"@type": "User"}
    },
    "everyone": %* {
      "@type": "Group",
      "name": "everyone",
      "domainId": domainId,
      "description": "Everyone group"
    }
  }.toTable)
  let accountsResp = admin.request(accounts)
  echo accountsResp.pretty
  let
    aliceId = accountsResp["created"]["alice"]["id"].str
    bobId   = accountsResp["created"]["bob"]["id"].str
    groupId = accountsResp["created"]["everyone"]["id"].str
  echo "Alice: ", aliceId, "  Bob: ", bobId, "  Group: ", groupId

  echo "Adding alice and bob to group..."
  var memberUpdate = initTable[string, JsonNode]()
  for id in [aliceId, bobId]:
    let patch = newJObject()
    patch["memberGroupIds/" & groupId] = %true
    memberUpdate[id] = patch
  discard admin.request(xset("x:Account/set", id = "c1", update = memberUpdate))

  # Restart without recovery mode, don't need admin anymore
  stopContainer()
  startContainer()

  echo "Waiting for JMAP API on ", apiUrl, "..."
  waitFor(apiHost, "alice", "aliceSecret")
  echo "JMAP API is up"

  let client = newJMAPClient(basicAuth("alice", "aliceSecret"), apiHost)
  client.startSession(insecure = true)
  let accountId = primaryAccount(apiHost, "alice", "aliceSecret", mailCapability)
  echo "Alice account id: ", accountId

  echo "Importing test emails..."
  let boxes = client.request(Mailbox.get(accountId, properties = Mailbox.props(id, name)))
  var inbox = ""
  for box in boxes.list:
    if box.name == "Inbox":
      inbox = box.id
  if inbox == "":
    raise (ref KeyError)(msg: "Couldn't find Inbox mailbox")
  echo "Inbox: ", inbox

  let received = now()
  for eml in [emlDir / "1.eml", emlDir / "3.eml"]:
    let blob = client.uploadBlob(accountId, "message/rfc822", readFile(eml))
    let name = extractFilename(eml).changeFileExt("")
    echo "Importing ", eml, " as blob ", blob.id, "..."
    let resp = client.request(Email.importMail(accountId, emails = {
      name: EmailImport(
        blobId: blob.id,
        mailboxIds: {inbox: true}.toTable,
        keywords: initTable[string, bool](),
        receivedAt: received
      )
    }.toTable))
    echo resp.toJson().pretty

  echo "Provisioning complete!"

main()
