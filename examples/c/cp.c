#define _GNU_SOURCE

#include <fcntl.h>
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
    printf(
        "\n\t%s <cp_strategy> <traversal_strategy> <src dir to copy> <dst dir>",
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
    } else {
      printf("Error: strategy must be one of rw,sp,sf,cf\n");
      exit(1);
    };

    if (argc == 3) {
      /* Open fd for file to copy */
      fd_from = open(argv[2], O_RDONLY);
      /* Open fd for output */
      fd_to = creat(strcat(argv[2], ".copy"), 0644);
      /* Get file size to copy */
      if (statx(fd_from, "", AT_EMPTY_PATH, STATX_SIZE, &statxbuf)) {
        perror("statx");
        exit(1);
      };

      res = fn(fd_from, fd_to, statxbuf.stx_size);

      close(fd_from);
      close(fd_to);

      return res;
    }

    else if (argc == 5) {

      if (strcmp(argv[2], "seq") == 0) {
        return seq_traverse(argv[3], argv[4], fn);

        /* } else if (strcmp(argv[1], "sp") == 0) { */
        /*   fn = sp_cp; */

        /* } else if (strcmp(argv[1], "sf") == 0) { */
        /*   fn = sf_cp; */

        /* } else if (strcmp(argv[1], "cf") == 0) { */
        /*   fn = cf_cp; */
      } else {
        printf("Error: strategy must be one of seq\n");
        exit(1);
      };
    }
  };

  return 0;
}
