(* /* *)
(*  * io_uring_setup() flags *)
(*  */ *)
(* #define IORING_SETUP_IOPOLL	(1U << 0)	/* io_context is polled */ *)
(* #define IORING_SETUP_SQPOLL	(1U << 1)	/* SQ poll thread */ *)
(* #define IORING_SETUP_SQ_AFF	(1U << 2)	/* sq_thread_cpu is valid */ *)
(* #define IORING_SETUP_CQSIZE	(1U << 3)	/* app defines CQ size */ *)
(* #define IORING_SETUP_CLAMP	(1U << 4)	/* clamp SQ/CQ ring sizes */ *)
(* #define IORING_SETUP_ATTACH_WQ	(1U << 5)	/* attach to existing wq */ *)
(* #define IORING_SETUP_R_DISABLED	(1U << 6)	/* start with ring disabled */ *)
(* #define IORING_SETUP_SUBMIT_ALL	(1U << 7)	/* continue submit on error */ *)
(* /* *)
(*  * Cooperative task running. When requests complete, they often require *)
(*  * forcing the submitter to transition to the kernel to complete. If this *)
(*  * flag is set, work will be done when the task transitions anyway, rather *)
(*  * than force an inter-processor interrupt reschedule. This avoids interrupting *)
(*  * a task running in userspace, and saves an IPI. *)
(*  */ *)
(* #define IORING_SETUP_COOP_TASKRUN	(1U << 8) *)
(* /* *)
(*  * If COOP_TASKRUN is set, get notified if task work is available for *)
(*  * running and a kernel transition would be needed to run it. This sets *)
(*  * IORING_SQ_TASKRUN in the sq ring flags. Not valid with COOP_TASKRUN. *)
(*  */ *)
(* #define IORING_SETUP_TASKRUN_FLAG	(1U << 9) *)
(* #define IORING_SETUP_SQE128		(1U << 10) /* SQEs are 128 byte */ *)
(* #define IORING_SETUP_CQE32		(1U << 11) /* CQEs are 32 byte */ *)
(* /* *)
(*  * Only one task is allowed to submit requests *)
(*  */ *)
(* #define IORING_SETUP_SINGLE_ISSUER	(1U << 12) *)

(* /* *)
(*  * Defer running task work to get events. *)
(*  * Rather than running bits of task work whenever the task transitions *)
(*  * try to do it just before it is needed. *)
(*  */ *)
(* #define IORING_SETUP_DEFER_TASKRUN	(1U << 13) *)
type setup_flags =
  | IOPOLL
  | SQPOLL
  | SQ_AF
  | CQSIZE
  | CLAMP
  | ATTACH_WQ
  | R_DISABLED
  | SUBMIT_ALL
  | COOP_TASKRUN
  | TASKRUN_FLAG
  | SQE128
  | CQE32
  | SINGLE_ISSUER
  | DEFER_TASKRUN
[@@deriving show { with_path = false }]

(*   /* *)
(*  * sqe->flags *)
(*  */ *)
(* /* use fixed fileset */ *)
(* #define IOSQE_FIXED_FILE	(1U << IOSQE_FIXED_FILE_BIT) *)
(* /* issue after inflight IO */ *)
(* #define IOSQE_IO_DRAIN		(1U << IOSQE_IO_DRAIN_BIT) *)
(* /* links next sqe */ *)
(* #define IOSQE_IO_LINK		(1U << IOSQE_IO_LINK_BIT) *)
(* /* like LINK, but stronger */ *)
(* #define IOSQE_IO_HARDLINK	(1U << IOSQE_IO_HARDLINK_BIT) *)
(* /* always go async */ *)
(* #define IOSQE_ASYNC		(1U << IOSQE_ASYNC_BIT) *)
(* /* select buffer from sqe->buf_group */ *)
(* #define IOSQE_BUFFER_SELECT	(1U << IOSQE_BUFFER_SELECT_BIT) *)
(* /* don't post CQE if request succeeded */ *)
(* #define IOSQE_CQE_SKIP_SUCCESS	(1U << IOSQE_CQE_SKIP_SUCCESS_BIT) *)
type sqe_flags =
  | FIXED_FILE
  | IO_DRAIN
  | IO_LINK
  | IO_HARDLINK
  | ASYNC
  | BUFFER_SELECT
  | CQE_SKIP_SUCCESS
[@@deriving show { with_path = false }]

(* /* *)
(*  * cqe->flags *)
(*  * *)
(*  * IORING_CQE_F_BUFFER	If set, the upper 16 bits are the buffer ID *)
(*  * IORING_CQE_F_MORE	If set, parent SQE will generate more CQE entries *)
(*  * IORING_CQE_F_SOCK_NONEMPTY	If set, more data to read after socket recv *)
(*  * IORING_CQE_F_NOTIF	Set for notification CQEs. Can be used to distinct *)
(*  * 			them from sends. *)
(*  */ *)
type cqe_flags = BUFFER | MORE | SOCK_NONEMPTY | NOTIF [@@deriving show {with_path = false}]

type tracepoint_t =
  | IO_URING_CREATE
  | IO_URING_REGISTER
  | IO_URING_FILE_GET
  | IO_URING_SUBMIT_SQE
  | IO_URING_QUEUE_ASYNC_WORK
  | IO_URING_POLL_ARM
  | IO_URING_TASK_ADD
  | IO_URING_TASK_WORK_RUN
  | IO_URING_SHORT_WRITE
  | IO_URING_LOCAL_WORK_RUN
  | IO_URING_DEFER
  | IO_URING_LINK
  | IO_URING_FAIL_LINK
  | IO_URING_CQRING_WAIT
  | IO_URING_REQ_FAILED
  | IO_URING_CQE_OVERFLOW
  | IO_URING_COMPLETE
  | KPROBE_IO_INIT_NEW_WORKER
  | SYS_ENTER_IO_URING_SETUP
  | SYS_EXIT_IO_URING_SETUP
  | SYS_ENTER_IO_URING_REGISTER
  | SYS_EXIT_IO_URING_REGISTER
  | SYS_ENTER_IO_URING_ENTER
  | SYS_EXIT_IO_URING_ENTER
[@@deriving show { with_path = false }]
