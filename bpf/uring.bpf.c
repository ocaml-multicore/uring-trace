#include "vmlinux.h"
#include "uring.h"
#include <bpf/bpf_helpers.h>
#include <bpf/bpf_tracing.h>

extern u32 LINUX_KERNEL_VERSION __kconfig;

char LICENSE[] SEC("license") = "Dual BSD/GPL";

/* BPF ringbuf map */
struct {
  __uint(type, BPF_MAP_TYPE_RINGBUF);
  __uint(max_entries, 256 * 4096 /* 256 KB */);
} rb SEC(".maps");

/* Globals implemented as an array */
/* pid | total | lost | skipped | unrelated | sampling_idx | user_idx */
struct {
  __uint(type, BPF_MAP_TYPE_ARRAY);
  __uint(max_entries, 7);
  __type(key, int);
  __type(value, long);
} globals SEC(".maps");

const int pid_idx = 0;
const int total_idx = 1;
const int lost_idx = 2;
const int skipped_idx = 3;
const int unrelated_idx = 4;
const int sampling_idx = 5;
const int user_idx = 6;

static void __incr(const int *idx) {
  long *value;
  value = bpf_map_lookup_elem(&globals, idx);
  if (value == NULL) {
    bpf_printk("Error got NULL");
    return;
  };
  (*value)++;
  bpf_map_update_elem(&globals, idx, value, 0);
}

static int __filter_event(void *req) {

  /* Skip if perfect modulus of sampling_value */
  long *value;
  value = bpf_map_lookup_elem(&globals, &sampling_idx);
  if (value == NULL) {
    bpf_printk("Error got NULL");
    return 0;
  };

  if (*value == 1) {
    uint32_t hash = (uint32_t)req * (2654435761);
    if (hash % 10 != 0) {
      __incr(&skipped_idx);
      return 1;
    };
  };

  return 0;
}

static struct event *__init_event(enum tracepoint_t ty) {
  struct event *e;
  u64 id;

  __incr(&user_idx);
  /* Try to reserve space from BPF ringbuf */
  e = bpf_ringbuf_reserve(&rb, sizeof(*e), 0);
  if (!e) {
    __incr(&lost_idx);
    return NULL;
  }
  id = bpf_get_current_pid_tgid();
  e->ty = ty;
  e->pid = id >> 32;
  e->tid = id;
  e->ts = bpf_ktime_get_ns();
  bpf_get_current_comm(&e->comm, sizeof(e->comm));

  return e;
}

SEC("tp/io_uring/io_uring_create")
int handle_create(struct trace_event_raw_io_uring_create *ctx) {
  struct event *e;
  struct io_uring_create *extra;

  __incr(&total_idx);
  e = __init_event(IO_URING_CREATE);
  if (e == NULL)
    return 0;

  extra = &(e->io_uring_create);
  extra->fd = ctx->fd;
  extra->ctx = ctx->ctx;
  extra->sq_entries = ctx->sq_entries;
  extra->cq_entries = ctx->cq_entries;
  extra->flags = ctx->flags;

  /* This will overwrite if another create is encountered!! TODO */
  /* pid = e->pid; */
  /* bpf_map_update_elem(&globals, &pid_idx, &pid, 0); */

  bpf_ringbuf_submit(e, 0);
  return 0;
}

SEC("tp/io_uring/io_uring_register")
int handle_register(struct trace_event_raw_io_uring_register *ctx) {
  struct event *e;
  struct io_uring_register *extra;

  __incr(&total_idx);
  e = __init_event(IO_URING_REGISTER);
  if (e == NULL)
    return 0;

  extra = &(e->io_uring_register);
  extra->ctx = ctx->ctx;
  extra->opcode = ctx->opcode;
  extra->nr_files = ctx->nr_files;
  extra->ret = ctx->ret;

  bpf_ringbuf_submit(e, 0);
  return 0;
}

SEC("tp/io_uring/io_uring_file_get")
int handle_file_get(struct trace_event_raw_io_uring_file_get *ctx) {
  struct event *e;
  struct io_uring_file_get *extra;

  __incr(&total_idx);
  if (__filter_event(ctx->req) != 0)
    return 0;

  e = __init_event(IO_URING_FILE_GET);
  if (e == NULL)
    return 0;

  extra = &(e->io_uring_file_get);
  extra->ctx = ctx->ctx;
  extra->req = ctx->req;
  extra->fd = ctx->fd;

  bpf_ringbuf_submit(e, 0);
  return 0;
}

