open Ctypes
module C = Stubs.Bindings (Uring_generated)
include Stub_types

let char_array_as_string a =
  let len = CArray.length a in
  let b = Buffer.create len in
  try
    for i = 0 to len - 1 do
      let c = CArray.get a i in
      if c = '\x00' then raise Exit else Buffer.add_char b c
    done;
    Buffer.contents b
  with Exit -> Buffer.contents b

let flags_of_i64 i64 flag_assoc_l =
  let open Int64 in
  List.fold_left
    (fun acc (i, f) -> if logand i64 i <> zero then f :: acc else acc)
    [] flag_assoc_l

let i64_of_flags flags flag_assoc_l =
  let open Int64 in
  List.fold_left (fun acc f -> logor acc (List.assoc f flag_assoc_l)) zero flags

let string_of_flag_list l show =
  if l = [] then "None" else List.map show l |> String.concat " | "

let () =
  assert (C.(Defines.max_op_str_len = max_op_str_len));
  assert (C.(Defines.task_comm_len = task_comm_len))

module Setup_flags = struct
  let setup_flag_assoc =
    C.Create.Flags.
      [
        (IOPOLL, iopoll);
        (SQPOLL, sqpoll);
        (SQ_AF, sq_aff);
        (CLAMP, clamp);
        (ATTACH_WQ, attach_wq);
        (R_DISABLED, r_disabled);
        (SUBMIT_ALL, submit_all);
        (COOP_TASKRUN, coop_taskrun);
        (TASKRUN_FLAG, taskrun_flag);
        (SQE128, sqe128);
        (CQE32, cqe32);
        (SINGLE_ISSUER, single_issuer);
        (DEFER_TASKRUN, defer_taskrun);
      ]

  let read i64 =
    flags_of_i64 i64 (List.map (fun (i, f) -> (f, i)) setup_flag_assoc)

  let write flags = i64_of_flags flags setup_flag_assoc
  let show flags = string_of_flag_list flags show_setup_flags
end

module Sqe_flags = struct
  let sqe_flag_assoc =
    C.Submit_sqe.Flags.
      [
        (FIXED_FILE, fixed_file);
        (IO_DRAIN, io_drain);
        (IO_LINK, io_link);
        (IO_HARDLINK, io_hardlink);
        (ASYNC, async);
        (BUFFER_SELECT, buffer_select);
        (CQE_SKIP_SUCCESS, cqe_skip_success);
      ]

  let read i64 =
    flags_of_i64 i64 (List.map (fun (i, f) -> (f, i)) sqe_flag_assoc)

  let write flags = i64_of_flags flags sqe_flag_assoc
  let show flags = string_of_flag_list flags show_sqe_flags
end

module Cqe_flags = struct
  let cqe_flag_assoc =
    C.Complete.Flags.
      [
        (BUFFER, buffer);
        (MORE, more);
        (SOCK_NONEMPTY, sock_nonempty);
        (NOTIF, notif);
      ]

  let read i64 =
    flags_of_i64 i64 (List.map (fun (i, f) -> (f, i)) cqe_flag_assoc)

  let write flags = i64_of_flags flags cqe_flag_assoc
  let show flags = string_of_flag_list flags show_cqe_flags
end

type io_uring_create = {
  fd : int;
  ctx_ptr : unit ptr;
  sq_entries : int32;
  cq_entries : int32;
  flags : setup_flags list;
}

let unload_create s =
  let open C.Create in
  let fd = getf s fd in
  let ctx_ptr = getf s ctx in
  let cq_entries = getf s cq_entries |> Unsigned.UInt32.to_int32 in
  let sq_entries = getf s sq_entries |> Unsigned.UInt32.to_int32 in
  let flags = getf s flags |> Unsigned.UInt32.to_int64 |> Setup_flags.read in
  { fd; ctx_ptr; sq_entries; cq_entries; flags }

type register = {
  ctx_ptr : unit ptr;
  opcode : int32;
  nr_files : int32;
  nr_bufs : int32;
  ret : int64;
}

let unload_register s =
  let open C.Register in
  let ctx_ptr = getf s ctx in
  let opcode = getf s opcode |> Unsigned.UInt32.to_int32 in
  let nr_files = getf s nr_files |> Unsigned.UInt32.to_int32 in
  let nr_bufs = getf s nr_bufs |> Unsigned.UInt32.to_int32 in
  let ret = getf s ret in
  { ctx_ptr; opcode; nr_files; nr_bufs; ret }

