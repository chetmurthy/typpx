module Loaded = struct
  val%overloaded (+) : 'a -> 'a -> 'a
  module Int = struct
    let (+) = Stdlib.(+)
  end
  module Float = struct
    let (+) = Stdlib.(+.)
  end
end

open Loaded
let _ = 
  assert (1 + 2 = 3);
  assert (1.2 + 3.4 = 4.6); (* See it is not +. but + !!! *)
  prerr_endline "OK!"
