# Package

version       = "0.2.0"
author        = "Jake Leahy"
description   = "JMAP library for nim"
license       = "MIT"
srcDir        = "src"


# Dependencies

requires "nim >= 2.2.4"
requires "anano >= 0.2.0 & < 0.3.0"
requires "casserole >= 0.3.0"

task buildContainer, "Builds test mail server container":
  exec "podman build --tag mail-memory tests/image/"

task startContainer, "Starts the test mail server container":
  try:
    exec "docker run -d --network host -v $PWD/tests/testdata/config.toml:/opt/stalwart/etc/config.toml:ro --name test-mail stalwartlabs/stalwart:latest"
  except OSError:
    exec "docker start test-mail"
  exec "bash tests/testdata/provision.sh"

task stopContainer, "Stops the test mail server container":
  exec "docker stop --time 0 test-mail"
  exec "docker rm test-mail"

task cleanContainer, "Removes container and image":
  try: exec "docker image rm mail-memory" except: discard
