open Libbpf

let () =
  let obj_path = "uring.bpf.o" in
  let program_names =   [
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
 in
  with_bpf_object_open_load_link ~obj_path ~program_names (fun _ _ ->
      Printf.printf "Load success\n%!")
