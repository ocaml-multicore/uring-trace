CC = gcc
CFLAGS = -Wall -Werror -g
OBJS = cp.o cp_strat.o traversal_strat.o
BINS = cp
LIBS = -luring
RES_DIR = ../results

all: cp.exe

%.o : %.c
	$(CC) $(CFLAGS) -c $^

cp.exe: $(OBJS)
	$(CC) $(CFLAGS) $^ -o $@ $(LIBS)

text.file:
	echo "Hello\nSuccessful\nCopy" > $@

4kb.file:
	dd if=/dev/random of=$@ bs=4096 count=1

1gb.file:
	fallocate -l 1G $@

# with 1kb file size
big_dir:
	dune exec -- ../fs_gen.exe 5 5 . $@ 4096

# with 1Mb file size
big_dir_big_files:
	dune exec -- ../fs_gen.exe 5 5 . big_dir 1000000

# For validation purposes
small_dir:
	dune exec -- ../fs_gen.exe 2 2 . $@

validate: cp.exe cp.c text.file
	for cp_strat in rw sp sf cf; do	./$< $$cp_strat cp.c && ./$< $$cp_strat text.file && diff cp.c cp.c.copy && diff text.file text.file.copy; done

bench_c_api: cp.exe 1gb.file
	hyperfine --warmup 5 \
		  --prepare "echo 3 | sudo tee /proc/sys/vm/drop_caches; rm -f 1gb.file.copy" \
		  --export-json=$(RES_DIR)/cp_api_uncached.json \
		  --parameter-list strategy rw,sp,sf,cf \
		  './$< {strategy} 1gb.file'

bench_cp_r_baseline: big_dir
	hyperfine --warmup 5 \
		  --prepare 'rm -rf big_dir.copy' \
		  'cp -R big_dir big_dir.copy'

bench_eio_cp_r: big_dir
ifeq ($(NO_RECOMPILE),1)
	#"No recompile done"
else
	opam upgrade --working-dir eio_linux -y
endif
	dune build -- ../cp.exe
	hyperfine --warmup 5 \
		--prepare 'rm -rf big_dir.copy' \
		--parameter-list algo kw,kentookura \
		'../../_build/default/examples/cp.exe big_dir big_dir.copy {algo}'

clean:
	rm -rf $(BINS).exe *.copy *.file *.data *.data.old *_dir $(OBJS)
