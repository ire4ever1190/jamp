# Package

version       = "0.1.0"
author        = "Jake Leahy"
description   = "JMAP library for nim"
license       = "MIT"
srcDir        = "src"


# Dependencies

requires "nim >= 1.6.0"
requires "anano >= 0.2.0 & < 0.3.0"

task buildContainer, "Builds test mail server container":
  exec "podman build --tag mail-memory tests/image/"

task startContainer, "Starts the test mail server container":
  try:
    exec "docker run -d -ti -p 80:8080 -p 11200:11200 --name test-mail stalwartlabs/jmap-server:latest --jmap-url=http://localhost"
  except OSError:
    exec "docker start test-mail"
  exec "sleep 1 && sh tests/testdata/provision.sh"
    
task stopContainer, "Stops the test mail server container":
  exec "docker stop --time 0 test-mail"
  exec "docker rm test-mail"

task cleanContainer, "Removes container and image":
  try: exec "docker image rm mail-memory" except: discard
