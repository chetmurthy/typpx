module Num = struct
  module Int = struct
    let (+) = Stdlib.(+)
  end
  
  module Float = struct
    let (+) = Stdlib.(+.)
  end
end

module String = struct
  let (+) = Stdlib.(^)
end

module Loaded = struct
  module Num = Num
  module String = String
  external (+) : 'a -> 'a -> 'a = "__OVERLOADED"
end

module Test = struct
  open Loaded
  let () = 
    assert (1 + 2 = 3);
    assert (1.2 + 3.4 = 4.6);
    assert ("hello" + "world" = "helloworld");
    prerr_endline "Ok!"
end

let _ = (Loaded.(+) : int -> int -> int)
