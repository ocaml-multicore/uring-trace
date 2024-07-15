let bufsz = 4096
let filepath = "bigfile"

let with_file_to_copy f =
  let in_fd = UnixLabels.openfile filepath ~mode:[ O_RDONLY ] ~perm:0 in
  let out_fd =
    UnixLabels.openfile (filepath ^ ".copy")
      ~mode:[ O_WRONLY; O_CREAT; O_TRUNC ]
      ~perm:0o644
  in
  let stat = UnixLabels.stat filepath in
  f in_fd out_fd stat;
  UnixLabels.close in_fd;
  UnixLabels.close out_fd

let reg_cp () =
  with_file_to_copy (fun in_fd out_fd stat ->
      let buf = Bytes.create bufsz in
      let left = ref stat.st_size in
      while !left > 0 do
        let len = UnixLabels.read in_fd ~buf ~pos:0 ~len:(min !left bufsz) in
        left := !left - len;
        UnixLabels.write out_fd ~buf ~pos:0 ~len |> ignore
      done)

let chan_cp () =
  In_channel.with_open_bin filepath (fun ic ->
      Out_channel.with_open_bin (filepath ^ ".copy") (fun oc ->
          let buf = Bytes.create bufsz in
          let stat = UnixLabels.stat filepath in
          let left = ref stat.st_size in
          while !left > 0 do
            let len = In_channel.input ic buf 0 (min !left bufsz) in
            left := !left - len;
            Out_channel.output oc buf 0 len |> ignore
          done))

let link ring (current_op : 'a Uring.job option) next_op =
  match current_op with
  | None -> failwith "Submission queue full"
  | Some _ -> (
      assert (Uring.submit ring > 0);
      match Uring.wait ring with
      | None -> failwith "No linked operation returned"
      | Some { result; data } -> next_op result data)

let uring_rw_cp ring in_fd pos out_fd buf filesize =
  let ( >>= ) = link ring in
  let filesize =  Optint.Int63.of_int filesize in
  let rec aux file_offset =
    Printf.printf "file_offset %d filesize %d\n%!"
      (Optint.Int63.to_int file_offset)
      (Optint.Int63.to_int filesize);
    if Optint.Int63.compare file_offset filesize >= 0 then ()
    else
      Uring.read ring ~file_offset in_fd buf () >>= fun res _data ->
      let buf = Cstruct.sub buf 0 res in
      Uring.write ring ~file_offset out_fd buf () >>= fun res _data ->
      aux (Optint.Int63.add file_offset (Optint.Int63.of_int res))
  in
  aux (Optint.Int63.of_int pos)

let uring_cp () =
  let ring = Uring.create ~queue_depth:1 () in
  with_file_to_copy (fun in_fd out_fd stat ->
      let buf = Cstruct.create bufsz in
      uring_rw_cp ring in_fd 0 out_fd buf stat.st_size)

let uring_rwv_cp ring in_fd pos out_fd iovec =
  let depth = List.length iovec in
  List.iteri
    (fun i buf ->
      let pos = (i * bufsz) + pos |> Optint.Int63.of_int in
      assert (Uring.read ring ~file_offset:pos in_fd buf () |> Option.is_some))
    iovec;
  assert (Uring.submit ring = depth);
  for _i = 1 to depth do
    match Uring.wait ring with
    | None -> failwith "Missed completion call"
    | Some _ -> ()
  done;
  link ring
    (Uring.writev ring ~file_offset:(Optint.Int63.of_int pos) out_fd iovec ())
    (fun _ _ -> pos + (depth * bufsz))

let uring_writev_cp () =
  let queue_depth = 64 in
  let ring = Uring.create ~queue_depth () in
  let iovec = List.init queue_depth (fun _ -> Cstruct.create bufsz) in
  let rec copy in_fd offset out_fd filesize =
    if offset >= filesize then ()
    else if filesize - offset >= Cstruct.lenv iovec then
      let next_offset = uring_rwv_cp ring in_fd offset out_fd iovec in
      copy in_fd next_offset out_fd filesize
    else uring_rw_cp ring in_fd offset out_fd (List.hd iovec) filesize
  in
  with_file_to_copy (fun in_fd out_fd stat -> copy in_fd 0 out_fd stat.st_size)

let () =
  match Sys.argv.(1) with
  | "reg" -> reg_cp ()
  | "chan" -> chan_cp ()
  | "uring" -> uring_cp ()
  | "uring_writev" -> uring_writev_cp ()
  | (exception _) | _ -> failwith "Usage error"
