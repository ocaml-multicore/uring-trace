open Eio

let ( / ) = Eio.Path.( / )

(* Maximum number of open file descriptors is 1024, since we fork only
   when we encounter a directory, to exceed the limit, there has to be
   more than 512 directories (Since each fiber can be blocked with 2
   fd's open, 1 to read and 1 to write). Typically, we have more files
   than directories, so this design should suffice. *)
let _copy_dfs ~src ~dst =
  let rec aux ~sw ~src ~dst =
    let stat = Path.stat ~follow:false src in
    match stat.kind with
    | `Directory ->
        (* Opens 1 FD *)
        Path.mkdir ~perm:stat.perm dst;
        let files = Path.read_dir src in
        Fiber.fork ~sw (fun () ->
            List.iter
              (fun basename ->
                aux ~sw ~src:(src / basename) ~dst:(dst / basename))
              files)
    | `Regular_file ->
        (* Opens 2 FDs *)
        Path.with_open_in src @@ fun source ->
        Path.with_open_out ~create:(`Exclusive stat.perm) dst @@ fun sink ->
        Flow.copy source sink
    | _ -> failwith "Not sure how to handle kind"
  in
  Switch.run ~name:"copy" (fun sw -> aux ~sw ~src ~dst)

let copy_dfs_max ?(max_fibers = 4) ~src ~dst () =
  let sem = Semaphore.make max_fibers in
  let rec aux ~src ~dst =
    let stat = Path.stat ~follow:false src in
    match stat.kind with
    | `Directory ->
      (* Opens 1 FD *)
      Semaphore.acquire sem;
      Path.mkdir ~perm:stat.perm dst;
      Semaphore.release sem;
      let files = Path.read_dir src in
      Fiber.List.iter
        (fun basename -> aux ~src:(src / basename) ~dst:(dst / basename))
        files
    | `Regular_file ->
      (* Opens 2 FDs *)
      Semaphore.acquire sem;
      Path.with_open_in src @@ fun source ->
      Path.with_open_out ~create:(`Exclusive stat.perm) dst @@ fun sink ->
      Flow.copy source sink;
      Semaphore.release sem
    | _ -> failwith "Not sure how to handle kind"
  in
  aux ~src ~dst


let () =
  (* powers of 2 *)
  let queue_depth = try int_of_string Sys.argv.(3) with _ -> 1 in
  (* 2 * queue_depth *)
  let n_blocks = try int_of_string Sys.argv.(4) with _ -> 2 * queue_depth in
  (* multiply by powers of 2 of 4096 *)
  let block_size = try int_of_string Sys.argv.(5) with _ -> 4096 in
  Eio_linux.run ~queue_depth ~n_blocks ~block_size (fun env ->
      let cwd = Eio.Stdenv.cwd env in
      let src = cwd / Sys.argv.(1) in
      let dst = cwd / Sys.argv.(2) in
      copy_dfs_max ~max_fibers:100 ~src ~dst ())
