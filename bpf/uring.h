#ifndef __URING_IO_H
#define __URING_IO_H

#include <stdbool.h>
#define TASK_COMM_LEN 16
#define MAX_OP_STR_LEN 127

/* Shim for old kernel versions */
struct trace_event_raw_io_uring_submit_sqe {
	struct trace_entry ent;
	void *ctx;
	void *req;
	long long unsigned int user_data;
	u8 opcode;
	u32 flags;
	bool force_nonblock;
	bool sq_thread;
	u32 __data_loc_op_str;
	char __data[0];
};

enum tracepoint_t {
  IO_URING_CREATE,
  IO_URING_REGISTER,
  IO_URING_FILE_GET,
  IO_URING_SUBMIT_SQE,
  IO_URING_QUEUE_ASYNC_WORK,
  IO_URING_POLL_ARM,
  IO_URING_TASK_ADD,
  IO_URING_TASK_WORK_RUN,
  IO_URING_SHORT_WRITE,
  IO_URING_LOCAL_WORK_RUN,
  IO_URING_DEFER,
  IO_URING_LINK,
  IO_URING_FAIL_LINK,
  IO_URING_CQRING_WAIT,
  IO_URING_REQ_FAILED,
  IO_URING_CQE_OVERFLOW,
  IO_URING_COMPLETE,
  KPROBE_IO_INIT_NEW_WORKER,
  SYS_ENTER_IO_URING_SETUP,
  SYS_EXIT_IO_URING_SETUP,
  SYS_ENTER_IO_URING_REGISTER,
  SYS_EXIT_IO_URING_REGISTER,
  SYS_ENTER_IO_URING_ENTER,
  SYS_EXIT_IO_URING_ENTER
};

struct io_uring_create {
  int fd;
  void *ctx;
  unsigned long sq_entries;
  unsigned long cq_entries;
  unsigned long flags;
};

struct io_uring_register {
  void *ctx;
  unsigned opcode;
  unsigned nr_files;
  unsigned nr_bufs;
  long ret;
};

struct io_uring_file_get {
  void *ctx;
  void *req;
  /* unsigned long long user_data; */
  int fd;
};

struct io_uring_submit_sqe {
  void *ctx;
  void *req;
  /* unsigned long long user_data; */
  unsigned char opcode;
  unsigned long flags;
  bool force_nonblock;
  bool sq_thread;
  /* unsigned long __data_loc_op_str; */
  char op_str[MAX_OP_STR_LEN];
};

struct io_uring_queue_async_work {
  void *ctx;
  void *req;
  /* unsigned long long user_data; */
  unsigned char opcode;
  unsigned int flags;
  void *work;
  /* int rw; */
  /* unsigned long __data_loc_op_str; */
  char op_str[MAX_OP_STR_LEN];
};

struct io_uring_poll_arm {
  void *ctx;
  void *req;
  /* unsigned long long user_data; */
  unsigned char opcode;
  int mask;
  int events;
  char op_str[MAX_OP_STR_LEN];
};

struct io_uring_task_add {
  void *ctx;
  void *req;
  /* unsigned long long user_data; */
  unsigned char opcode;
  int mask;
  char op_str[MAX_OP_STR_LEN];
};

struct io_uring_task_work_run {
  void *tctx;
  unsigned int count;
  unsigned int loops;
};

struct io_uring_short_write {
  void *ctx;
  unsigned long long fpos;
  unsigned long long wanted;
  unsigned long long got;
};

struct io_uring_local_work_run {
  void *ctx;
  int count;
  unsigned int loops;
};

struct io_uring_defer {
  void *ctx;
  void *req;
  /* unsigned long long data; */
  unsigned char opcode;
  char op_str[MAX_OP_STR_LEN];
};

struct io_uring_link {

  void *ctx;
  void *req;
  void *target_req;
};

struct io_uring_fail_link {
  void *ctx;
  void *req;
  /* unsigned long long user_data; */
  unsigned char opcode;
  void *link;
  char op_str[MAX_OP_STR_LEN];
};

struct io_uring_cqring_wait {
  void *ctx;
  int min_events;
};

struct io_uring_req_failed {
  void *ctx;
  void *req;
  /* unsigned long long user_data; */
  unsigned char opcode;
  unsigned char flags;
  unsigned char ioprio;
  unsigned long long off;
  unsigned long long addr;
  unsigned long len;
  unsigned long op_flags;
  unsigned int buf_index;
  unsigned int personality;
  unsigned long file_index;
  unsigned long long pad1;
  unsigned long long addr3;
  int error;
  char op_str[MAX_OP_STR_LEN];
};

struct io_uring_cqe_overflow {
  void *ctx;
  unsigned long long user_data;
  long res;
  unsigned long cflags;
  void *ocqe;
};

