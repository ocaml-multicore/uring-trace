#!/bin/bash

SRC=src
DST=dst
EIO_CP=../../_build/default/examples/blogpost/cp.exe

# Setup FS & build cp.exe
dune build -- ./cp.exe
dune exec -- ../fs_gen.exe 5 5 . $SRC 4096

# Benchmark 1
hyperfine --warmup 5 \
          --prepare "rm -rf $DST" \
          "cp -R $SRC $DST"

hyperfine --warmup 5 \
          --prepare "rm -rf $DST" \
          "$EIO_CP $SRC $DST 4096"

# Remake FS with 1Mb files
rm -rf $SRC $DST
dune exec -- ../fs_gen.exe 5 5 . $SRC 1000000

# Benchmark 2
hyperfine --warmup 5 \
          --prepare "rm -rf $DST" \
          "cp -R $SRC $DST"

hyperfine --warmup 5 \
          --prepare "rm -rf $DST" \
          "$EIO_CP $SRC $DST 4096"


hyperfine --warmup 5 \
          --prepare "rm -rf $DST" \
          "$EIO_CP $SRC $DST 1000000"
