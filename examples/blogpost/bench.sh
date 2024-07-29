#!/bin/bash

SRC=src
DST=dst
EIO_CP=../../_build/default/examples/blogpost/cp.exe

rm -rf $SRC $DST

# Setup FS & build cp.exe
dune build -- ./cp.exe
dune exec -- ../fs_gen.exe 5 7 . $SRC 4096

# Benchmark 1
hyperfine --warmup 5 \
          --prepare "rm -rf $DST; sync" \
	  --export-json cp_r_4k.json \
          "cp -r $SRC $DST"

hyperfine --warmup 5 \
          --prepare "rm -rf $DST; sync" \
	  --export-json eio_cp_4k.json \
          "$EIO_CP $SRC $DST"

hyperfine --warmup 5 \
	  --setup "sudo -v" \
	  --prepare "rm -rf $DST; sync; echo 3 | sudo tee /proc/sys/vm/drop_caches" \
	  --export-json cp_r_4k_fsync+cold.json \
          "cp -r $SRC $DST; sync"

hyperfine --warmup 5 \
	  --setup "sudo -v" \
	  --prepare "rm -rf $DST; sync; echo 3 | sudo tee /proc/sys/vm/drop_caches" \
	  --export-json eio_cp_4k_fsync+cold.json \
          "$EIO_CP $SRC $DST; sync"

# # Remake FS with 1Mb files
# rm -rf $SRC $DST
# dune exec -- ../fs_gen.exe 5 4 . $SRC 1000000

# # Benchmark 2
# hyperfine --warmup 5 \
#           --prepare "rm -rf $DST; sync" \
# 	  --export-json cp_r_1mb.json \
# 	  --show-output \
#           "cp -R $SRC $DST"

# hyperfine --warmup 5 \
#           --prepare "rm -rf $DST; sync" \
# 	  --export-json eio_cp_1mb.json \
#           "$EIO_CP $SRC $DST"

# hyperfine --warmup 5 \
# 	  --setup "sudo -v" \
# 	  --prepare "rm -rf $DST; sync; echo 3 | sudo tee /proc/sys/vm/drop_caches" \
# 	  --export-json cp_r_1mb_fsync+cold.json \
#           "cp -r $SRC $DST; sync"

# hyperfine --warmup 5 \
# 	  --setup "sudo -v" \
# 	  --prepare "rm -rf $DST; sync; echo 3 | sudo tee /proc/sys/vm/drop_caches" \
# 	  --export-json eio_cp_1mb_fsync+cold.json \
#           "$EIO_CP $SRC $DST; sync"

# # Benchmark 3
# hyperfine --warmup 5 \
# 	  --prepare "rm -rf $DST; sync" \
# 	  --export-json eio_cp_1mb_var_blksz.json \
# 	  --parameter-list blksz 4096,16384,65536,262144,1048576 \
#           "$EIO_CP $SRC $DST {blksz}"
