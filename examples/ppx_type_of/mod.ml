open Asttypes
open Typedtree

  let expr sub e =
    match e.exp_desc with
    | Texp_apply ({ exp_desc= Texp_ident(Pdot(Pident id, "type_of"), _, _) }, args) when Ident.name id = "Ppx_type_of" ->
        begin match args with
        | [Nolabel, Some ({ exp_type= ty } as _a) ] ->
            let s =
              Printtyp.reset ();
              Printtyp.mark_loops ty;
              Format.asprintf "%a" Printtyp.type_expr ty
            in
            let name =
              { e with exp_desc = Texp_constant (Const_string (s, None)) }
            in
            name

        | _ -> assert false (* better error handling required *)
        end
    | _ -> Tast_mapper.default.expr sub e
        
let mapper = { Tast_mapper.default with
               expr = expr }

module Map = struct
  let map_structure st = mapper.structure mapper st
  let map_signature sg = mapper.signature mapper sg
end
