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
    --command-name "cp_var_depth" \
    --warmup 5 \
    --prepare "rm -rf ${DST}" \
    --export-json results_again.json \
    --parameter-list depth 1,2,4,8,16,32,64,128,256 \
    "../_build/default/examples/bench_blks.exe ${SRC} ${DST} {depth}"
