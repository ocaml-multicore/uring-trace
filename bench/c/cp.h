#ifndef CP_H
#define CP_H

#include <dirent.h>
#include <liburing.h>
#include <sys/types.h>

/* Copy strategy */
typedef int (*fcp_fn)(int fd_from, int fd_to, size_t len);
int rw_cp(int, int, size_t); /* read write */
int sp_cp(int, int, size_t); /* splice */
int sf_cp(int, int, size_t); /* sendfile */
int cf_cp(int, int, size_t); /* copy_file_range */

struct io_uring_sqe *get_sqe(struct io_uring *ring);
typedef int (*fcp_fn_uring)(struct io_uring *, int fd_from, int fd_to,
                            size_t len);
int ring_rw_cp_v1(struct io_uring *, int, int, size_t);
int ring_rw_cp_v2(struct io_uring *, int, int, size_t); /* Interleaving RW */
int ring_rw_cp_v3(struct io_uring *, int, int,
                  size_t); /* Parallel Reads into iovec & Writev */
int ring_rw_cp_v4(struct io_uring *, int, int,
                  size_t); /* SQ-polling && Completion-polling */

/* Traversal strategy */
int seq_traverse(char *, char *, fcp_fn fn);
int posix_traverse(char *, char *, fcp_fn fn);
int epoll_traverse(char *, char *, fcp_fn fn);
int uring_traverse(struct io_uring *, char *, char *);

#endif
