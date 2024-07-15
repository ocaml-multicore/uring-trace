[@@@warning "-32"]

open Eio

let ( / ) = Eio.Path.( / )

(* Copies the src file or directory name to the dst directory in the
   filesystem and returns the list of pending copies to be done if
   it's a directory *)
let _copy ~sw ~src ~dst =
  let stat = Path.stat ~follow:false src in
  match stat.kind with
  | `Directory ->
      (* Opens 1 FD *)
      Path.mkdir ~perm:stat.perm dst;
      let files = Path.read_dir src in
      List.map (fun basename -> (src / basename, dst / basename)) files
  | `Regular_file ->
      (* Opens 2 FDs *)
      Path.with_open_in src @@ fun source ->
      Path.with_open_out ~create:(`Exclusive stat.perm) dst @@ fun sink ->
      Flow.copy source sink;
      []
  | _ ->
      Switch.fail sw (Failure "Not sure how to handle kind");
      []

let rec copy_dfs_1 ?(depth = 3) ~src ~dst () =
  let stat = Path.stat ~follow:false src in
  match stat.kind with
  | `Directory ->
      (* Opens 1 FD *)
      Path.mkdir ~perm:stat.perm dst;
      let files = Path.read_dir src in
      let rec_call basename =
        copy_dfs_1 ~depth:(depth - 1) ~src:(src / basename)
          ~dst:(dst / basename) ()
      in
      if depth > 0 then Fiber.List.iter rec_call files
      else List.iter rec_call files
  | `Regular_file ->
      (* Opens 2 FDs *)
      Path.with_open_in src @@ fun source ->
      Path.with_open_out ~create:(`Exclusive stat.perm) dst @@ fun sink ->
      Flow.copy source sink
  | _ -> failwith "Not sure how to handle kind"

let copy_dfs_2 ?(max_fibers = 4) ~src ~dst () =
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

(* Maximum number of open file descriptors is 1024, since we fork only
   when we encounter a directory, to exceed the limit, there has to be
   more than 512 directories (Since each fiber can be blocked with 2
   fd's open, 1 to read and 1 to write). Typically, we have more files
   than directories, so this design should suffice. *)
let copy_dfs_3 ~src ~dst () =
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

(* let copy  ~src ~dst () = *)
(*   let module Q = Eio_utils.Lf_queue in *)
(*   let worklist = Q.create () in *)
(*   Q.push worklist (src, dst); *)
(*   Switch.run ~name:"worklist" (fun sw -> *)
(*       while not (Q.is_empty worklist) do *)
(*         let s, d = Q.pop worklist |> Option.get in *)
(*         (\* Are we allowed to spawn more fibers? *\) *)
(*         Fiber.fork ~sw (fun () -> fun p -> Q.push p worklist); *)
(*       done) *)

let copy_kentookura ?(debug = false) ~src ~dst () =
  let debug_info =
    if debug then fun p -> Eio.Std.traceln "%a" Eio.Path.pp p else Fun.const ()
  in
  let debug_error =
    if debug then fun p ex ->
      Eio.Std.traceln "%a: %a" Eio.Path.pp p Eio.Exn.pp ex
    else fun _ _ -> ()
  in
  let rec aux ~src ~dst =
    match Path.kind ~follow:false src with
    | `Directory ->
        (match Path.mkdir dst ~perm:0o700 with
        | () -> debug_info dst
        | exception ex -> debug_error dst ex);
        Path.read_dir src
        |> Fiber.List.iter ~max_fibers:2 (function
             | item when String.starts_with ~prefix:"." item -> ()
             | item -> aux ~src:(src / item) ~dst:(dst / item))
    | `Regular_file ->
        (* Switch.run @@ fun sw -> *)
        ( Path.with_open_in src @@ fun src ->
          Path.with_open_out ~create:(`Or_truncate 0o700) dst @@ fun dst ->
          Flow.copy src dst );
        ()
    | _ -> ()
  in
  (match Path.mkdir dst ~perm:0o700 with
  | () -> debug_info dst
  | exception (ex : exn) -> debug_error dst ex);
  aux ~src ~dst

let () =
  Eio_linux.run ~block_size:1_000_000 @@ fun env ->
  let cwd = Eio.Stdenv.cwd env in
  let src = cwd / Sys.argv.(1) in
  let dst = cwd / Sys.argv.(2) in
  let algo = try Sys.argv.(3) with _ -> "kw" in
  match algo with
  | "kw" -> copy_dfs_2 ~max_fibers:4 ~src ~dst ()
  | "kentookura" -> copy_kentookura ~src ~dst ()
  | _ -> failwith "algo is one of <kw/kentookura>"
