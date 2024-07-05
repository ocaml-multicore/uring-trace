let c_headers =
  {|#include <liburing.h>
#include "uring.h"|}

let () =
  Format.printf "%s@\n" c_headers;
  Cstubs_structs.write_c Format.std_formatter (module Stubs.Bindings);
