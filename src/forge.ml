(* Forging typed AST

   This is *not* to create a well-typed Typedtree.
   This is only to forge a Typedtree AST which will be untypeast'ed 
   to Parsetree immediately.
*)
open Typedtree
open List
open Asttypes

(* a dirty hack *)
let default_loc = ref Location.none

module Dummy = struct

  open Types

  let type_expr = Btype.newgenty (Types.Tvar None)

  let env = Env.empty

  let value_description () = 
    { val_type       = type_expr;
      val_kind       = Val_reg;
      val_loc        = !default_loc;
      val_attributes = [] 
    }

  let exp_desc = Texp_tuple []

  let exp () = 
    { exp_desc;
      exp_loc        = !default_loc;
      exp_extra      = [];
      exp_type       = type_expr;
      exp_env        = env;
      exp_attributes = [] 
    }

  let mod_type = Mty_signature [] 

  let structure_item () = 
    { str_desc = Tstr_recmodule []
    ; str_loc = !default_loc
    ; str_env = env 
    }
end

let loc txt = { Location.loc= !default_loc; txt }

let lidentloc_of_path p = loc @@ Untypeast.lident_of_path p

let with_loc loc f = 
  let back = !default_loc in
  default_loc := loc;
  let res = f () in
  default_loc := back;
  res

module Path = struct
  open Longident
  open Path
  type t = Path.t
  let rec of_lident = function
    | Lident s -> Pident (Ident.create_local s)
    | Ldot (t,s) -> Pdot (of_lident t, s)
    | Lapply (t1,t2) -> Papply (of_lident t1, of_lident t2)
end

module Typ = struct
  open Types
  open Ctype
  let arrow ?(label=Nolabel) t1 t2 = newty (Tarrow (label, t1, t2, Cunknown)) 
end

module Exp = struct

  (* directly embed Parsetree.expression *)    
  let untyped pexp = 
    { (Dummy.exp ()) 
      with exp_attributes= [ {attr_name={txt="typpx_embed"; loc= !default_loc}; 
                              attr_payload=PStr ([ Ast_helper.Str.eval pexp ]);
                              attr_loc = !default_loc } ] }

  let ident p = 
    { (Dummy.exp ()) with
      exp_desc = Texp_ident (p, lidentloc_of_path p, Dummy.value_description ()) } 

  let let_ ?(recursive=false) vbs e =
    { (Dummy.exp ()) with
      exp_desc = Texp_let((if recursive then Recursive else Nonrecursive),
                          vbs,
                          e)
    }

  let letmodule id pres mexpr e =
    { (Dummy.exp ()) with 
      exp_desc = Texp_letmodule (id, loc (Option.map Ident.name id), pres, mexpr, e) }

  let app e les =
    match les with
    | [] -> e
    | _ ->
        { (Dummy.exp ()) with
          exp_desc = Texp_apply(e, map (fun (l,e) -> l, Some e) les)
        }

  let ignore x =
    let lident_ignore = Longident.(Ldot ( Lident "Pervasives", "ignore" )) in
    let path_ignore = Path.of_lident lident_ignore in
    let ignore = ident path_ignore in
    { x with exp_desc = Texp_apply (ignore, [Nolabel, Some x]) }

  let fun_ ?(label=Nolabel) c_lhs e =
    let cases = [ {c_lhs; c_guard=None; c_rhs= e} ] in
    let param = Typecore.name_pattern "param" [c_lhs] in
    { e with exp_desc = Texp_function { arg_label= label
                                      ; param
                                      ; cases
                                      ; partial= Total 
                                      }
    }

  let tuple es = { (Dummy.exp ()) with exp_desc = Texp_tuple es }

  let with_env ev e = { e with exp_env = ev }

  let check_constructor_is_for_path ev s path =
    let lid = Longident.Lident s in
    try
      let cdesc = Env.find_constructor_by_name lid ev in
      match (Ctype.repr cdesc.cstr_res).desc with
      | Tconstr (p, _, _) when p = path -> ()
      | _ -> 
          Format.eprintf "Typpx.Forge.Exp: %a is not accessible in this scope@." Printtyp.longident lid;
          assert false
    with Not_found ->
      Format.eprintf "Typpx.Forge.Exp: %a is not accessible in this scope@." Printtyp.longident lid;
      assert false
    
  let none ?(ty=Dummy.type_expr) ev =
    check_constructor_is_for_path ev "None" Predef.path_option; 
    Typecore.option_none ev ty !default_loc
      
  let some ev e =
    check_constructor_is_for_path ev "Some" Predef.path_option; 
    Typecore.option_some ev e

  let list ev es =
    check_constructor_is_for_path ev "::" Predef.path_list;
    check_constructor_is_for_path ev "[]" Predef.path_list;
    let ty = match es with
      | [] -> Dummy.type_expr
      | e::_ -> e.exp_type
    in
    let cnull = Env.find_constructor_by_name (Longident.Lident "[]") ev in
    let ccons = Env.find_constructor_by_name (Longident.Lident "::") ev in
    let null ty = 
      { (Dummy.exp ()) with
        exp_desc = Texp_construct ( loc (Longident.Lident "[]"),
                                    cnull, [] );
        exp_type = Predef.type_list ty
      }
    in
    let cons e e' =
      { (Dummy.exp ()) with
        exp_desc = Texp_construct ( loc (Longident.Lident "::"),
                                    ccons, [e; e'] ) }
    in
    fold_right (fun e st ->
      { (cons e st) with exp_type = Predef.type_list e.exp_type })
      es (null ty)
      
  open Asttypes

  let ghost l = { l with Location.loc_ghost = true }
  let mark txt e =
    { e with exp_attributes= {attr_name={txt; loc= ghost e.exp_loc};
                              attr_payload=Parsetree.PStr [];
                              attr_loc = ghost e.exp_loc} 
                             :: e.exp_attributes }

  let partition_map f xs =
    let rec part left right = function
      | [] -> rev left, rev right
      | x::xs ->
          match f x with
          | `Left v -> part (v::left) right xs
          | `Right v -> part left (v::right) xs
    in
    part [] [] xs

  let partition_marks e f =
    let g = function
      | {Parsetree.attr_name={txt}; attr_payload=Parsetree.PStr [];_} when f txt -> `Left txt
      | a -> `Right a
    in
    let marks, exp_attributes = partition_map g e.exp_attributes in
    marks,
    { e with exp_attributes }

end

module Pat = struct

  let desc d = 
    { pat_desc = d;
      pat_loc = !default_loc;
      pat_extra = [];
      pat_type = Dummy.type_expr;
      pat_env = Dummy.env;
      pat_attributes = [];
    }

  let var id = desc (Tpat_var (id, loc (Ident.name id)))
end

module MB = struct
  let module_binding id pres x = { mb_id = id
                            ; mb_name = loc (Option.map Ident.name id)
                            ; mb_presence = pres
                            ; mb_expr = x
                            ; mb_attributes = []
                            ; mb_loc = !default_loc 
                            } 
end

module Mod = struct
  let of_module_expr_desc d = 
    { mod_desc = d;
      mod_loc = !default_loc;
      mod_type = Dummy.mod_type;
      mod_env = Dummy.env;
      mod_attributes = [] }

  let ident p = of_module_expr_desc @@ Tmod_ident (p, lidentloc_of_path p)

  let unpack e = of_module_expr_desc @@ Tmod_unpack (e, Dummy.mod_type)
end
