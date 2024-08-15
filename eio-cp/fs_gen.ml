(* Taken from https://github.com/ocaml-multicore/eio/blob/main/bench/bench_stat.ml *)
open Eio.Std
open Cmdliner
module Path = Eio.Path

let () = Random.init 3
let ( / ) = Eio.Path.( / )

module Bench_dir = struct
  let size_dir = Int64.of_int 4096

  type t =
    | Dir of { name : string; size : int64; perm : int; children : t list }
    | File of { name : string; size : int64; perm : int }

  let get_name = function Dir { name; _ } | File { name; _ } -> name

  let _get_children = function
    | Dir { children; _ } -> children
    | File _ -> invalid_arg "Files don't have children"

  let compare a b = String.compare (get_name a) (get_name b)

  let rec sort = function
    | Dir ({ children; _ } as v) ->
        let c = List.map sort children in
        let c = List.stable_sort compare c in
        Dir { v with children = c }
    | File _ as f -> f

  let rec size_count = function
    | Dir { children; size = sz_dir; _ } ->
        let first, second =
          List.fold_left
            (fun (size, count) v ->
              let s, c = size_count v in
              (Int64.add size s, count + c))
            (Int64.zero, 0) children
        in
        (Int64.add sz_dir first, second)
    | File { size = sz_file; _ } -> (sz_file, 1)

  let rec pp ppf = function
    | Dir { name; perm; children; _ } ->
        if children = [] then Fmt.pf ppf "dir %s (0o%o)" name perm
        else
          Fmt.pf ppf "@[<v2>dir %s (0o%o)@ %a@]" name perm
            Fmt.(list ~sep:Fmt.cut pp)
            children
    | File { name; size; perm } ->
        Fmt.pf ppf "file %s (0o%o) %Lu" name perm size
  [@@warning "-32"]

  let make fs t =
    let rec aux iter fs = function
      | Dir { name; perm; children; _ } ->
          let dir = fs / name in
          Path.mkdir ~perm dir;
          iter (aux List.iter dir) children
      | File { name; size; perm } ->
          let buf = Cstruct.create (Int64.to_int size) in
          Path.with_open_out ~create:(`If_missing perm) (fs / name) (fun oc ->
              Eio.Flow.write oc [ buf ])
    in
    aux Fiber.List.iter fs t
end

let file name size = Bench_dir.File { name; perm = 0o644; size }

let dir name children =
  Bench_dir.Dir { name; size = Bench_dir.size_dir; perm = 0o700; children }

type quantity = Fixed of int64 | Range of int64 * int64

let pp_quantity ppf = function
  | Fixed sz -> Format.fprintf ppf "Fixed (%Ld)" sz
  | Range (min, max) -> Format.fprintf ppf "Range (%Ld, %Ld)" min max

let quantity_conv =
  let parser s =
    match String.split_on_char ',' s with
    | [ sz ] -> Ok (Fixed (Int64.of_string sz))
    | [ min; max ] -> Ok (Range (Int64.of_string min, Int64.of_string max))
    | _ -> Error (`Msg s)
  in
  Arg.conv (parser, pp_quantity)

let random_bench_dir ~nr_files ~depth ~dirname ~filesize =
  if depth < 1 then invalid_arg "Levels should be >= 1";
  let get_size = function
    | Fixed sz -> sz
    | Range (min, max) -> Random.int64_in_range ~min ~max
  in
  let rec loop root = function
    | 1 -> (
        match root with
        | Bench_dir.Dir d ->
            let leaf_files =
              List.init
                (get_size nr_files |> Int64.to_int)
                (fun i ->
                  file (Fmt.str "test-file-%i-%i" 1 i) (get_size filesize))
            in
            Bench_dir.Dir { d with children = leaf_files }
        | _ -> failwith "Root is always expected to be a directory")
    | depth -> (
        match root with
        | Bench_dir.Dir d ->
            let files =
              List.init
                (get_size nr_files |> Int64.to_int)
                (fun i ->
                  file (Fmt.str "test-file-%i-%i" depth i) (get_size filesize))
            in
            let dirs =
              List.init
                (get_size nr_files |> Int64.to_int)
                (fun i -> dir (Fmt.str "test-dir-%i-%i" depth i) [])
            in

            let dirs = List.map (fun dir -> loop dir (depth - 1)) dirs in
            Bench_dir.Dir { d with children = dirs @ files }
        | _ -> failwith "Root is always expected to be directory")
  in
  loop (dir dirname []) depth

let gen ~fs ~clock ~dirname ~nr_files ~depth ~filesize =
  let dir =
    random_bench_dir ~depth ~nr_files ~dirname ~filesize |> Bench_dir.sort
  in
  let size, count = Bench_dir.size_count dir in
  let size_mb = Int64.(div size (of_int 1_000_000)) in
  traceln
    "Going to create %i files and directories (%Ld Mb apparent size), is this \
     okay (y/n)\n"
    count size_mb;
  match read_line () with
  | "n" -> ()
  | "y" ->
      let create_time =
        let t0 = Eio.Time.now clock in
        Bench_dir.make fs dir;
        let t1 = Eio.Time.now clock in
        t1 -. t0
      in
      traceln "Created in %.2f s" create_time
  | _ as s -> invalid_arg s

let dirname =
  let doc = "Name of root directory" in
  Arg.(value & opt string "testfs" (info [ "name" ] ~doc))

let nr_files =
  let doc =
    "Number of files per directory. Can be provided a fixed value or a range."
  in
  Arg.(value & opt quantity_conv (Fixed 5L) (info [ "n"; "nr_files" ] ~doc))

let depth =
  let doc = "Maximum Depth of the directory" in
  Arg.(value & opt int 5 (info [ "d"; "depth" ] ~doc))

let filesize =
  let doc =
    "Size of files to generate. Can be provided a fixed value or a range."
  in
  Arg.(value & opt quantity_conv (Fixed 4096L) (info [ "f"; "filesize" ] ~doc))

let cmd =
  let doc = "Generate a test filesystem" in
  let info = Cmd.info "fs_gen" ~doc in
  let run dirname nr_files depth filesize =
    Eio_main.run @@ fun env ->
    let fs = Eio.Stdenv.fs env in
    let clock = Eio.Stdenv.clock env in
    gen ~fs ~clock ~dirname ~nr_files ~depth ~filesize
  in
  Cmd.v info Term.(const run $ dirname $ nr_files $ depth $ filesize)

let () = exit (Cmd.eval cmd)