type io_uring_file_get = { ctx_ptr : unit ptr; req_ptr : unit ptr; fd : int }

let unload_file_get s =
  let open C.File_get in
  let ctx_ptr = getf s ctx in
  let req_ptr = getf s req in
  let fd = getf s fd in
  { ctx_ptr; req_ptr; fd }

type io_uring_submit_sqe = {
  ctx_ptr : unit ptr;
  req_ptr : unit ptr;
  opcode : int;
  flags : sqe_flags list;
  force_nonblock : bool;
  sq_thread : bool;
  op_str : string;
}

let unload_submit_sqe s =
  let open C.Submit_sqe in
  let ctx_ptr = getf s ctx in
  let req_ptr = getf s req in
  let opcode = getf s opcode |> Unsigned.UChar.to_int in
  let flags = getf s flags |> Unsigned.ULong.to_int64 |> Sqe_flags.read in
  let force_nonblock = getf s force_nonblock in
  let sq_thread = getf s sq_thread in
  let op_str = getf s op_str |> char_array_as_string in
  { req_ptr; ctx_ptr; opcode; flags; force_nonblock; sq_thread; op_str }

type io_uring_queue_async_work = {
  ctx_ptr : unit ptr;
  req_ptr : unit ptr;
  opcode : int;
  flags : int32;
  work_ptr : unit ptr;
  op_str : string;
}

let unload_queue_async_work s =
  let open C.Queue_async_work in
  let ctx_ptr = getf s ctx in
  let req_ptr = getf s req in
  let opcode = getf s opcode |> Unsigned.UChar.to_int in
  let flags = getf s flags |> Unsigned.UInt32.to_int32 in
  let work_ptr = getf s work |> to_voidp in
  let op_str = getf s op_str |> char_array_as_string in
  { ctx_ptr; req_ptr; opcode; flags; work_ptr; op_str }

type poll_arm = {
  ctx_ptr : unit ptr;
  req_ptr : unit ptr;
  opcode : int;
  mask : int;
  events : int;
  op_str : string;
}

let unload_poll_arm s =
  let open C.Poll_arm in
  let ctx_ptr = getf s ctx in
  let req_ptr = getf s req in
  let opcode = getf s opcode |> Unsigned.UChar.to_int in
  let mask = getf s mask in
  let events = getf s events in
  let op_str = getf s op_str |> char_array_as_string in
  { ctx_ptr; req_ptr; opcode; mask; events; op_str }

type task_add = {
  ctx_ptr : unit ptr;
  req_ptr : unit ptr;
  opcode : int;
  mask : int;
  op_str : string;
}

let unload_task_add s =
  let open C.Task_add in
  let ctx_ptr = getf s ctx in
  let req_ptr = getf s req in
  let opcode = getf s opcode |> Unsigned.UChar.to_int in
  let mask = getf s mask in
  let op_str = getf s op_str |> char_array_as_string in
  { ctx_ptr; req_ptr; opcode; mask; op_str }

type task_work_run = { tctx_ptr : unit ptr; count : int; loops : int }

let unload_task_work_run s =
  let open C.Task_work_run in
  let tctx_ptr = getf s tctx in
  let count = getf s count |> Unsigned.UInt32.to_int in
  let loops = getf s loops |> Unsigned.UInt32.to_int in
  { tctx_ptr; count; loops }

type short_write = {
  ctx_ptr : unit ptr;
  fpos : int64;
  wanted : int64;
  got : int64;
}

let unload_short_write s =
  let open C.Short_write in
  let ctx_ptr = getf s ctx in
  let fpos = getf s fpos |> Unsigned.UInt64.to_int64 in
  let wanted = getf s wanted |> Unsigned.UInt64.to_int64 in
  let got = getf s got |> Unsigned.UInt64.to_int64 in
  { ctx_ptr; fpos; wanted; got }

type local_work_run = { ctx_ptr : unit ptr; count : int; loops : int }

let unload_local_work_run s =
  let open C.Local_work_run in
  let ctx_ptr = getf s ctx in
  let count = getf s count in
  let loops = getf s loops |> Unsigned.UInt32.to_int in
  { ctx_ptr; count; loops }

type defer = {
  ctx_ptr : unit ptr;
  req_ptr : unit ptr;
  opcode : int;
  op_str : string;
}

let unload_defer s =
  let open C.Defer in
  let ctx_ptr = getf s ctx in
  let req_ptr = getf s req in
  let opcode = getf s opcode |> Unsigned.UChar.to_int in
  let op_str = getf s op_str |> char_array_as_string in
  { ctx_ptr; req_ptr; opcode; op_str }

