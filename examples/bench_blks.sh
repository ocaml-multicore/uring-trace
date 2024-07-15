#!/bin/bash
SRC=src
DST=dst

eval $(opam env)
dune build .
if [ ! -d "$SRC" ];
then
    dune exec -- ./fs_gen.exe 5 7 . src 8192
fi

if [ -d "$DST" ];
then
    rm -rf $DST
fi

echo "Testing queue depth"
hyperfine \
    --command-name "cp_var_blk_size" \
    --warmup 5 \
    --prepare "rm -rf ${DST}" \
    --export-json results_blksz.json \
    --parameter-list size 4096,8192,16384,32768,65536 \
    "../_build/default/examples/bench_blks.exe ${SRC} ${DST} 256 512 ${size}"
