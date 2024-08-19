open Eio
open Eio_linux

let read_then_write_chunk infd outfd file_offset len =
  let buf = Low_level.alloc_fixed_or_wait () in
  Low_level.read_exactly ~file_offset infd buf len;
  Low_level.write ~file_offset outfd buf len;
  Low_level.free_fixed buf

let copy_file_aux infd outfd insize block_size =
  Switch.run @@ fun sw ->
  let rec copy_block file_offset =
    let remaining = Optint.Int63.(sub insize file_offset) in
    if remaining <> Optint.Int63.zero then (
      let len =
        Optint.Int63.to_int (min (Optint.Int63.of_int block_size) remaining)
      in
      Fiber.fork ~sw (fun () ->
          read_then_write_chunk infd outfd file_offset len);
      copy_block Optint.Int63.(add file_offset (of_int len)))
  in
  copy_block Optint.Int63.zero

let copy_file infile outfile =
  Switch.run ~name:"copy_file" @@ fun sw ->
  let infd =
    Low_level.openat2 infile ~sw ~seekable:true ~access:`R
      ~flags:Uring.Open_flags.empty ~perm:0 ~resolve:Uring.Resolve.empty
  in
  let outfd =
    Low_level.openat2 outfile ~sw ~seekable:true ~access:`RW
      ~flags:Uring.Open_flags.(creat + trunc)
      ~resolve:Uring.Resolve.empty ~perm:0o644
  in
  let insize = (Low_level.fstat infd).size in
  copy_file_aux infd outfd insize 4096

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
