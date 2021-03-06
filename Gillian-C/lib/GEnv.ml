open Gillian.Concrete
module GUtils = Gillian.Utils

type def = FunDef of string | GlobVar of string

type t = {
  symb : (string, string) PMap.t;  (** maps symbols to loc names *)
  defs : (string, def) PMap.t;  (** maps loc names to definitions *)
}

let find_opt x s = try Some (PMap.find x s) with Not_found -> None

let find_symbol genv sym =
  try PMap.find sym genv.symb
  with Not_found -> failwith ("Can't find symbol " ^ sym ^ " !")

let set_symbol genv sym block =
  let symb = PMap.add sym block genv.symb in
  { genv with symb }

let find_def genv block = PMap.find block genv.defs

let set_def genv block def =
  let defs = PMap.add block def genv.defs in
  { genv with defs }

let empty = { symb = PMap.empty; defs = PMap.empty }

(** Serialization of definitions *)
let serialize_def def =
  let open Gillian.Gil_syntax.Literal in
  match def with
  | FunDef fname  -> LList [ String "function"; String fname ]
  | GlobVar vname -> LList [ String "variable"; String vname ]

let deserialize_def sdef =
  let open Gillian.Gil_syntax.Literal in
  match sdef with
  | LList [ String "function"; String fname ] -> FunDef fname
  | LList [ String "variable"; String vname ] -> GlobVar vname
  | _ ->
      failwith (Format.asprintf "Invalid global definition : %a" Values.pp sdef)

(* Pretty printing *)

let pp_def fmt def =
  match def with
  | FunDef f  -> Format.fprintf fmt "(Function %s)" f
  | GlobVar v -> Format.fprintf fmt "(Variable %s)" v

let pp fmt genv =
  let rec aux not_printed vlist =
    match vlist with
    | []     ->
        Format.fprintf fmt "There are %i unimplemented external functions@]@\n"
          not_printed
    | s :: r ->
        let new_not_printed =
          try
            let l = find_symbol genv s in
            let d = find_def genv l in
            match d with
            | FunDef f
              when String.equal f CConstants.Internal_Functions.not_implemented
              -> not_printed + 1
            | _ ->
                let () =
                  Format.fprintf fmt "'%s' -> %s -> %a@\n" s l pp_def d
                in
                not_printed
          with Not_found ->
            let () = Format.fprintf fmt "Error unkown symbol %s@\n" s in
            not_printed
        in
        aux new_not_printed r
  in
  if !Config.hide_genv then Format.fprintf fmt "{@[<v 2>@\nHIDDEN@]@\n}"
  else
    let () = Format.fprintf fmt "{@[<v 2>@\n" in
    let keys = List.rev (PMap.foldi (fun k _ l -> k :: l) genv.symb []) in
    let () = aux 0 keys in
    Format.fprintf fmt "}"

let substitution subst genv =
  let open Gillian.Gil_syntax in
  let open Gillian.Symbolic in
  let aloc_subst =
    Subst.filter subst (fun var _ -> GUtils.Names.is_aloc_name var)
  in
  let rename old_loc new_loc pmap =
    match find_opt old_loc pmap with
    | Some target -> PMap.add new_loc target (PMap.remove old_loc pmap)
    | None        -> pmap
  in
  (* Then we substitute the locations *)
  Subst.fold aloc_subst
    (fun old_loc new_loc cgenv ->
      let new_loc =
        match new_loc with
        | Lit (Loc loc) | ALoc loc -> loc
        | _                        ->
            failwith
              (Format.asprintf "Heap substitution failed for loc : %a" Expr.pp
                 new_loc)
      in
      {
        symb = rename old_loc new_loc cgenv.symb;
        defs = rename old_loc new_loc cgenv.defs;
      })
    genv

let assertions genv =
  let open Gillian.Gil_syntax in
  let build_asrt s def =
    match def with
    | FunDef fname ->
        let s_ser = Expr.Lit (String s) in
        let f_ser = Expr.Lit (String fname) in
        let pname = CConstants.Internal_Predicates.glob_fun in
        Asrt.Pred (pname, [ s_ser; f_ser ])
    | GlobVar _    -> failwith "CANNOT MAKE ASSERTION OF GLOBAL VAR YET"
  in
  let assert_symb symb loc =
    let def = find_def genv loc in
    let asrt = build_asrt symb def in
    asrt
  in
  let list_of_loc_asrt_pairs =
    PMap.foldi
      (fun sym loc lis -> (loc, assert_symb sym loc) :: lis)
      genv.symb []
  in
  List.split list_of_loc_asrt_pairs
