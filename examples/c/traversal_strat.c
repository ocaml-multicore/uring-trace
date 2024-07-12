#define _GNU_SOURCE

#include "cp.h"
#include <dirent.h>
#include <err.h>
#include <fcntl.h>
#include <linux/stat.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

int fcp_wrapper(char *src, char *dst, fcp_fn fn) {
  int from_fd, to_fd, res;
  struct stat statbuf;

  if ((from_fd = open(src, O_RDONLY) < 0)) {
    perror("open");
    exit(1);
  }

  /* Something weird going on here, fstat gives zero size */
  if (fstatat(AT_FDCWD, src, &statbuf, 0) == -1) {
    perror("stat");
    exit(1);
  };

  if ((to_fd = creat(dst, statbuf.st_mode)) < 0) {
    perror("creat");
    exit(1);
  };

  /* Not sure why it's hanging here */
  res = fn(from_fd, to_fd, statbuf.st_size);

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

    if (mkdir(dst, 0700) < 0) {
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
            fcp_wrapper(src_path, dst_path, fn);
        } else if (S_ISDIR(statbuf.st_mode)) {
            printf("name of directory is %s\n", ent->d_name);
            fflush(stdout);
            seq_traverse(src_path, dst_path, fn);
        } else {
            err(1, "Not sure how to handle this type of file: %s", src_path);
        }
    }

    closedir(dir);
    return 0;
}