struct io_uring_complete {
  void *ctx;
  void *req;
  /* unsigned long long user_data; */
  int res;
  unsigned int cflags;
  /* unsigned long long extra1; */
  /* unsigned long long extra2; */
};

struct io_init_new_worker {
  int io_worker_tid;
};

/* struct sys_enter_io_uring_enter { */
/*     unsigned int fd; */
/*     unsigned long to_submit; */
/*     unsigned long min_complete; */
/*     unsigned long flags; */
/*     unsigned */
/* } */

struct event {
  enum tracepoint_t ty;
  int pid;
  int tid;
  unsigned long long ts;
  char comm[TASK_COMM_LEN];
  union {
    struct io_uring_create io_uring_create;
    struct io_uring_register io_uring_register;
    struct io_uring_file_get io_uring_file_get;
    struct io_uring_submit_sqe io_uring_submit_sqe;
    struct io_uring_queue_async_work io_uring_queue_async_work;
    struct io_uring_poll_arm io_uring_poll_arm;
    struct io_uring_task_add io_uring_task_add;
    struct io_uring_task_work_run io_uring_task_work_run;
    struct io_uring_short_write io_uring_short_write;
    struct io_uring_local_work_run io_uring_local_work_run;
    struct io_uring_defer io_uring_defer;
    struct io_uring_link io_uring_link;
    struct io_uring_fail_link io_uring_fail_link;
    struct io_uring_cqring_wait io_uring_cqring_wait;
    struct io_uring_req_failed io_uring_req_failed;
    struct io_uring_cqe_overflow io_uring_cqe_overflow;
    struct io_uring_complete io_uring_complete;
    struct io_init_new_worker io_init_new_worker;
  };
};

/* enum io_uring_op { */
/* 	IORING_OP_NOP = 0, */
/* 	IORING_OP_READV = 1, */
/* 	IORING_OP_WRITEV = 2, */
/* 	IORING_OP_FSYNC = 3, */
/* 	IORING_OP_READ_FIXED = 4, */
/* 	IORING_OP_WRITE_FIXED = 5, */
/* 	IORING_OP_POLL_ADD = 6, */
/* 	IORING_OP_POLL_REMOVE = 7, */
/* 	IORING_OP_SYNC_FILE_RANGE = 8, */
/* 	IORING_OP_SENDMSG = 9, */
/* 	IORING_OP_RECVMSG = 10, */
/* 	IORING_OP_TIMEOUT = 11, */
/* 	IORING_OP_TIMEOUT_REMOVE = 12, */
/* 	IORING_OP_ACCEPT = 13, */
/* 	IORING_OP_ASYNC_CANCEL = 14, */
/* 	IORING_OP_LINK_TIMEOUT = 15, */
/* 	IORING_OP_CONNECT = 16, */
/* 	IORING_OP_FALLOCATE = 17, */
/* 	IORING_OP_OPENAT = 18, */
/* 	IORING_OP_CLOSE = 19, */
/* 	IORING_OP_FILES_UPDATE = 20, */
/* 	IORING_OP_STATX = 21, */
/* 	IORING_OP_READ = 22, */
/* 	IORING_OP_WRITE = 23, */
/* 	IORING_OP_FADVISE = 24, */
/* 	IORING_OP_MADVISE = 25, */
/* 	IORING_OP_SEND = 26, */
/* 	IORING_OP_RECV = 27, */
/* 	IORING_OP_OPENAT2 = 28, */
/* 	IORING_OP_EPOLL_CTL = 29, */
/* 	IORING_OP_SPLICE = 30, */
/* 	IORING_OP_PROVIDE_BUFFERS = 31, */
/* 	IORING_OP_REMOVE_BUFFERS = 32, */
/* 	IORING_OP_TEE = 33, */
/* 	IORING_OP_SHUTDOWN = 34, */
/* 	IORING_OP_RENAMEAT = 35, */
/* 	IORING_OP_UNLINKAT = 36, */
/* 	IORING_OP_MKDIRAT = 37, */
/* 	IORING_OP_SYMLINKAT = 38, */
/* 	IORING_OP_LINKAT = 39, */
/* 	IORING_OP_MSG_RING = 40, */
/* 	IORING_OP_FSETXATTR = 41, */
/* 	IORING_OP_SETXATTR = 42, */
/* 	IORING_OP_FGETXATTR = 43, */
/* 	IORING_OP_GETXATTR = 44, */
/* 	IORING_OP_SOCKET = 45, */
/* 	IORING_OP_URING_CMD = 46, */
/* 	IORING_OP_SEND_ZC = 47, */
/* 	IORING_OP_SENDMSG_ZC = 48, */
/* 	IORING_OP_LAST = 49, */
/* }; */

#endif
