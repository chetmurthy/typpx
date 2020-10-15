open Types
open Typedtree

let print_ident ppf id = Ident.print ppf id

let rec print_path ppf = function
  | Path.Pident id -> print_ident ppf id
  | Path.Pdot (p, name) -> Format.fprintf ppf "%a.%s" print_path p name
  | Path.Papply (p1, p2) -> Format.fprintf ppf "%a(%a)" print_path p1 print_path p2

let get_name = function
  | Path.Pident id -> Ident.name id
  | Path.Pdot (_, name) -> name
  | Path.Papply _ -> assert false

let test env ty vdesc =
  let snapshot = Btype.snapshot () in
  let ity = Ctype.instance vdesc.val_type in
  let res = try  Ctype.unify env ty ity; true with _ -> false in
  Btype.backtrack snapshot;
  res

let resolve_overloading exp lidloc path = 
  let env = exp.exp_env in

  let name = get_name path in

  let rec find_candidates (path : Path.t) mty =
    (* Format.eprintf "Find_candidates %a@." print_path path; *)

    let sg = 
      match Env.scrape_alias env @@ Mtype.scrape env mty with
      | Mty_signature sg -> sg
      | _ -> assert false
    in
    List.fold_right (fun sitem st -> match sitem with
    | Sig_value (id, _vdesc, _) when Ident.name id = name -> 
        let lident = Longident.Ldot (Untypeast.lident_of_path path, Ident.name id) in
        let path, vdesc = Env.lookup_value lident env  in
        if test env exp.exp_type vdesc then (path, vdesc) :: st else st
    | Sig_module (id, _, _mty, _, _) -> 
        let lident = Longident.Ldot (Untypeast.lident_of_path path, Ident.name id) in
        let path = Env.lookup_module ~load:true (*?*) lident env  in
        let moddecl = Env.find_module path env in
        find_candidates path moddecl.Types.md_type @ st
    | _ -> st) sg []
  in
  
  let lid_opt = match path with
    | Path.Pident _ -> None
    | Path.Pdot (p, _) -> Some (Untypeast.lident_of_path p)
    | Path.Papply _ -> assert false
  in

  match 
    Env.fold_modules (fun _name path moddecl st -> 
      find_candidates path moddecl.Types.md_type @ st) lid_opt env []
  with
  | [] -> 
     Location.raise_errorf ~loc:lidloc.Asttypes.loc "Overload resolution failed: no match"
  | [path, vdesc] -> 
      (* Format.eprintf "RESOLVED: %a@." print_path path; *)
      let ity = Ctype.instance vdesc.val_type in
      Ctype.unify env exp.exp_type ity; (* should succeed *)
      { exp with 
        exp_desc = Texp_ident (path, {lidloc with Asttypes.txt = Untypeast.lident_of_path path}, vdesc);
        exp_type = exp.exp_type }
  | _ -> 
     Location.raise_errorf ~loc:lidloc.loc "Overload resolution failed: too ambiguous"

let expr sub = function
    | ({ exp_desc= Texp_ident (path, lidloc, vdesc) } as e)-> 
        begin match vdesc.val_kind with
        | Val_prim { Primitive.prim_name = "__OVERLOADED" } ->
           resolve_overloading e lidloc path
        | _ -> e
        end
    | e -> Tast_mapper.default.expr sub e

let mapper = {
  Tast_mapper.default with
  expr = expr
}

module Map = struct
  let map_structure st = mapper.structure mapper st
  let map_signature sg = mapper.signature mapper sg
end
