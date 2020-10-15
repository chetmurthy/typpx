(**************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*             Xavier Leroy, projet Cristal, INRIA Rocquencourt           *)
(*                                                                        *)
(*   Copyright 1996 Institut National de Recherche en Informatique et     *)
(*     en Automatique.                                                    *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)

open! Clflags
open! Compenv

module Options = Main_args.Make_bytecomp_options (Main_args.Default.Main)

let compiler_libs_options =
  let inappropriate =
    [ "-a"
    ; "-c"
    ; "-cc"
    ; "-cclib"
    ; "-ccopt"
    ; "-compat-32"
    ; "-custom"
    ; "-dllib"
    ; "-dllpath"
    ; "-for-pack"
    ; "-g"
    (* ; "-i" *)
    ; "-linkall"
    ; "-make-runtime"
    ; "-make_runtime"
    ; "-noassert"
    ; "-noautolink"
    ; "-o"
    ; "-output-obj"
    ; "-pack"
    ; "-pp"
    ; "-ppx"
    ; "-runtime-variant"
    ; "-use-runtime"
    ; "-use_runtime"
    ; "-where"
    ; "-"
    ; "-nopervasives"
    ; "-use-prims"
    ; "-drawlambda"
    ; "-dlambda"
    ; "-dinstr"
    ; "-dtimings"
    ; "-dprofile"
    ]
  in
  List.filter (fun (n,_,_) -> not @@ List.mem n inappropriate) Options.list

