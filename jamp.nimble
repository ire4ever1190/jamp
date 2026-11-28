# Package

version       = "0.2.2"
author        = "Jake Leahy"
description   = "JMAP library for nim"
license       = "MIT"
srcDir        = "src"


# Dependencies

requires "nim >= 2.2.4"
requires "anano >= 0.2.0 & < 0.3.0"
requires "gh:ire4ever1190/casserole >= 0.3.0"

task stopContainer, "Stops the test mail server container":
  try: exec "docker stop --timeout 0 test-mail"
  except OSError: discard
  try: exec "docker rm test-mail"
  except OSError: discard

task cleanContainer, "Removes container, data volume and image":
  stopContainerTask()
  try: exec "docker volume rm test-mail-data"
  except OSError: discard
  try: exec "docker image rm stalwartlabs/stalwart:v1.2.1"
  except OSError: discard

task startContainer, "Starts the test mail server container":
  cleanContainerTask()
  exec "nim r tests/testdata/provision.nim"
