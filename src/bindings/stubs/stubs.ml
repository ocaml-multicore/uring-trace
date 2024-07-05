open Stub_types

(* Add some views for flags to display nicely? *)
module Bindings (T : Cstubs_structs.TYPE) = struct
  open Ctypes
  open T

  (* Since we can't get the definitions prior to using them in
     structs, we will have to manually write them and assert they are
     the same after they are generated *)

  module Defines = struct
    let task_comm_len = 16
    let max_op_str_len = 127
  end

  let task_comm_len = constant "TASK_COMM_LEN" int
  let max_op_str_len = constant "MAX_OP_STR_LEN" int

  let enum_gen ?typedef ?(prefix = "") label vals =
    enum ?typedef label
      (List.map (fun (a, b) -> (a, constant (prefix ^ b) int64_t)) vals)

  let enum_tracepoint_t =
    enum_gen "tracepoint_t"
      [
        (IO_URING_CREATE, "IO_URING_CREATE");
        (IO_URING_REGISTER, "IO_URING_REGISTER");
        (IO_URING_FILE_GET, "IO_URING_FILE_GET");
        (IO_URING_SUBMIT_SQE, "IO_URING_SUBMIT_SQE");
        (IO_URING_QUEUE_ASYNC_WORK, "IO_URING_QUEUE_ASYNC_WORK");
        (IO_URING_POLL_ARM, "IO_URING_POLL_ARM");
        (IO_URING_TASK_ADD, "IO_URING_TASK_ADD");
        (IO_URING_TASK_WORK_RUN, "IO_URING_TASK_WORK_RUN");
        (IO_URING_SHORT_WRITE, "IO_URING_SHORT_WRITE");
        (IO_URING_LOCAL_WORK_RUN, "IO_URING_LOCAL_WORK_RUN");
        (IO_URING_DEFER, "IO_URING_DEFER");
        (IO_URING_LINK, "IO_URING_LINK");
        (IO_URING_FAIL_LINK, "IO_URING_FAIL_LINK");
        (IO_URING_CQRING_WAIT, "IO_URING_CQRING_WAIT");
        (IO_URING_REQ_FAILED, "IO_URING_REQ_FAILED");
        (IO_URING_CQE_OVERFLOW, "IO_URING_CQE_OVERFLOW");
        (IO_URING_COMPLETE, "IO_URING_COMPLETE");
        (KPROBE_IO_INIT_NEW_WORKER, "KPROBE_IO_INIT_NEW_WORKER");
        (SYS_ENTER_IO_URING_SETUP, "SYS_ENTER_IO_URING_SETUP");
        (SYS_EXIT_IO_URING_SETUP, "SYS_EXIT_IO_URING_SETUP");
        (SYS_ENTER_IO_URING_REGISTER, "SYS_ENTER_IO_URING_REGISTER");
        (SYS_EXIT_IO_URING_REGISTER, "SYS_EXIT_IO_URING_REGISTER");
        (SYS_ENTER_IO_URING_ENTER, "SYS_ENTER_IO_URING_ENTER");
        (SYS_EXIT_IO_URING_ENTER, "SYS_EXIT_IO_URING_ENTER");
      ]

  module Create = struct
    let t = structure "io_uring_create"
    let ( -: ) ty label = field t label ty
    let fd = int -: "fd"
    let ctx = ptr void -: "ctx"
    let sq_entries = uint32_t -: "sq_entries"
    let cq_entries = uint32_t -: "cq_entries"
    let flags = uint32_t -: "flags"
    let _ = seal (t : [ `Create ] structure typ)

    module Flags = struct
      let c label = constant ("IORING_SETUP_" ^ label) int64_t

      let iopoll = c "IOPOLL"
      and sqpoll = c "SQPOLL"
      and sq_aff = c "SQ_AFF"
      and cqsize = c "CQSIZE"
      and clamp = c "CLAMP"
      and attach_wq = c "ATTACH_WQ"
      and r_disabled = c "R_DISABLED"
      and submit_all = c "SUBMIT_ALL"
      and coop_taskrun = c "COOP_TASKRUN"
      and taskrun_flag = c "TASKRUN_FLAG"
      and sqe128 = c "SQE128"
      and cqe32 = c "CQE32"
      and single_issuer = c "SINGLE_ISSUER"
      and defer_taskrun = c "DEFER_TASKRUN"
    end
  end

  module Register = struct
    let t = structure "io_uring_register"
    let ( -: ) ty label = field t label ty
    let ctx = ptr void -: "ctx"
    let opcode = uint32_t -: "opcode"
    let nr_files = uint32_t -: "nr_files"
    let nr_bufs = uint32_t -: "nr_bufs"
    let ret = int64_t -: "ret"
    let _ = seal (t : [ `Register ] structure typ)
  end

  module File_get = struct
    let t = structure "io_uring_file_get"
    let ( -: ) ty label = field t label ty
    let ctx = ptr void -: "ctx"
    let req = ptr void -: "req"
    let fd = int -: "fd"
    let _ = seal (t : [ `File_get ] Ctypes.structure typ)
  end

  module Submit_sqe = struct
    let t = structure "io_uring_submit_sqe"
    let ( -: ) ty label = field t label ty
    let ctx = ptr void -: "ctx"
    let req = ptr void -: "req"
    let opcode = uchar -: "opcode"
    let flags = ulong -: "flags"
    let force_nonblock = bool -: "force_nonblock"
    let sq_thread = bool -: "sq_thread"
    let op_str = array Defines.max_op_str_len char -: "op_str"
    let _ = seal (t : [ `Submit_sqe ] Ctypes.structure typ)

    module Flags = struct
      let c label = constant ("IOSQE_" ^ label) int64_t

      let fixed_file = c "FIXED_FILE"
      and io_drain = c "IO_DRAIN"
      and io_link = c "IO_LINK"
      and io_hardlink = c "IO_HARDLINK"
      and async = c "ASYNC"
      and buffer_select = c "BUFFER_SELECT"
      and cqe_skip_success = c "CQE_SKIP_SUCCESS"
    end
  end

  module Queue_async_work = struct
    let t = structure "io_uring_queue_async_work"
    let ( -: ) ty label = field t label ty
    let ctx = ptr void -: "ctx"
    let req = ptr void -: "req"
    let opcode = uchar -: "opcode"
    let flags = uint32_t -: "flags"
    let work = ptr void -: "work"
    let op_str = array Defines.max_op_str_len char -: "op_str"
    let _ = seal (t : [ `Queue_async_work ] Ctypes.structure typ)
  end

  module Poll_arm = struct
    let t = structure "io_uring_poll_arm"
    let ( -: ) ty label = field t label ty
    let ctx = ptr void -: "ctx"
    let req = ptr void -: "req"
    let opcode = uchar -: "opcode"
    let mask = int -: "mask"
    let events = int -: "events"
    let op_str = array Defines.max_op_str_len char -: "op_str"
    let _ = seal (t : [ `Poll_arm ] Ctypes.structure typ)
  end

  module Task_add = struct
    let t = structure "io_uring_task_add"
    let ( -: ) ty label = field t label ty
    let ctx = ptr void -: "ctx"
    let req = ptr void -: "req"
    let opcode = uchar -: "opcode"
    let mask = int -: "mask"
    let op_str = array Defines.max_op_str_len char -: "op_str"
    let _ = seal (t : [ `Task_add ] Ctypes.structure typ)
  end

  module Task_work_run = struct
    let t = structure "io_uring_task_work_run"
    let ( -: ) ty label = field t label ty
    let tctx = ptr void -: "tctx"
    let count = uint32_t -: "count"
    let loops = uint32_t -: "loops"
    let _ = seal (t : [ `Task_work_run ] Ctypes.structure typ)
  end

  module Short_write = struct
    let t = structure "io_uring_short_write"
    let ( -: ) ty label = field t label ty
    let ctx = ptr void -: "ctx"
    let fpos = uint64_t -: "fpos"
    let wanted = uint64_t -: "wanted"
    let got = uint64_t -: "got"
    let _ = seal (t : [ `Short_write ] Ctypes.structure typ)
  end

  module Local_work_run = struct
    let t = structure "io_uring_local_work_run"
    let ( -: ) ty label = field t label ty
    let ctx = ptr void -: "ctx"
    let count = int -: "count"
    let loops = uint32_t -: "loops"
    let _ = seal (t : [ `Local_work_run ] Ctypes.structure typ)
  end

  module Defer = struct
    let t = structure "io_uring_defer"
    let ( -: ) ty label = field t label ty
    let ctx = ptr void -: "ctx"
    let req = ptr void -: "req"
    let opcode = uchar -: "opcode"
    let op_str = array Defines.max_op_str_len char -: "op_str"
    let _ = seal (t : [ `Defer ] Ctypes.structure typ)
  end

  module Link = struct
    let t = structure "io_uring_link"
    let ( -: ) ty label = field t label ty
    let ctx = ptr void -: "ctx"
    let req = ptr void -: "req"
    let target_req = ptr void -: "target_req"
    let _ = seal (t : [ `Link ] Ctypes.structure typ)
  end

  module Fail_link = struct
    let t = structure "io_uring_fail_link"
    let ( -: ) ty label = field t label ty
    let ctx = ptr void -: "ctx"
    let req = ptr void -: "req"
    let opcode = uchar -: "opcode"
    let link = ptr void -: "link"
    let op_str = array Defines.max_op_str_len char -: "op_str"
    let _ = seal (t : [ `Fail_link ] Ctypes.structure typ)
  end

  module Cqring_wait = struct
    let t = structure "io_uring_cqring_wait"
    let ( -: ) ty label = field t label ty
    let ctx = ptr void -: "ctx"
    let min_events = int -: "min_events"
    let _ = seal (t : [ `Cqring_wait ] Ctypes.structure typ)
  end

  module Req_failed = struct
    let t = structure "io_uring_req_failed"
    let ( -: ) ty label = field t label ty
    let ctx = ptr void -: "ctx"
    let req = ptr void -: "req"
    let opcode = uchar -: "opcode"
    let flags = uchar -: "flags"
    let ioprio = uchar -: "ioprio"
    let off = ullong -: "off"
    let addr = ullong -: "addr"
    let len = ulong -: "len"
    let op_flags = ulong -: "op_flags"
    let buf_index = uint -: "buf_index"
    let personality = uint -: "personality"
    let file_index = ulong -: "file_index"
    let pad1 = ullong -: "pad1"
    let addr3 = ullong -: "addr3"
    let error = int -: "error"
    let op_str = array Defines.max_op_str_len char -: "op_str"
    let _ = seal (t : [ `Req_failed ] Ctypes.structure typ)
  end

  module Cqe_overflow = struct
    let t = structure "io_uring_cqe_overflow"
    let ( -: ) ty label = field t label ty
    let ctx = ptr void -: "ctx"
    let user_data = ullong -: "user_data"
    let res = int -: "res"
    let cflags = ulong -: "cflags"
    let ocqe = ptr void -: "ocqe"
    let _ = seal (t : [ `Cqe_overflow ] Ctypes.structure typ)
  end

  module Complete = struct
    let t = structure "io_uring_complete"
    let ( -: ) ty label = field t label ty
    let ctx = ptr void -: "ctx"
    let req = ptr void -: "req"
    let res = int -: "res"
    let cflags = uint -: "cflags"
    let _ = seal (t : [ `Complete ] Ctypes.structure typ)

    module Flags = struct
      let c label = constant ("IORING_CQE_F_" ^ label) int64_t

      let buffer = c "BUFFER"
      and more = c "MORE"
      and sock_nonempty = c "SOCK_NONEMPTY"
      and notif = c "NOTIF"
    end
  end

  module Io_init_new_worker = struct
    let t = structure "io_init_new_worker"
    let ( -: ) ty label = field t label ty
    let io_worker_tid = int -: "io_worker_tid"
    let _ = seal (t : [`Io_init_new_worker] Ctypes.structure typ)

  end

  module Event = struct
    let t = structure "event"
    let ( -: ) ty label = field t label ty
    let ty = enum_tracepoint_t -: "ty"
    let pid = int -: "pid"
    let tid = int -: "tid"
    let ts = uint64_t -: "ts"
    let comm = array Defines.task_comm_len char -: "comm"

    (* When using stub gen interface, we can just define the union type
       directly since it uses offsets to calculate the position of the
       union members. See:
       https://github.com/yallop/ocaml-ctypes/issues/593 *)
    let io_uring_create = Create.t -: "io_uring_create"
    let io_uring_register = Register.t -: "io_uring_register"
    let io_uring_file_get = File_get.t -: "io_uring_file_get"
    let io_uring_submit_sqe = Submit_sqe.t -: "io_uring_submit_sqe"

    let io_uring_queue_async_work =
      Queue_async_work.t -: "io_uring_queue_async_work"

    let io_uring_poll_arm = Poll_arm.t -: "io_uring_poll_arm"
    let io_uring_task_add = Task_add.t -: "io_uring_task_add"
    let io_uring_task_work_run = Task_work_run.t -: "io_uring_task_work_run"
    let io_uring_short_write = Short_write.t -: "io_uring_short_write"
    let io_uring_local_work_run = Local_work_run.t -: "io_uring_local_work_run"
    let io_uring_defer = Defer.t -: "io_uring_defer"
    let io_uring_link = Link.t -: "io_uring_link"
    let io_uring_fail_link = Fail_link.t -: "io_uring_fail_link"
    let io_uring_cqring_wait = Cqring_wait.t -: "io_uring_cqring_wait"
    let io_uring_req_failed = Req_failed.t -: "io_uring_req_failed"
    let io_uring_cqe_overflow = Cqe_overflow.t -: "io_uring_cqe_overflow"
    let io_uring_complete = Complete.t -: "io_uring_complete"
    let io_init_new_worker = Io_init_new_worker.t -: "io_init_new_worker"
    let _ = seal (t : [ `Event ] Ctypes.structure typ)
  end
end
