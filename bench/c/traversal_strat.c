#define _GNU_SOURCE

#include "cp.h"
#include <dirent.h>
#include <err.h>
#include <error.h>
#include <fcntl.h>
#include <liburing.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

int fcp_wrapper(char *src, char *dst, mode_t perm, size_t len, fcp_fn fn) {
  int from_fd, to_fd, res;

  if ((from_fd = open(src, O_RDONLY)) < 0) {
    perror("open");
    exit(1);
  }

  if ((to_fd = creat(dst, perm)) < 0) {
    perror("creat");
    exit(1);
  };

  res = fn(from_fd, to_fd, len);

  close(from_fd);
  close(to_fd);

  return res;
}

int seq_traverse(char *src, char *dst, fcp_fn fn) {
  DIR *dir;
  struct dirent *ent;
  struct stat statbuf;
  char src_path[PATH_MAX];
  char dst_path[PATH_MAX];

  if ((dir = opendir(src)) == NULL) {
    perror("opendir");
    exit(1);
  }

  if (mkdir(dst, 0755) < 0) {
    perror("mkdir");
    exit(1);
  }

  while ((ent = readdir(dir)) != NULL) {
    if (strcmp(ent->d_name, ".") == 0 || strcmp(ent->d_name, "..") == 0)
      continue;

    snprintf(src_path, sizeof(src_path), "%s/%s", src, ent->d_name);
    snprintf(dst_path, sizeof(dst_path), "%s/%s", dst, ent->d_name);

    if (lstat(src_path, &statbuf) < 0) {
      perror("lstat");
      continue;
    }

    if (S_ISREG(statbuf.st_mode)) {
      fcp_wrapper(src_path, dst_path, statbuf.st_mode, statbuf.st_size, fn);
    } else if (S_ISDIR(statbuf.st_mode)) {
      seq_traverse(src_path, dst_path, fn);
    } else {
      err(1, "Not sure how to handle this type of file: %s", src_path);
    }
  }

  closedir(dir);
  return 0;
}

int uring_traverse(struct io_uring *ring, char *src, char *dst) {
  int errn;
  DIR *dir;
  struct dirent *ent;
  struct statx statxbuf;
  char src_path[PATH_MAX];
  char dst_path[PATH_MAX];
  struct io_uring_sqe *sqe;
  struct io_uring_cqe *cqe;

  /* Check that it's not null */
  if ((dir = opendir(src)) == NULL) {
    perror("opendir");
    exit(1);
  }

  sqe = get_sqe(ring);
  io_uring_prep_mkdir(sqe, dst, 0755);

  if ((errn = io_uring_submit_and_wait(ring, 1)) <= 0) {
    error(1, -errn, "io_uring_submit_and_wait");
  };

  io_uring_wait_cqe(ring, &cqe);
  io_uring_cqe_seen(ring, cqe);
  if ((errn = cqe->res)) {
      error(1, -errn, "mkdir");
  }

  while ((ent = readdir(dir)) != NULL) {
    if (strcmp(ent->d_name, ".") == 0 || strcmp(ent->d_name, "..") == 0)
      continue;

    snprintf(src_path, sizeof(src_path), "%s/%s", src, ent->d_name);
    snprintf(dst_path, sizeof(dst_path), "%s/%s", dst, ent->d_name);

    sqe = io_uring_get_sqe(ring);
    io_uring_prep_statx(sqe, AT_FDCWD, src_path, 0, STATX_SIZE | STATX_MODE,
                        &statxbuf);


    if ((errn = io_uring_submit_and_wait(ring, 1)) <= 0) {
      error(1, -errn, "io_uring_submit_and_wait");
    };

    io_uring_wait_cqe(ring, &cqe);
    io_uring_cqe_seen(ring, cqe);

    if (S_ISREG(statxbuf.stx_mode)) {

      int from_fd, to_fd;

      if ((from_fd = open(src_path, O_RDONLY)) < 0) {
        perror("open");
        exit(1);
      }

      if ((to_fd = creat(dst_path, 0644)) < 0) {
        perror("creat");
        exit(1);
      };

      ring_rw_cp_v1(ring, from_fd, to_fd, statxbuf.stx_size);

      close(from_fd);
      close(to_fd);

      /* Insert file copy here */
    } else if (S_ISDIR(statxbuf.stx_mode)) {
        uring_traverse(ring, src_path, dst_path);
    } else {
      printf("Not sure how to handle this type of file: %s", src_path);
      exit(1);
    }
  }

  return 0;
};
