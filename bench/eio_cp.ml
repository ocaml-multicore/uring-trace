open Eio

let ( / ) = Path.( / )

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
  let block_size = try int_of_string Sys.argv.(3) with _ -> 4096 in
  Eio_linux.run ~block_size @@ fun env ->
  let cwd = Eio.Stdenv.cwd env in
  let src = cwd / Sys.argv.(1) in
  let dst = cwd / Sys.argv.(2) in
  copy_kentookura ~src ~dst ()
