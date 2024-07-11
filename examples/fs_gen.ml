(* Taken from https://github.com/ocaml-multicore/eio/blob/main/bench/bench_stat.ml *)
open Eio.Std
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

let file name = Bench_dir.File { name; perm = 0o644; size = 4000L }

let dir name children =
  Bench_dir.Dir { name; size = Bench_dir.size_dir; perm = 0o700; children }

let random_bench_dir ~n ~levels ~rootname =
  if levels < 1 then invalid_arg "Levels should be >= 1";
  let rec loop root = function
    | 1 -> (
        match root with
        | Bench_dir.Dir d ->
            let leaf_files =
              List.init n (fun i -> file (Fmt.str "test-file-%i-%i" 1 i))
            in
            Bench_dir.Dir { d with children = leaf_files }
        | _ -> failwith "Root is always expected to be a directory")
    | level -> (
        match root with
        | Bench_dir.Dir d ->
            let files =
              List.init n (fun i -> file (Fmt.str "test-file-%i-%i" level i))
            in
            let dirs =
              List.init n (fun i -> dir (Fmt.str "test-dir-%i-%i" level i) [])
            in
            let dirs = List.map (fun dir -> loop dir (level - 1)) dirs in
            Bench_dir.Dir { d with children = dirs @ files }
        | _ -> failwith "Root is always expected to be directory")
  in
  loop (dir rootname []) levels

let gen ~n ~levels ~root ~rootname ~clock =
  let dir = random_bench_dir ~levels ~n ~rootname |> Bench_dir.sort in
  let size, count = Bench_dir.size_count dir in
  let size_mb = Int64.(div size (of_int 1_000_000)) in
  traceln
    "Going to create %i files and directories (%Ld Mb apparent size), are you sure? (y/n) "
    count size_mb;
  match read_line () with
  | "n" -> exit 0
  | "y" ->
      let create_time =
        let t0 = Eio.Time.now clock in
        Bench_dir.make root dir;
        let t1 = Eio.Time.now clock in
        t1 -. t0
      in
      traceln "Created in %.2f s" create_time
  | _ -> failwith "Input not recognized"

let () =
  Eio_linux.run @@ fun env ->
  let fs = Eio.Stdenv.fs env in
  let clock = Eio.Stdenv.clock env in
  let n = try Sys.argv.(1) |> int_of_string with _ -> 20 in
  let levels = try Sys.argv.(2) |> int_of_string with _ -> 4 in
  let root = try fs / Sys.argv.(3) with _ -> fs in
  let rootname = try Sys.argv.(4) with _ -> "root" in
  gen ~n ~levels ~root ~rootname ~clock
