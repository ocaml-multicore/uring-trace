#define _GNU_SOURCE

#include <errno.h>
#include <fcntl.h>
#include <liburing.h>
#include <linux/stat.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/sendfile.h>
#include <sys/stat.h>
#include <unistd.h>

#include "cp.h"

int rw_cp(int from, int to, size_t len) {
  char buf[BUFSIZ];
  int res;

  while ((res = read(from, buf, BUFSIZ))) {
    write(to, buf, res);
  }

  if (errno) {
    perror("read/write");
    exit(1);
  }

  return 0;
};

int sp_cp(int from, int to, size_t len) {

  int pipefd[2];

  if (pipe(pipefd) != 0) {
    perror("pipe");
  };

  /* Limit is 65536 bytes */
  while ((splice(from, NULL, pipefd[1], NULL, len, 0) > 0) &&
         (splice(pipefd[0], NULL, to, NULL, len, 0) > 0)) {

    if (errno) {
      perror("splice");
      exit(1);
    }
  };

  close(pipefd[0]);
  close(pipefd[1]);
  return 0;
}

/* sendfile */
int sf_cp(int from, int to, size_t len) {

  /* Limit is 2 GB */
  while (sendfile(to, from, NULL, len) > 0) {
  };
  if (errno) {
    perror("sendfile");
    exit(1);
  }

  return 0;
};

int cf_cp(int from, int to, size_t len) {

  /* Limit is filesystem dependent */
  while (copy_file_range(from, NULL, to, NULL, len, 0) > 0) {
  };
  if (errno) {
    perror("copy_file_range");
    exit(1);
  }

  return 0;
};

struct io_uring_sqe *get_sqe(struct io_uring *ring) {
  struct io_uring_sqe *sqe;
  while ((sqe = io_uring_get_sqe(ring)) == NULL) {
    /* Keep trying to get available sqe */
  };
  return sqe;
}

int ring_rw_cp_v1(struct io_uring *ring, int fd_from, int fd_to, size_t len) {
  struct io_uring_sqe *sqe;
  struct io_uring_cqe *cqe;
  char buf[BUFSIZ];
  int offset = 0;

  for (; offset < len; offset += cqe->res) {
    /* Do read */
    get_sqe(ring);
    io_uring_prep_read(sqe, fd_from, buf, BUFSIZ, offset);
    io_uring_submit(ring);
    io_uring_wait_cqe(ring, &cqe);
    io_uring_cqe_seen(ring, cqe);

    /* Do write */
    sqe = get_sqe(ring);
    io_uring_prep_write(sqe, fd_to, buf, cqe->res /* number of read bytes */,
                        offset);
    io_uring_submit(ring);
    io_uring_wait_cqe(ring, &cqe);
    io_uring_cqe_seen(ring, cqe);
  }

  return 0;
};
