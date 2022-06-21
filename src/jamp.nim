when not defined(ssl):
  {.error: "JAMP requires ssl to be enabled (via -d:ssl)".}
import jamp/client
import jamp/common

export client
export common
