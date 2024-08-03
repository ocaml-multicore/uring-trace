#define _GNU_SOURCE

#include <assert.h>
#include <liburing.h>
#include <liburing/io_uring.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/ioctl.h>
#include <unistd.h>
#include <error.h>

#define QD 2
#define BS (16 * 1024)

struct user_data {
  enum io_uring_op opcode;
  int offset;
  int bid;
};

int setup_context(unsigned entries, struct io_uring *ring) {
  int ret;

  ret = io_uring_queue_init(entries, ring, IORING_SETUP_IOPOLL);

  if (ret)
    perror("io_uring_queue_init");

  return ret;
}

int setup_buffer_ring(struct io_uring *ring, int nr_bufs,
                      struct io_uring_buf_ring *br) {

  int ret;
  void *addr = NULL;
  struct io_uring_buf_reg reg;

  reg.ring_addr = posix_memalign(&addr, 4096, BS * nr_bufs);
  reg.ring_entries = nr_bufs;
  reg.bgid = 1;

  /* Register to ring instance */
  ret = io_uring_register_buf_ring(ring, &reg, 0);
  if (ret) {
    perror("io_uring_register_buf_ring");
    return ret;
  };

  /* Call before using the ring */
  io_uring_buf_ring_init(br);

  return 0;
}

int setup_provided_buffers(struct io_uring *ring, struct iovec *iovecs,
                           unsigned int entries) {

  for (int i = 0; i < entries; i++) {
    iovecs[i].iov_base = malloc(BS);
    iovecs[i].iov_len = BS;
  };

  if (io_uring_register_buffers(ring, iovecs, entries)) {
    perror("io_uring_register_buffers");
    exit(1);
  };

  return 0;
}

static int get_file_size(int fd, off_t *size) {
  struct stat st;

  if (fstat(fd, &st) < 0)
    return -1;
  if (S_ISREG(st.st_mode)) {
    *size = st.st_size;
    return 0;
  } else if (S_ISBLK(st.st_mode)) {
    unsigned long long bytes;
    if (ioctl(fd, BLKGETSIZE64, &bytes) != 0)
      return -1;

    *size = bytes;
    return 0;
  }
  return -1;
}

int copy_file(struct io_uring *ring, int infd, int outfd, off_t size) {

  int ret;
  int reads_left, inflight, offset, depth;
  struct io_uring_sqe *sqe;
  struct io_uring_cqe cqe;
  struct io_uring_cqe *cqe_ptr = &cqe;
  struct iovec iovecs[QD];
  struct user_data *d;
  /* struct io_uring_buf_ring br; */

  /* if (setup_buffer_ring(ring, 64, &br)) { */
  /*   perror("setup_buffer_ring"); */
  /*   exit(1); */
  /* }; */
  if (setup_provided_buffers(ring, iovecs, QD)) {
    perror("setup_provided_buffers");
    exit(1);
  };

  /* Number of reads_left to do */
  reads_left = (size / BS) + 1 ? (size % BS) : (size / BS);
  inflight = 0;

  /* Kickoff */
  for (offset = 0, depth = 0; offset < size && depth < QD;
       depth++, offset += BS, reads_left--, inflight++) {
    /* Fill user data info */
    d = (struct user_data *) malloc(sizeof(struct user_data));
    d->offset = offset;
    /* d->bid = depth; */
    d->opcode = IORING_OP_READ_FIXED;
    sqe = io_uring_get_sqe(ring);
    io_uring_sqe_set_data(sqe, d);
    void *buf = malloc(BS);
    io_uring_prep_read(sqe, infd, buf, BS, offset);
  };
  io_uring_submit(ring);

  while (reads_left || inflight) {

    ret = io_uring_peek_cqe(ring, &cqe_ptr);

    if (ret == -EAGAIN)
      continue;
    else if (ret == 0) {
      d = (struct user_data *) io_uring_cqe_get_data(cqe_ptr);
      switch (d->opcode) {

      case IORING_OP_READ_FIXED:

	if (cqe_ptr->res < 0){
	  error(cqe_ptr->res, -(cqe_ptr->res), "Something went wrong, got %d\n", cqe_ptr->res);
	  exit(1);
	};
        /* Get new SQE */
        sqe = io_uring_get_sqe(ring);
        assert(sqe != NULL);
	/* Reuse user data object */
	d->opcode = IORING_OP_WRITE_FIXED;
	io_uring_sqe_set_data(sqe, d);
        /* Submit corresponding write */
        io_uring_prep_write_fixed(sqe, outfd, iovecs[d->bid].iov_base, cqe_ptr->res,
                                  d->offset, d->bid);
        inflight++;
        break;

      case IORING_OP_WRITE_FIXED:

        assert(cqe_ptr->res >= 0);
        /* Get new SQE */
        sqe = io_uring_get_sqe(ring);
        assert(sqe != NULL);
        if (reads_left) {
	  /* Reuse user data object */
	  d->opcode = IORING_OP_WRITE_FIXED;
	  io_uring_sqe_set_data(sqe, d);
          /* Submit next read, reusing buffer */
          io_uring_prep_read_fixed(sqe, infd, iovecs[d->bid].iov_base, BS,
                                   offset, d->bid);
        } else {
          /* Nothing to do */
          inflight--;
	  /* Free user data */
	  free(d);
        }
        break;

      default:
        /* Shouldn't reach here */
        printf("Shouldn't reach here\n");
        exit(1);
      };
      /* Free up cqe_ptr */
      io_uring_cqe_seen(ring, cqe_ptr);
    } else {
      printf("not sure what to do here");
      exit(1);
    };
  };

  return 0;
};

int main(int argc, char *argv[]) {
  struct io_uring ring;
  off_t insize;
  int ret;
  int infd, outfd;

  if (argc < 3) {
    printf("Usage: %s <infile> <outfile>\n", argv[0]);
    return 1;
  }

  infd = open(argv[1], O_RDONLY | O_DIRECT);
  if (infd < 0) {
    perror("open infile");
    return 1;
  }

  outfd = open(argv[2], O_WRONLY | O_CREAT | O_TRUNC | O_DIRECT, 0644);
  if (outfd < 0) {
    perror("open outfile");
    return 1;
  }

  if (setup_context(QD, &ring))
    return 1;

  if (get_file_size(infd, &insize))
    return 1;

  ret = copy_file(&ring, infd, outfd, insize);

  close(infd);
  close(outfd);
  io_uring_queue_exit(&ring);
  return ret;
}
