#!/bin/bash

SRC=src
DST=dst
EIO_CP=../../_build/default/examples/blogpost/cp.exe

rm -rf $SRC $DST

# Setup FS & build cp.exe
dune build -- ./cp.exe
dune exec -- ../fs_gen.exe 5 5 . $SRC 4096

# Workload 1
hyperfine --warmup 5 \
          --prepare "rm -rf $DST" \
          "cp -R $SRC $DST"

hyperfine --warmup 5 \
          --prepare "rm -rf $DST" \
          "$EIO_CP $SRC $DST 4096"


# Remake FS with 1Mb files
rm -rf $SRC $DST
dune exec -- ../fs_gen.exe 5 4 . $SRC 1000000

# Workload 2
hyperfine --warmup 5 \
          --prepare "rm -rf $DST" \
          "cp -R $SRC $DST"

hyperfine --warmup 5 \
          --prepare "rm -rf $DST" \
          "$EIO_CP $SRC $DST 4096"

hyperfine --warmup 5 \
	  --prepare "rm -rf $DST" \
          "$EIO_CP $SRC $DST 1000000"

# With a cold cache
echo "Testing with cold caches"

hyperfine --warmup 5 \
          --setup "sudo -v" \
          --prepare "rm -rf $DST; sync; echo 3 | sudo tee /proc/sys/vm/drop_caches" \
          "cp -R $SRC $DST"

hyperfine --warmup 5 \
          --setup "sudo -v" \
          --prepare "rm -rf $DST; sync; echo 3 | sudo tee /proc/sys/vm/drop_caches" \
          --parameter-list blksz 4096,1000000 \
          "$EIO_CP $SRC $DST {blksz}"

rm -rf $SRC $DST

# Setup FS & build cp.exe
dune build -- ./cp.exe
dune exec -- ../fs_gen.exe 5 5 . $SRC 4096

hyperfine --warmup 5 \
          --setup "sudo -v" \
          --prepare "rm -rf $DST; sync; echo 3 | sudo tee /proc/sys/vm/drop_caches" \
          "cp -R $SRC $DST"

hyperfine --warmup 5 \
          --setup "sudo -v" \
          --prepare "rm -rf $DST; sync; echo 3 | sudo tee /proc/sys/vm/drop_caches" \
          "$EIO_CP $SRC $DST 4096"
