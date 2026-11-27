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

task startContainer, "Starts the test mail server container":
  # Stalwart v1.x keeps its config in the data store, so boot once in recovery
  # mode for provision.sh to apply the config, then restart in normal mode
  try: exec "docker rm -f test-mail"
  except OSError: discard
  try: exec "docker volume rm test-mail-data"
  except OSError: discard
  exec "docker run -d --network host --user root -v $PWD/tests/testdata/config.json:/etc/stalwart/config.json:ro -v test-mail-data:/var/lib/stalwart -e STALWART_RECOVERY_MODE=1 -e STALWART_RECOVERY_ADMIN=admin:admin --name test-mail stalwartlabs/stalwart:v1.2.1"
  exec "bash tests/testdata/provision.sh"

task stopContainer, "Stops the test mail server container":
  try: exec "docker stop --time 0 test-mail"
  except OSError: discard
  try: exec "docker rm test-mail"
  except OSError: discard

task cleanContainer, "Removes container, data volume and image":
  try: exec "docker rm -f test-mail"
  except OSError: discard
  try: exec "docker volume rm test-mail-data"
  except OSError: discard
  try: exec "docker image rm stalwartlabs/stalwart:v1.2.1"
  except OSError: discard
