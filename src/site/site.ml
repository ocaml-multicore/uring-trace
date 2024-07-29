let lookup_bpf_object_path filename =
  let dir = Bpf.Sites.bpf |> List.hd in
  let filename' = Filename.concat dir filename in
  if Sys.file_exists filename' then filename' else failwith "Couldn't find bpf object file"

let bpf_object_path = lookup_bpf_object_path "uring-trace.bpf.o"

  let bpf_program_names = [
        "handle_create";
        "handle_register";
        "handle_file_get";
        "handle_submit_req";
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
