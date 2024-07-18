#define _GNU_SOURCE

#include <error.h>
#include <fcntl.h>
#include <liburing.h>
#include <liburing/io_uring.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#include "cp.h"

int main(int argc, char **argv) {

  int fd_from, fd_to, res;
  struct statx statxbuf;
  fcp_fn fn;

  if (argc < 2) {

    printf("Usage:\n\t%s <cp_strategy> <file to copy>", argv[0]);
    printf("\n\t%s <cp_strategy> <traversal_strategy> <src dir> <dst dir>",
           argv[0]);
    exit(1);

  } else {

    if (strcmp(argv[1], "rw") == 0) {
      fn = rw_cp;
    } else if (strcmp(argv[1], "sp") == 0) {
      fn = sp_cp;

    } else if (strcmp(argv[1], "sf") == 0) {
      fn = sf_cp;

    } else if (strcmp(argv[1], "cf") == 0) {
      fn = cf_cp;
    } else if (strcmp(argv[1], "iou") == 0) {
      printf("uring selected\n");
    } else {
      printf("Error: strategy must be one of rw,sp,sf,cf\n");
      exit(1);
    };

    /* Copying a file */
    if (argc == 3) {
      /* Open fd for file to copy */
      fd_from = open(argv[2], O_RDONLY);
      /* Open fd for output */
      fd_to = open(strcat(argv[2], ".copy"), O_CREAT | O_WRONLY | O_TRUNC, 0644);
      /* Get file size to copy */
      if (statx(fd_from, "", AT_EMPTY_PATH, STATX_SIZE, &statxbuf)) {
        perror("statx");
        exit(1);
      };

      res = fn(fd_from, fd_to, statxbuf.stx_size);

      fsync(fd_to);
      close(fd_from);
      close(fd_to);

      return res;
    }

    /* Copying a directory */
    else if (argc == 5) {

      if (strcmp(argv[2], "seq") == 0) {
        return seq_traverse(argv[3], argv[4], fn);
      } else if (strcmp(argv[2], "uring") == 0) {
        struct io_uring ring;
        int err;
        if ((err = io_uring_queue_init(64, &ring, 0)) != 0) {
            error(1, -err, "io_uring_queue_init");
        }
        uring_traverse(&ring, argv[3], argv[4]);
        io_uring_queue_exit(&ring);
      } else {
        printf("Error: strategy must be one of seq,uring\n");
        exit(1);
      };
    }
  };

  return 0;
}
