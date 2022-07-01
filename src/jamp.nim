when not defined(ssl):
  {.error: "JAMP requires ssl to be enabled (via -d:ssl)".}
import jamp/client
import jamp/common
import jamp/jsonptr

export jsonptr
export client
export common
