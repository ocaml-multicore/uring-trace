#define _GNU_SOURCE

#include <errno.h>
#include <fcntl.h>
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
