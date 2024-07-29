open Libbpf
module F = C.Functions
module T = C.Types
module B = Bindings
module W = Writer

type poll_behaviour = Poll of int | Busywait

exception Exit of int

let pid_idx = 0
let total_idx = 1
let lost_idx = 2
let skipped_idx = 3
let unrelated_idx = 4
let sampling_idx = 5
let user_idx = 6

let init sampling obj =
  if sampling then
    let map = bpf_object_find_map_by_name obj "globals" in
    bpf_map_update_elem map ~key_ty:Ctypes.int ~val_ty:Ctypes.long sampling_idx
      (Signed.Long.of_int 1)

let load_run ~sampling ~poll_behaviour ~bpf_object_path ~bpf_program_names
    ~(writer : W.t) callback =
  let before_link = init sampling in
  with_bpf_object_open_load_link ~before_link ~obj_path:bpf_object_path
    ~program_names:bpf_program_names (fun obj _links ->
      (* Set signal handlers *)
      let cont = ref true in
      let sig_handler = Sys.Signal_handle (fun _ -> cont := false) in
      Sys.(set_signal sigint sig_handler);
      Sys.(set_signal sigterm sig_handler);

      let callback_w_ctx = callback writer in
      let map = bpf_object_find_map_by_name obj "rb" in
      Libbpf_maps.RingBuffer.init map ~callback:callback_w_ctx (fun rb ->
          (match poll_behaviour with
          | Poll timeout ->
              while !cont do
                match Libbpf_maps.RingBuffer.poll rb ~timeout with
                (* Ctrl-C will cause -EINTR exception *)
                | e when e = Sys.sigint -> cont := false
                | _ -> ()
              done
          | Busywait -> (
              match Libbpf_maps.RingBuffer.consume rb with
              | e when e = Sys.sigint -> cont := false
              | _ -> ()));

          let globals = bpf_object_find_map_by_name obj "globals" in
          let lookup_globals idx =
            bpf_map_lookup_value ~key_ty:Ctypes.int ~val_ty:Ctypes.long
              ~val_zero:Signed.Long.zero globals idx
          in
          (* Print globals at the end *)
          let total = lookup_globals 1 in
          let lost = lookup_globals 2 in
          let skipped = lookup_globals 3 in
          let unrelated = lookup_globals 4 in
          let user = lookup_globals 6 in
          let str_of_long clong =
            Ctypes_value_printing.string_of Ctypes.long clong
          in
          Printf.printf
            "\n\
             Kernel-space recorded %s total events, %s lost events, %s skipped \
             events, %s unrelated events, sent to user %s\n"
            (str_of_long total) (str_of_long lost) (str_of_long skipped)
            (str_of_long unrelated) (str_of_long user)))

let run ~tracefile ~sampling ~poll_behaviour =
  Eio_linux.run @@ fun env ->
  Eio.Switch.run (fun sw ->
      let output_file = Eio.Path.( / ) (Eio.Stdenv.cwd env) tracefile in
      let out =
        Eio.Path.open_out ~sw ~create:(`Or_truncate 0o644) output_file
      in
      Eio.Buf_write.with_flow out (fun w ->
          let writer = W.make (W.FW.of_writer w) in
          try
            load_run ~sampling ~poll_behaviour ~bpf_object_path:Site.bpf_object_path
              ~bpf_program_names:Site.bpf_program_names ~writer Handler.handle_event
          with Exit i -> Printf.eprintf "exit %d\n" i))
