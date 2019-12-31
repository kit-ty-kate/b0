(*---------------------------------------------------------------------------
   Copyright (c) 2020 The b0 programmers. All rights reserved.
   Distributed under the ISC license, see terms at the end of the file.
  ---------------------------------------------------------------------------*)

open B0_std

let driver =
  let libs = [B0_ocaml_lib.Name.v "b0.b0/b0"] in
  B0_driver.create ~name:"b0" ~version:"%%VERSION%%" ~libs

module Def = struct
  let list (module Def : B0_def.S) c format ds =
    let pp = match format with
    | `Short -> Def.pp_name
    | `Normal -> Def.pp_synopsis
    | `Long -> Def.pp
    in
    Log.if_error ~use:B0_driver.Exit.no_such_name @@
    Result.bind (Def.get_all ds) @@ fun ds ->
    Log.if_error' ~use:B0_driver.Exit.some_error @@
    let don't = B0_driver.Conf.no_pager c in
    Result.bind (B0_pager.find ~don't ()) @@ fun pager ->
    Result.bind (B0_pager.page_stdout pager) @@ fun () ->
    if ds <> [] then Log.app (fun m -> m "@[<v>%a@]" Fmt.(list pp) ds);
    Ok B0_driver.Exit.ok

  let edit (module Def : B0_def.S) c ds =
    let rec find_files not_found fs = function
    | [] -> not_found, Fpath.uniquify fs
    | d :: ds ->
        match B0_def.file (Def.def d) with
        | None -> find_files (Def.Set.add d not_found) fs ds
        | Some f -> find_files not_found (f :: fs) ds
    in
    let edit_all = ds = [] in
    Log.if_error ~use:B0_driver.Exit.no_such_name @@
    Result.bind (Def.get_all ds) @@ fun ds ->
    let not_found, files = find_files Def.Set.empty [] ds in
    Log.if_error' ~use:B0_driver.Exit.some_error @@
    match not edit_all && not (Def.Set.is_empty not_found) with
    | true ->
        let plural = if (Def.Set.cardinal not_found > 1) then "s" else "" in
        let none = Def.Set.elements not_found in
        Fmt.error "Could not find B0 file for %s%s: @[%a@]"
          Def.def_kind plural Fmt.(list ~sep:sp Def.pp_name) none
    | false ->
        Result.bind (B0_editor.find ()) @@ fun editor ->
        Result.bind (B0_editor.edit_files editor files) @@ function
        | `Exited 0 -> Ok B0_driver.Exit.ok
        | _ -> Ok B0_driver.Exit.some_error

  let get (module Def : B0_def.S) c format key ds =
    Log.if_error ~use:B0_driver.Exit.no_such_name @@
    let key = match B0_meta.Key.get_or_suggest key with
    | Ok _ as v -> v
    | Error suggs ->
        let kind = Fmt.any "metadata key" and hint = Fmt.did_you_mean in
        let pp = Fmt.unknown' ~kind B0_meta.Key.pp_name_str ~hint in
        let name (B0_meta.Key.V k) = B0_meta.Key.name k in
        Fmt.error "@[%a@]" pp (key, List.map name suggs)
    in
    Result.bind key @@ fun (B0_meta.Key.V key) ->
    Result.bind (Def.get_all ds) @@ fun ds ->
    let add_meta acc d = match B0_meta.find_binding key (Def.meta d) with
    | None -> acc | Some v -> (d, v) :: acc
    in
    let bs = List.rev @@ List.fold_left add_meta [] ds in
    begin match ds with
    | [d] ->
        (* For single def requests we don't print the def name. *)
        begin match bs with
        | [] -> ()
        | [_, B0_meta.B (k, v)] ->
            Log.app (fun m -> m "@[<h>%a@]" (B0_meta.Key.pp_value k) v)
        | _ -> assert false
        end
    | _ ->
        let pp_bindings ppf (d, B0_meta.B (k, v)) =
          Fmt.pf ppf "@[<h>%a %a@]" Def.pp_name d (B0_meta.Key.pp_value k) v
        in
        Log.app (fun m -> m "@[<v>%a@]" Fmt.(list pp_bindings) bs)
    end;
    Ok B0_driver.Exit.ok
end

module Cli = struct
  open Cmdliner
  let man_see_manual = `Blocks
      [ `S Manpage.s_see_also;
        `P "Consult $(b,odig doc b0) for manuals and more details."]
end

(*---------------------------------------------------------------------------
   Copyright (c) 2020 The b0 programmers

   Permission to use, copy, modify, and/or distribute this software for any
   purpose with or without fee is hereby granted, provided that the above
   copyright notice and this permission notice appear in all copies.

   THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
   WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
   MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
   ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
   WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
   ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
   OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
  ---------------------------------------------------------------------------*)
