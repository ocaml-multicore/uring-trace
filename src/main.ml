open Driver

let show_ptr = Ctypes_value_printing.string_of (Ctypes.ptr Ctypes.void)
let cb = ref 0

(* queue_async, type of workqueue, hashed or normal *)
(* Add a view that shows when the complete task is read? *)
(* How to get ring specific tracks? Segregate by Process and then each thread is a the thread ID? *)

(* Describe event handler *)
let handle_event (writer : W.t) _ctx data _size =
  let open Ctypes in
  incr cb;
  let event = !@(from_voidp B.C.Event.t data) in
  let ev = B.unload_event event in
  let comm = ev.comm in
  let pid = Int64.of_int ev.pid in
  let tid = Int64.of_int ev.tid in
  let ts = Unsigned.UInt64.to_int64 ev.ts in
  (match ev.ty with
  | ( B.SYS_ENTER_IO_URING_ENTER | B.SYS_ENTER_IO_URING_REGISTER
    | B.SYS_ENTER_IO_URING_SETUP ) as ev ->
      W.syscall_begin writer ~name:(B.show_tracepoint_t ev) ~pid ~tid ~ts
  | ( B.SYS_EXIT_IO_URING_ENTER | B.SYS_EXIT_IO_URING_REGISTER
    | B.SYS_EXIT_IO_URING_SETUP ) as ev ->
      W.syscall_end writer ~name:(B.show_tracepoint_t ev) ~pid ~tid ~ts
  | B.KPROBE_IO_INIT_NEW_WORKER as ev ->
      let t = getf event B.C.Event.io_init_new_worker in
      let worker_tid = getf t B.C.Io_init_new_worker.io_worker_tid in
      W.create_worker_ev writer ~name:(B.show_tracepoint_t ev) ~pid ~tid
        ~worker_tid ~comm ~ts
  (* Tracepoints *)
  | B.IO_URING_CREATE ->
      let t = getf event B.C.Event.io_uring_create |> B.unload_create in
      let flag_list_str = t.flags |> B.Setup_flags.show in
      W.create_ring_ev writer ~pid ~ring_ctx:t.ctx_ptr ~tid
        ~name:"io_uring_create" ~comm ~ts
        ~args:
          [
            ("file descriptor", `Int64 (Int64.of_int t.fd));
            ("ring_ptr", `String (show_ptr t.ctx_ptr));
            ("sq_entries", `Int64 (Int64.of_int32 t.sq_entries));
            ("cq_entries", `Int64 (Int64.of_int32 t.cq_entries));
            ("flags", `String flag_list_str);
          ]
  | B.IO_URING_REGISTER ->
      let t = getf event B.C.Event.io_uring_register |> B.unload_register in
      W.instant_event writer ~name:"io_uring_register" ~pid ~tid ~ts
        ~args:
          [
            ("ring_ptr", `String (show_ptr t.ctx_ptr));
            ("opcode", `Int64 (Int64.of_int32 t.opcode));
            ("nr_files", `Int64 (Int64.of_int32 t.nr_files));
            ("nr_bufs", `Int64 (Int64.of_int32 t.nr_bufs));
            ("ret", `Int64 t.ret);
          ]
  | B.IO_URING_SUBMIT_SQE ->
      let t = getf event B.C.Event.io_uring_submit_sqe |> B.unload_submit_sqe in
      let correlation_id =
        t.req_ptr |> raw_address_of_ptr |> Int64.of_nativeint
      in
      let flag_list_str = t.flags |> B.Sqe_flags.show in
      W.submit_ev writer ~ring_ctx:t.ctx_ptr ~pid ~tid ~name:"io_uring_submit"
        ~ts ~correlation_id
        ~args:
          [
            ("ring_ptr", `String (show_ptr t.ctx_ptr));
            ("req_ptr", `String (show_ptr t.req_ptr));
            ("op_str", `String t.op_str);
            ("opcode", `Int64 (Int64.of_int t.opcode));
            ("flags", `String flag_list_str);
            ("force_nonblock", `String (Bool.to_string t.force_nonblock));
            ("sq_thread", `String (Bool.to_string t.sq_thread));
          ]
  | B.IO_URING_QUEUE_ASYNC_WORK ->
      let t =
        getf event B.C.Event.io_uring_queue_async_work
        |> B.unload_queue_async_work
      in
      let correlation_id =
        t.req_ptr |> raw_address_of_ptr |> Int64.of_nativeint
      in
      W.flow_ev writer ~ring_ctx:t.ctx_ptr ~pid ~tid
        ~name:"io_uring_queue_async_work" ~ts ~correlation_id
        ~args:
          [
            ("ring_ptr", `String (show_ptr t.ctx_ptr));
            ("req_ptr", `String (show_ptr t.req_ptr));
            ("opcode", `Int64 (Int64.of_int t.opcode));
            ("flags", `Int64 (Int64.of_int32 t.flags));
            ("work_ptr", `String (show_ptr t.work_ptr));
            ("op_str", `String t.op_str);
          ]
  | B.IO_URING_TASK_ADD ->
      let t = getf event B.C.Event.io_uring_task_add |> B.unload_task_add in
      let correlation_id =
        t.req_ptr |> raw_address_of_ptr |> Int64.of_nativeint
      in
      W.flow_ev writer ~pid ~ring_ctx:t.ctx_ptr ~tid ~name:"io_uring_task_add"
        ~ts ~correlation_id
        ~args:
          [
            ("ring_ctx", `String (show_ptr t.ctx_ptr));
            ("req_ptr", `String (show_ptr t.req_ptr));
            ("opcode", `Int64 (Int64.of_int t.opcode));
            ("mask", `Int64 (Int64.of_int t.mask));
            ("op_str", `String t.op_str);
          ]
  | B.IO_URING_POLL_ARM ->
      let t = getf event B.C.Event.io_uring_poll_arm |> B.unload_poll_arm in
      let correlation_id =
        t.req_ptr |> raw_address_of_ptr |> Int64.of_nativeint
      in
      W.flow_ev writer ~pid ~ring_ctx:t.ctx_ptr ~tid ~name:"io_uring_poll_arm"
        ~ts ~correlation_id
        ~args:
          [
            ("ring_ptr", `String (show_ptr t.ctx_ptr));
            ("req_ptr", `String (show_ptr t.req_ptr));
            ("opcode", `Int64 (Int64.of_int t.opcode));
            ("mask", `Int64 (Int64.of_int t.mask));
            ("events", `Int64 (Int64.of_int t.events));
            ("op_str", `String t.op_str);
          ]
  | B.IO_URING_FILE_GET ->
      let t = getf event B.C.Event.io_uring_file_get |> B.unload_file_get in
      let correlation_id =
        t.req_ptr |> raw_address_of_ptr |> Int64.of_nativeint
      in
      W.flow_ev writer ~pid ~ring_ctx:t.ctx_ptr ~tid ~name:"io_uring_file_get"
        ~ts ~correlation_id
        ~args:
          [
            ("ring_ptr", `String (show_ptr t.ctx_ptr));
            ("req_ptr", `String (show_ptr t.req_ptr));
            ("fd", `Int64 (Int64.of_int t.fd));
          ]
  | B.IO_URING_DEFER ->
      let t = getf event B.C.Event.io_uring_defer |> B.unload_defer in
      let correlation_id =
        t.req_ptr |> raw_address_of_ptr |> Int64.of_nativeint
      in
      W.flow_ev writer ~pid ~ring_ctx:t.ctx_ptr ~tid ~name:"io_uring_defer" ~ts
        ~correlation_id
        ~args:
          [
            ("ring_ptr", `String (show_ptr t.ctx_ptr));
            ("req_ptr", `String (show_ptr t.req_ptr));
            ("opcode", `Int64 (Int64.of_int t.opcode));
            ("op_str", `String t.op_str);
          ]
  | B.IO_URING_FAIL_LINK ->
      let t = getf event B.C.Event.io_uring_fail_link |> B.unload_fail_link in
      let correlation_id =
        t.req_ptr |> raw_address_of_ptr |> Int64.of_nativeint
      in
      W.flow_ev writer ~pid ~ring_ctx:t.ctx_ptr ~tid ~name:"io_uring_fail_link"
        ~ts ~correlation_id
        ~args:
          [
            ("ring_ptr", `String (show_ptr t.ctx_ptr));
            ("req_ptr", `String (show_ptr t.req_ptr));
            ("link_ptr", `String (show_ptr t.link_ptr));
            ("opcode", `Int64 (Int64.of_int t.opcode));
            ("op_str", `String t.op_str);
          ]
  | B.IO_URING_LINK ->
      let t = getf event B.C.Event.io_uring_link |> B.unload_link in
      let correlation_id =
        t.req_ptr |> raw_address_of_ptr |> Int64.of_nativeint
      in
      W.flow_ev writer ~pid ~ring_ctx:t.ctx_ptr ~tid ~name:"io_uring_link" ~ts
        ~correlation_id
        ~args:
          [
            ("ring_ptr", `String (show_ptr t.ctx_ptr));
            ("req_ptr", `String (show_ptr t.req_ptr));
            ("target_req", `String (show_ptr t.target_req_ptr));
          ]
  | B.IO_URING_REQ_FAILED ->
      let t = getf event B.C.Event.io_uring_req_failed |> B.unload_req_failed in
      let correlation_id =
        t.req_ptr |> raw_address_of_ptr |> Int64.of_nativeint
      in
      W.flow_ev writer ~pid ~ring_ctx:t.ctx_ptr ~tid ~name:"io_uring_req_failed"
        ~ts ~correlation_id
        ~args:
          [
            ("ring_ptr", `String (show_ptr t.ctx_ptr));
            ("req_ptr", `String (show_ptr t.req_ptr));
            ("opcode", `Int64 (Int64.of_int t.opcode));
            ("flags", `Int64 (Int64.of_int t.flags));
            ("ioprio", `Int64 (Int64.of_int t.ioprio));
            ("off", `Int64 t.off);
            ("addr", `Pointer t.addr);
            ("len", `Int64 (Int64.of_int t.len));
            ("op_flags", `Int64 (Int64.of_int t.op_flags));
            ("buf_index", `Int64 (Int64.of_int t.buf_index));
            ("personality", `Int64 (Int64.of_int t.personality));
            ("file_index", `Int64 (Int64.of_int t.file_index));
            ("pad1", `Int64 t.pad1);
            ("addr3", `Pointer t.addr3);
            ("error", `Int64 (Int64.of_int t.error));
            ("op_str", `String t.op_str);
          ]
  | B.IO_URING_COMPLETE ->
      let t = getf event B.C.Event.io_uring_complete |> B.unload_complete in
      let correlation_id =
        t.req_ptr |> raw_address_of_ptr |> Int64.of_nativeint
      in
      let flag_list_str = t.cflags |> B.Cqe_flags.show in
      W.complete_ev writer ~pid ~ring_ctx:t.ctx_ptr ~tid
        ~name:"io_uring_complete" ~ts ~correlation_id
        ~args:
          [
            ("ring_ptr", `String (show_ptr t.ctx_ptr));
            ("req_ptr", `String (show_ptr t.req_ptr));
            ("res", `Int64 (Int64.of_int t.res));
            ("cflags", `String flag_list_str);
          ]
  | B.IO_URING_SHORT_WRITE ->
      let t =
        getf event B.C.Event.io_uring_short_write |> B.unload_short_write
      in
      W.instant_event writer ~name:"io_uring_short_write" ~pid ~tid ~ts
        ~args:
          [
            ("ring_ptr", `String (show_ptr t.ctx_ptr));
            ("fpos", `Int64 t.fpos);
            ("wanted", `Int64 t.wanted);
            ("got", `Int64 t.got);
          ]
  | B.IO_URING_TASK_WORK_RUN ->
      let t =
        getf event B.C.Event.io_uring_task_work_run |> B.unload_task_work_run
      in
      W.instant_event writer ~name:"io_uring_task_work_run" ~pid ~tid ~ts
        ~args:
          [
            ("tctx", `String (show_ptr t.tctx_ptr));
            ("count", `Int64 (Int64.of_int t.count));
            ("loops", `Int64 (Int64.of_int t.loops));
          ]
  | B.IO_URING_LOCAL_WORK_RUN ->
      let t =
        getf event B.C.Event.io_uring_local_work_run |> B.unload_local_work_run
      in
      W.instant_event writer ~name:"io_uring_task_work_run" ~pid ~tid ~ts
        ~args:
          [
            ("ring_ptr", `String (show_ptr t.ctx_ptr));
            ("count", `Int64 (Int64.of_int t.count));
            ("loops", `Int64 (Int64.of_int t.loops));
          ]
  | B.IO_URING_CQE_OVERFLOW ->
      let t =
        getf event B.C.Event.io_uring_cqe_overflow |> B.unload_cqe_overflow
      in
      W.instant_event writer ~name:"io_uring_cqe_overflow" ~pid ~tid ~ts
        ~args:
          [
            ("ring_ptr", `String (show_ptr t.ctx_ptr));
            ("user_data", `Pointer t.user_data);
            ("res", `Int64 (Int64.of_int t.res));
            ("cflags", `Int64 (Int64.of_int t.cflags));
            ("ocqe_ptr", `String (show_ptr t.ocqe_ptr));
          ]
  | B.IO_URING_CQRING_WAIT ->
      let t =
        getf event B.C.Event.io_uring_cqring_wait |> B.unload_cqring_wait
      in
      W.instant_event writer ~name:"io_uring_cqring_wait" ~pid ~tid ~ts
        ~args:
          [
            ("ring_ptr", `String (show_ptr t.ctx_ptr));
            ("min_events", `Int64 (Int64.of_int t.min_events));
          ]);
  0

let () =
  run ~bpf_object_path:"uring.bpf.o"
    ~bpf_program_names:
      [
        "handle_create";
        "handle_register";
        "handle_file_get";
        "handle_submit_sqe";
        "handle_queue_async_work";
        "handle_poll_arm";
        "handle_task_add";
        "handle_task_work_run";
        "handle_short_write";
        "handle_local_work_run";
        "handle_defer";
        "handle_link";
        "handle_fail_link";
        "handle_cqring_wait";
        "handle_req_failed";
        "handle_cqe_overflow";
        "handle_complete";
        "handle_io_init_new_worker";
        "handle_sys_enter_io_uring_setup";
        "handle_sys_exit_io_uring_setup";
        "handle_sys_enter_io_uring_register";
        "handle_sys_exit_io_uring_register";
        "handle_sys_enter_io_uring_enter";
        "handle_sys_exit_io_uring_enter";
      ]
    handle_event;
  Printf.printf "User space consumed %d events" !cb
