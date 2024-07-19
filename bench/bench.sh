#!/bin/bash
FILE=1gb.file
SRC=src
DST=dst
RES_DIR=results
EIO_CP=../_build/default/bench/eio_cp.exe

# # Get test dependencies
# echo "Installing dependencies"
# opam switch create .. --deps-only
# eval $(opam env)
# dune build -- ./eio_cp.exe
# sudo apt install hyperfine fio

# echo "Writing a test big file..."
# fallocate -l 1G $FILE

# echo "Building cp.exe"
# make -C c cp.exe

# echo "Creating results directory"
# mkdir $RES_DIR

# echo "FIO expectation"
# fio --name=copy --rw=rw --io_size=2Gb \
#     --filesize=1Gb --blocksize=8192 --directory=/tmp \
#     --ioengine=sync --output=$RES_DIR/expectations.txt

# echo "Running benchmarks for C-api"
# hyperfine --warmup 5 \
# 	  --export-json "$RES_DIR/cp_api_cached.json" \
# 	  --parameter-list strategy rw,sp,sf,cf \
# 	  "./c/cp.exe {strategy} ${FILE}"

# hyperfine --warmup 5 \
#           --setup "sudo -v" \
# 	  --prepare "sync; echo 3 | sudo tee /proc/sys/vm/drop_caches" \
# 	  --export-json "$RES_DIR/cp_api_uncached.json" \
# 	  --parameter-list strategy rw,sp,sf,cf \
# 	  "./c/cp.exe {strategy} ${FILE}"

for dir_params in "5 4 1000000"
do
    set -- $dir_params
    echo "Building test directory"
    if [ -d "$SRC" ];
    then
        rm -rf $SRC
    fi
    dune exec -- ../examples/fs_gen.exe $1 $2 . ${SRC} $3

    if [ -d "$DST" ];
    then
        rm -rf $DST
    fi

    echo "Baseline Coreutils CP performance (cached)"
    hyperfine \
        --warmup 5 \
        --prepare "rm -rf ${DST}" \
        --export-json "${RES_DIR}/cp_r_cached_$3.json" \
        "cp -R ${SRC} ${DST}"

    echo "Eio CP default (cached)"
    hyperfine \
        --warmup 5 \
        --prepare "rm -rf ${DST}" \
        --export-json "${RES_DIR}/eio_cp_r_cached_$3.json" \
        "${EIO_CP} ${SRC} ${DST} $3"

    echo "Baseline Coreutils CP performance (uncached)"
    hyperfine \
        --setup "sudo -v" \
        --warmup 5 \
        --prepare "sync; echo 3 | sudo tee /proc/sys/vm/drop_caches && rm -rf ${DST}" \
        --export-json "${RES_DIR}/cp_r_uncached_$3.json" \
        "cp -R ${SRC} ${DST}"

    echo "Eio CP default (uncached)"
    hyperfine \
        --setup "sudo -v" \
        --warmup 5 \
        --prepare "sync; echo 3 | sudo tee /proc/sys/vm/drop_caches && rm -rf ${DST}" \
        --export-json "${RES_DIR}/eio_cp_r_uncached_$3.json" \
        "${EIO_CP} ${SRC} ${DST} $3"
done

rm -rf $SRC $DST $FILE ${FILE}.copy
