# TLDR
- Increasing the default block/buffer sizes in eio/uring provides a
  generic improvement for file IO. It reduces syscall usage when
  read/writing large files and additionally reduces how often we get
  into the slow io-uring path (write requests on regular files are
  always punted to async worker... only XFS supports inline
  completion).

- Programs using eio benefit from structured, direct-style concurrency
  interface with implicit batching of asynchronous IO requests (under
  io-uring backend). For workloads that are expensive from a syscall
  perspective, using eio can transparently perform better without
  requiring users to think about batching.

# Introduction
The performance of disk IO under Linux is typically quite reasonable
because of kernel support for buffering requests. However, the
structure of some programs inherently introduce significant overhead
because of frequent context switching from high syscall
usage. IO-uring async interface tries to solve this by providing a way
to batch submissions of requests to the kernel. However,
structuring/restructuring programs to do explicit batching is
cumbersome and complex. eio make batching implicit with it's
underlying scheduler. Users can write high-level concurrent code and
transparently get syscall batching for free.

## Definitions
**IOPS**: Number of operations per second (!! Says nothing about the size of these operations)
**IO size**: The per request size of an operation
**Throughput**: IOPS x IO size
**Latency**: Time taken to complete a single operation
**Workload request percentage**: The breakdown of number of Reads/Writes/Deletions for a particular workload

**IO batching**: File IO is batched/buffered by the kernel as an
optimization. The kernel implicitly performs readahead optimization to
saturate the read requests so that they can already make it into the
page cache before being requested. Writes are also saturated because
the kernel buffers them to be flushed at a later time.

**Sscall batching**: Using io-uring to batch syscall requests to the
kernel, requiring only 1 context switch

> Disk performance expectations is highly variable depending on
> workload, see this link for a good breakdown on performance metrics
> for SSD's [SSD speed
> measurement](https://ssd.userbenchmark.com/Faq/What-is-the-effective-SSD-speed-index/42)

# Disk Benchmarks

## User benchmarks (2171 samples) for my SSD  INTEL (SSDPEKKF512G7L)
1QD Seq Read: 782Mb/s
1QD Seq Write: 519Mb/s
1QD Seq Mixed: 585Mb/s

1QD Random 4k Read: 29.1Mb/s
1QD Random 4k Write: 107Mb/s
1QD Random 4k Mixed: 42.8Mb/s

64QD Random 4k Read: 479Mb/s
64QD Random 4k Write: 463Mb/s
64QD Random 4k Mixed: 425Mb/s

[My results](bench.results)

## Evaluation
Best performance of raw IO against SSD hinges being able to saturate
disk.  The saturation point is reached when requests hit the maximum
IO size which is equivalent to (maximum sector size) and then start to
form a queue of pending requests. Sequential IO hits this case since
it is just streaming a while block of IO requests to disk. The 1QD
Random 4k read doesn't happen because of IO buffering by the kernel.

Copying one or a few **small/big** file(s): The most efficient way is
to just perform a sequential read and write with the maximum block
size. Even better, on Linux, we use copy\_file\_range API which
performs an in-kernel copy of the entire file with a single
syscall. Even if there are multiple files, the program is still
IO-bound since CPU work (syscall overhead) in contrast to IO is small
& negligible.

Copying **many small/large files**: With many files and directories,
the workload fundamentally changes from being totally IO-bound to
start experiencing pressure from context switching since it's doing
much more syscalls during traversal. Batched requests under IO-uring
can help minimize this cost with batch submission of syscalls.

# Other Notes
## Lifting IO batching into userspace.
High performance storage IO solutions typically suggest using async IO
with O\_DIRECT flag on files to skip the kernel page cache and write
their own internal caching mechanism instead. Essentially this _lifts_
the IO batching responsibility into user space. This is a rather
involved design but eio could potentially support this.

## TODO
- write a naive read/write copy strategy, see how that fares.
`perf` the traversal with cp and eio_cp
