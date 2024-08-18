[@@@warning "-32-26"]

open Eio

let ( / ) = Eio.Path.( / )

let copy_dfs concurrent src dst =
  let rec aux ~src ~dst =
    let stat = Path.stat ~follow:false src in
    match stat.kind with
    | `Directory ->
        Path.mkdir ~perm:stat.perm dst;
        let files = Path.read_dir src in
        let iter =
          if concurrent then Fiber.List.iter ~max_fibers:2 else List.iter
        in
        iter
          (fun basename -> aux ~src:(src / basename) ~dst:(dst / basename))
          files
    | `Regular_file ->
        Path.with_open_in src @@ fun source ->
        Path.with_open_out ~create:(`Exclusive stat.perm) dst @@ fun sink ->
        Flow.copy source sink
    | _ -> failwith "Not sure how to handle kind"
  in
  aux ~src ~dst

module Q = Eio_utils.Lf_queue

let copy_bfs src dst =
  let sem = Semaphore.make 64 in
  let q = Q.create () in
  Q.push q (src, dst);

  Switch.run @@ fun sw ->
  while not (Q.is_empty q) do
    match Q.pop q with
    | None -> failwith "None in queue"
    | Some (src_path, dst_path) -> (
        let stat = Path.stat ~follow:false src_path in
        match stat.kind with
        | `Directory ->
            Path.mkdir ~perm:stat.perm dst_path;
            let files = Path.read_dir src_path in
            (* Append files in found directory *)
            List.iter (fun f -> Q.push q (src_path / f, dst_path / f)) files
        | `Regular_file ->
          Semaphore.acquire sem;
            Fiber.fork ~sw (fun () ->
                Path.with_open_in src_path @@ fun source ->
                Path.with_open_out ~create:(`Exclusive stat.perm) dst_path
                @@ fun sink ->
                Flow.copy source sink;
            );
          Semaphore.release sem
        | _ -> failwith "Not sure how to handle kind")
  done

let () =
  let block_size = try Some (int_of_string Sys.argv.(3)) with _ -> None in
  let concurrent = try bool_of_string Sys.argv.(4) with _ -> true in
  Eio_linux.run ?block_size (fun env ->
      let cwd = Eio.Stdenv.fs env in
      let src = cwd / Sys.argv.(1) in
      let dst = cwd / Sys.argv.(2) in
      copy_bfs src dst)
