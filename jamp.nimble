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
    exec "podman run --network podman -d --name test-mail -p 8000:8000 -p 8443:443 localhost/mail-memory"
    echo "Importing test data... (This will take a whiles)"
    exec "podman exec test-mail bash /root/provision.sh"
  except OSError:
    exec "podman start test-mail"
    
task stopContainer, "Stops the test mail server container":
  exec "podman stop --time 0 test-mail"
