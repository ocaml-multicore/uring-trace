open Eio

let ( / ) = Eio.Path.( / )

let copy_dfs concurrent src dst =
  let rec aux ~src ~dst =
    let stat = Path.stat ~follow:false src in
    match stat.kind with
    | `Directory ->
      Path.mkdir ~perm:stat.perm dst;
      let files = Path.read_dir src in
      let iter = if concurrent then Fiber.List.iter ~max_fibers:2 else List.iter in
      iter (fun basename -> aux ~src:(src / basename) ~dst:(dst / basename)) files
    | `Regular_file ->
      Path.with_open_in src @@ fun source ->
      Path.with_open_out ~create:(`Exclusive stat.perm) dst @@ fun sink ->
      Flow.copy source sink;
    | _ -> failwith "Not sure how to handle kind"
  in
  aux ~src ~dst

let () =
  let block_size = try Some (int_of_string Sys.argv.(3)) with _ -> None in
  let concurrent = try bool_of_string Sys.argv.(4) with _ -> true in
  Eio_linux.run ?block_size (fun env ->
      let cwd = Eio.Stdenv.cwd env in
      let src = cwd / Sys.argv.(1) in
      let dst = cwd / Sys.argv.(2) in
      copy_dfs concurrent src dst)