/* This is a hacky way to load the right tracepoints */
#if (MAJOR_VERSION >= 6 && MINOR_VERSION >= 3)
SEC("tp/io_uring/io_uring_submit_req")
int handle_submit_req(struct trace_event_raw_io_uring_submit_req *ctx) {
#else
SEC("tp/io_uring/io_uring_submit_sqe")
int handle_submit_req(struct trace_event_raw_io_uring_submit_sqe *ctx) {
#endif
  struct event *e;
  struct io_uring_submit_sqe *extra;

  unsigned op_str_off;

  __incr(&total_idx);
  if (__filter_event(ctx->req))
    return 0;

  /* bpf_printk("submit %d", ctx->req); */
  e = __init_event(IO_URING_SUBMIT_SQE);
  if (e == NULL)
    return 0;

  extra = &(e->io_uring_submit_sqe);
  extra->ctx = ctx->ctx;
  extra->req = ctx->req;
  extra->opcode = ctx->opcode;
  extra->flags = ctx->flags;
  extra->sq_thread = ctx->sq_thread;
  op_str_off = ctx->__data_loc_op_str & 0xFFFF;
  bpf_probe_read_str(&(extra->op_str), sizeof(extra->op_str),
                     (void *)ctx + op_str_off);

  bpf_ringbuf_submit(e, 0);
  return 0;
}

SEC("tp/io_uring/io_uring_queue_async_work")
int handle_queue_async_work(
			    struct trace_event_raw_io_uring_queue_async_work *ctx) {
  struct event *e;
  struct io_uring_queue_async_work *extra;
  unsigned op_str_off;

  __incr(&total_idx);
  if (__filter_event(ctx->req) != 0)
    return 0;

  e = __init_event(IO_URING_QUEUE_ASYNC_WORK);
  if (e == NULL)
    return 0;

  extra = &(e->io_uring_queue_async_work);
  extra->ctx = ctx->ctx;
  extra->req = ctx->req;
  extra->opcode = ctx->opcode;
  extra->flags = ctx->flags;
  extra->work = ctx->work;
  op_str_off = ctx->__data_loc_op_str & 0xFFFF;
  bpf_probe_read_str(&(extra->op_str), sizeof(extra->op_str),
                     (void *)ctx + op_str_off);

  bpf_ringbuf_submit(e, 0);
  return 0;
}

SEC("tp/io_uring/io_uring_poll_arm")
int handle_poll_arm(struct trace_event_raw_io_uring_poll_arm *ctx) {
  struct event *e;
  struct io_uring_poll_arm *extra;
  unsigned op_str_off;

  __incr(&total_idx);
  if (__filter_event(ctx->req) != 0)
    return 0;

  e = __init_event(IO_URING_POLL_ARM);
  if (e == NULL)
    return 0;

  extra = &(e->io_uring_poll_arm);
  extra->ctx = ctx->ctx;
  extra->req = ctx->req;
  extra->opcode = ctx->opcode;
  extra->mask = ctx->mask;
  extra->events = ctx->events;
  op_str_off = ctx->__data_loc_op_str & 0xFFFF;
  bpf_probe_read_str(&(extra->op_str), sizeof(extra->op_str),
                     (void *)ctx + op_str_off);

  bpf_ringbuf_submit(e, 0);
  return 0;
}

SEC("tp/io_uring/io_uring_task_add")
int handle_task_add(struct trace_event_raw_io_uring_task_add *ctx) {
  struct event *e;
  struct io_uring_task_add *extra;
  unsigned op_str_off;

  __incr(&total_idx);
  if (__filter_event(ctx->req) != 0)
    return 0;

  e = __init_event(IO_URING_TASK_ADD);
  if (e == NULL)
    return 0;

  extra = &(e->io_uring_task_add);
  extra->ctx = ctx->ctx;
  extra->req = ctx->req;
  extra->mask = ctx->mask;
  extra->opcode = ctx->opcode;
  op_str_off = ctx->__data_loc_op_str & 0xFFFF;
  bpf_probe_read_str(&(extra->op_str), sizeof(extra->op_str),
                     (void *)ctx + op_str_off);

  bpf_ringbuf_submit(e, 0);
  return 0;
}

SEC("tp/io_uring/io_uring_task_work_run")
int handle_task_work_run(struct trace_event_raw_io_uring_task_work_run *ctx) {
  struct event *e;
  struct io_uring_task_work_run *extra;

  __incr(&total_idx);
  e = __init_event(IO_URING_TASK_WORK_RUN);
  if (e == NULL)
    return 0;

  extra = &(e->io_uring_task_work_run);
  extra->tctx = ctx->tctx;
  extra->count = ctx->count;
  extra->loops = ctx->loops;

  bpf_ringbuf_submit(e, 0);
  return 0;
}

SEC("tp/io_uring/io_uring_short_write")
int handle_short_write(struct trace_event_raw_io_uring_short_write *ctx) {
  struct event *e;
  struct io_uring_short_write *extra;

  __incr(&total_idx);
  e = __init_event(IO_URING_SHORT_WRITE);
  if (e == NULL)
    return 0;

  extra = &(e->io_uring_short_write);
  extra->ctx = ctx->ctx;
  extra->fpos = ctx->fpos;
  extra->wanted = ctx->wanted;
  extra->got = ctx->got;

  bpf_ringbuf_submit(e, 0);
  return 0;
}

SEC("tp/io_uring/io_uring_local_work_run")
int handle_local_work_run(struct trace_event_raw_io_uring_local_work_run *ctx) {
  struct event *e;
  struct io_uring_local_work_run *extra;

  __incr(&total_idx);
  e = __init_event(IO_URING_TASK_WORK_RUN);
  if (e == NULL)
    return 0;

  extra = &(e->io_uring_local_work_run);
  extra->ctx = ctx->ctx;
  extra->count = ctx->count;
  extra->loops = ctx->loops;

  bpf_ringbuf_submit(e, 0);
  return 0;
}

SEC("tp/io_uring/io_uring_defer")
int handle_defer(struct trace_event_raw_io_uring_defer *ctx) {
  struct event *e;
  struct io_uring_defer *extra;
  unsigned op_str_off;

  __incr(&total_idx);
  if (__filter_event(ctx->req) != 0)
    return 0;

  e = __init_event(IO_URING_DEFER);
  if (e == NULL)
    return 0;

  extra = &(e->io_uring_defer);
  extra->ctx = ctx->ctx;
  extra->req = ctx->req;
  extra->opcode = ctx->opcode;
  op_str_off = ctx->__data_loc_op_str & 0xFFFF;
  bpf_probe_read_str(&(extra->op_str), sizeof(extra->op_str),
                     (void *)ctx + op_str_off);

  bpf_ringbuf_submit(e, 0);
  return 0;
}

SEC("tp/io_uring/io_uring_link")
int handle_link(struct trace_event_raw_io_uring_link *ctx) {
  struct event *e;
  struct io_uring_link *extra;

  __incr(&total_idx);
  if (__filter_event(ctx->req) != 0)
    return 0;

  e = __init_event(IO_URING_LINK);
  if (e == NULL)
    return 0;

  extra = &(e->io_uring_link);
  extra->ctx = ctx->ctx;
  extra->req = ctx->req;
  extra->target_req = ctx->target_req;

  bpf_ringbuf_submit(e, 0);
  return 0;
}

SEC("tp/io_uring/io_uring_fail_link")
int handle_fail_link(struct trace_event_raw_io_uring_fail_link *ctx) {
  struct event *e;
  struct io_uring_fail_link *extra;
  unsigned op_str_off;

  __incr(&total_idx);
  if (__filter_event(ctx->req) != 0)
    return 0;

  e = __init_event(IO_URING_FAIL_LINK);
  if (e == NULL)
    return 0;

  extra = &(e->io_uring_fail_link);
  extra->ctx = ctx->ctx;
  extra->req = ctx->req;
  extra->opcode = ctx->opcode;
  extra->link = ctx->link;
  op_str_off = ctx->__data_loc_op_str & 0xFFFF;
  bpf_probe_read_str(&(extra->op_str), sizeof(extra->op_str),
                     (void *)ctx + op_str_off);

  bpf_ringbuf_submit(e, 0);
  return 0;
}

SEC("tp/io_uring/io_uring_cqring_wait")
int handle_cqring_wait(struct trace_event_raw_io_uring_cqring_wait *ctx) {
  struct event *e;
  struct io_uring_cqring_wait *extra;

  __incr(&total_idx);
  e = __init_event(IO_URING_CQRING_WAIT);
  if (e == NULL)
    return 0;

  extra = &(e->io_uring_cqring_wait);
  extra->ctx = ctx->ctx;
  extra->min_events = ctx->min_events;

  bpf_ringbuf_submit(e, 0);
  return 0;
}

SEC("tp/io_uring/io_uring_req_failed")
int handle_req_failed(struct trace_event_raw_io_uring_req_failed *ctx) {
  struct event *e;
  struct io_uring_req_failed *extra;
  unsigned op_str_off;

  __incr(&total_idx);
  if (__filter_event(ctx->req) != 0)
    return 0;

  e = __init_event(IO_URING_REQ_FAILED);
  if (e == NULL)
    return 0;

  extra = &(e->io_uring_req_failed);
  extra->ctx = ctx->ctx;
  extra->req = ctx->req;
  extra->opcode = ctx->opcode;
  extra->flags = ctx->flags;
  extra->ioprio = ctx->ioprio;
  extra->off = ctx->off;
  extra->addr = ctx->addr;
  extra->len = ctx->len;
  extra->op_flags = ctx->op_flags;
  extra->buf_index = ctx->buf_index;
  extra->personality = ctx->personality;
  extra->file_index = ctx->file_index;
  extra->pad1 = ctx->pad1;
  extra->addr3 = ctx->addr3;
  extra->error = ctx->error;
  op_str_off = ctx->__data_loc_op_str & 0xFFFF;
  bpf_probe_read_str(&(extra->op_str), sizeof(extra->op_str),
                     (void *)ctx + op_str_off);

  bpf_ringbuf_submit(e, 0);
  return 0;
}

SEC("tp/io_uring/io_uring_cqe_overflow")
int handle_cqe_overflow(struct trace_event_raw_io_uring_cqe_overflow *ctx) {
  struct event *e;
  struct io_uring_cqe_overflow *extra;

  __incr(&total_idx);
  e = __init_event(IO_URING_CQE_OVERFLOW);
  if (e == NULL)
    return 0;

  extra = &(e->io_uring_cqe_overflow);
  extra->ctx = ctx->ctx;
  extra->user_data = ctx->user_data;
  extra->res = ctx->res;
  extra->cflags = ctx->cflags;
  extra->ocqe = ctx->ocqe;

  bpf_ringbuf_submit(e, 0);
  return 0;
}

SEC("tp/io_uring/io_uring_complete")
int handle_complete(struct trace_event_raw_io_uring_complete *ctx) {
  struct event *e;
  struct io_uring_complete *extra;

  __incr(&total_idx);
  if (__filter_event(ctx->req) != 0)
    return 0;

  e = __init_event(IO_URING_COMPLETE);
  if (e == NULL)
    return 0;

  extra = &(e->io_uring_complete);
  extra->ctx = ctx->ctx;
  extra->req = ctx->req;
  extra->res = ctx->res;
  extra->cflags = ctx->cflags;

  bpf_ringbuf_submit(e, 0);
  return 0;
}

SEC("kprobe/io_init_new_worker")
int BPF_KPROBE(handle_io_init_new_worker, struct io_wq *wq,
               struct io_worker *worker, struct task_struct *tsk) {
  struct event *e;
  struct io_init_new_worker *extra;

  __incr(&total_idx);
  e = __init_event(KPROBE_IO_INIT_NEW_WORKER);
  if (e == NULL)
    return 0;

  /* The kernel uses the PID slot here for what we semantically use
     tid for */
  extra = &(e->io_init_new_worker);
  bpf_probe_read_kernel(&(extra->io_worker_tid), sizeof(int), &(tsk->pid));
  bpf_ringbuf_submit(e, 0);
  return 0;
}

SEC("tp/syscalls/sys_enter_io_uring_setup")
int handle_sys_enter_io_uring_setup(struct trace_event_raw_sys_enter *ctx) {
  struct event *e;

  __incr(&total_idx);
  e = __init_event(SYS_ENTER_IO_URING_SETUP);
  if (e == NULL)
    return 0;

  bpf_ringbuf_submit(e, 0);
  return 0;
}

SEC("tp/syscalls/sys_exit_io_uring_setup")
int handle_sys_exit_io_uring_setup(struct trace_event_raw_sys_enter *ctx) {
  struct event *e;

  __incr(&total_idx);
  e = __init_event(SYS_EXIT_IO_URING_SETUP);
  if (e == NULL)
    return 0;

  bpf_ringbuf_submit(e, 0);
  return 0;
}

SEC("tp/syscalls/sys_enter_io_uring_register")
int handle_sys_enter_io_uring_register(struct trace_event_raw_sys_enter *ctx) {
  struct event *e;

  __incr(&total_idx);
  e = __init_event(SYS_ENTER_IO_URING_REGISTER);
  if (e == NULL)
    return 0;

  bpf_ringbuf_submit(e, 0);
  return 0;
}

SEC("tp/syscalls/sys_exit_io_uring_register")
int handle_sys_exit_io_uring_register(struct trace_event_raw_sys_enter *ctx) {
  struct event *e;

  __incr(&total_idx);
  e = __init_event(SYS_EXIT_IO_URING_REGISTER);
  if (e == NULL)
    return 0;

  bpf_ringbuf_submit(e, 0);
  return 0;
}

SEC("tp/syscalls/sys_enter_io_uring_enter")
int handle_sys_enter_io_uring_enter(struct trace_event_raw_sys_enter *ctx) {
  struct event *e;

  __incr(&total_idx);
  e = __init_event(SYS_ENTER_IO_URING_ENTER);
  if (e == NULL)
    return 0;

  bpf_ringbuf_submit(e, 0);
  return 0;
}

SEC("tp/syscalls/sys_exit_io_uring_enter")
int handle_sys_exit_io_uring_enter(struct trace_event_raw_sys_enter *ctx) {
  struct event *e;

  __incr(&total_idx);
  e = __init_event(SYS_EXIT_IO_URING_ENTER);
  if (e == NULL)
    return 0;

  bpf_ringbuf_submit(e, 0);
  return 0;
}
