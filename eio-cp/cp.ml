open Eio

let main fs infile =
  let infile' = Path.( / ) fs infile in
  let outfile' = Path.( / ) fs (infile ^ ".copy") in
  Path.with_open_in infile' @@ fun in_handle ->
  Path.with_open_out ~create:(`Exclusive 0o644) outfile' @@ fun out_handle ->
  Flow.copy in_handle out_handle

let () =
  let infile = Sys.argv.(1) in
  let block_size = Sys.argv.(2) |> int_of_string in
  Eio_linux.run ~block_size @@ fun env -> main env#fs infile
