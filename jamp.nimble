# Package

version       = "0.1.0"
author        = "Jake Leahy"
description   = "JMAP library for nim"
license       = "MIT"
srcDir        = "src"


# Dependencies

requires "nim >= 1.7.0"
requires "anano >= 0.2.0 & < 0.3.0"

task startContainer, "Starts the test mail server container":
  exec "docker run -d -ti --rm -p 80:8080 -p 11200:11200 --name test-mail stalwartlabs/mail-server:v0.10.5 --jmap-url=http://localhost"
  exec "docker cp tests/testdata/provision.sh test-mail:/tmp/provision.sh"
  exec "docker exec test-mail chmod 777 /tmp/provision.sh && docker exec test-mail /tmp/provision.sh"


task stopContainer, "Stops the test mail server container":
  exec "docker stop --time 0 test-mail"

task cleanContainer, "Removes container and image":
  try: exec "docker image rm mail-memory" except: discard