type link = {
  ctx_ptr : unit ptr;
  req_ptr : unit ptr;
  target_req_ptr : unit ptr;
}

let unload_link s =
  let open C.Link in
  let ctx_ptr = getf s ctx in
  let req_ptr = getf s req in
  let target_req_ptr = getf s target_req in
  { ctx_ptr; req_ptr; target_req_ptr }

type fail_link = {
  ctx_ptr : unit ptr;
  req_ptr : unit ptr;
  opcode : int;
  link_ptr : unit ptr;
  op_str : string;
}

let unload_fail_link s =
  let open C.Fail_link in
  let ctx_ptr = getf s ctx in
  let req_ptr = getf s req in
  let opcode = getf s opcode |> Unsigned.UChar.to_int in
  let link_ptr = getf s link in
  let op_str = getf s op_str |> char_array_as_string in
  { ctx_ptr; req_ptr; opcode; link_ptr; op_str }

type cqring_wait = { ctx_ptr : unit ptr; min_events : int }

let unload_cqring_wait s =
  let open C.Cqring_wait in
  let ctx_ptr = getf s ctx in
  let min_events = getf s min_events in
  { ctx_ptr; min_events }

type req_failed = {
  ctx_ptr : unit ptr;
  req_ptr : unit ptr;
  opcode : int;
  flags : int;
  ioprio : int;
  off : int64;
  addr : int64;
  len : int;
  op_flags : int;
  buf_index : int;
  personality : int;
  file_index : int;
  pad1 : int64;
  addr3 : int64;
  error : int;
  op_str : string;
}

let unload_req_failed s =
  let open C.Req_failed in
  let ctx_ptr = getf s ctx in
  let req_ptr = getf s req in
  let opcode = getf s opcode |> Unsigned.UChar.to_int in
  let flags = getf s flags |> Unsigned.UChar.to_int in
  let ioprio = getf s ioprio |> Unsigned.UChar.to_int in
  let off = getf s off |> Unsigned.ULLong.to_int64 in
  let addr = getf s addr |> Unsigned.ULLong.to_int64 in
  let len = getf s len |> Unsigned.ULong.to_int in
  let op_flags = getf s op_flags |> Unsigned.ULong.to_int in
  let buf_index = getf s buf_index |> Unsigned.UInt.to_int in
  let personality = getf s personality |> Unsigned.UInt.to_int in
  let file_index = getf s file_index |> Unsigned.ULong.to_int in
  let pad1 = getf s pad1 |> Unsigned.ULLong.to_int64 in
  let addr3 = getf s addr3 |> Unsigned.ULLong.to_int64 in
  let error = getf s error in
  let op_str = getf s op_str |> char_array_as_string in
  {
    ctx_ptr;
    req_ptr;
    opcode;
    flags;
    ioprio;
    off;
    addr;
    len;
    op_flags;
    buf_index;
    personality;
    file_index;
    pad1;
    addr3;
    error;
    op_str;
  }

type cqe_overflow = {
  ctx_ptr : unit ptr;
  user_data : int64;
  res : int;
  cflags : int;
  ocqe_ptr : unit ptr;
}

let unload_cqe_overflow s =
  let open C.Cqe_overflow in
  let ctx_ptr = getf s ctx in
  let user_data = getf s user_data |> Unsigned.ULLong.to_int64 in
  let res = getf s res in
  let cflags = getf s cflags |> Unsigned.ULong.to_int in
  let ocqe_ptr = getf s ocqe in
  { ctx_ptr; user_data; res; cflags; ocqe_ptr }

type complete = {
  req_ptr : unit ptr;
  ctx_ptr : unit ptr;
  res : int;
  cflags : cqe_flags list;
}

let unload_complete s =
  let open C.Complete in
  let ctx_ptr = getf s ctx in
  let req_ptr = getf s req in
  let res = getf s res in
  let cflags = getf s cflags |> Unsigned.UInt.to_int64 |> Cqe_flags.read in
  { ctx_ptr; req_ptr; res; cflags }

type event = {
  ty : tracepoint_t;
  pid : int;
  tid : int;
  ts : Unsigned.uint64;
  comm : string;
}

let unload_event s =
  let open C.Event in
  let ty = getf s ty in
  let pid = getf s pid in
  let tid = getf s tid in
  let ts = getf s ts in
  let comm = getf s comm |> char_array_as_string in
  { ty; pid; tid; ts; comm }
