#ifndef CP_H
#define CP_H

#include <sys/types.h>
#include <dirent.h>

/* Copy strategy */
typedef int (*fcp_fn)(int fd_from, int fd_to, size_t len);
int rw_cp(int, int, size_t); /* read write */
int sp_cp(int, int, size_t); /* splice */
int sf_cp(int, int, size_t); /* sendfile */
int cf_cp(int, int, size_t); /* copy_file_range */

/* Traversal strategy */
int seq_traverse(char *, char *, fcp_fn fn);
int posix_traverse(char *, char *, fcp_fn fn);
int epoll_traverse(char *, char *, fcp_fn fn);
int uring_traverse(char *, char *, fcp_fn fn);

#endif
