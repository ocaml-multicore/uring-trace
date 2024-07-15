CC = gcc
CFLAGS = -Wall -Werror -g
OBJS = traversal_strat.o cp_strat.o cp.o
BINS = cp

all: cp.exe

%.o : %.c
	$(CC) $(CFLAGS) -c $^

cp.exe: $(OBJS)
	$(CC) $(CFLAGS) $^ -o $@

text.file:
	echo "Hello\nSuccessful\nCopy" > $@

4kb.file:
	dd if=/dev/random of=$@ bs=4096 count=1

1gb.file:
	fallocate -l 1G $@

big_dir:
	# 1kb file size
	dune exec -- ../fs_gen.exe 5 5 . $@ 4096

big_dir_big_files:
	# 5Mb file size
	dune exec -- ../fs_gen.exe 5 5 . big_dir 1000000

small_dir:
	dune exec -- ../fs_gen.exe 2 2 . $@

validate: cp.exe cp.c text.file
	for cp_strat in rw sp sf cf; do	./$< $$cp_strat cp.c && ./$< $$cp_strat text.file && diff cp.c cp.c.copy && diff text.file text.file.copy; done

bench: cp.exe 1gb.file 4kb.file
	# sudo -v
	# --prepare 'sync; echo 3 | sudo tee /proc/sys/vm/drop_caches'
	hyperfine --warmup 5 \
		  --export-json=res.json \
		  --parameter-list strategy rw,sp,sf,cf \
		  './$< {strategy} 1gb.file'

seq_rw: cp.exe small_dir
	rm -rf small_dir.copy
	./$< rw seq small_dir small_dir.copy


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

bench_c_cp_r: cp.exe big_dir
	hyperfine --warmup 5 \
		--prepare 'rm -rf big_dir.copy' \
		--parameter-list strategy rw,sp,sf,cf \
		'./$< {strategy} seq big_dir big_dir.copy'

bench_cp_r_baseline: big_dir
	hyperfine --warmup 5 \
		  --prepare 'rm -rf big_dir.copy' \
		  'cp -R big_dir big_dir.copy'

clean:
	rm -rf $(BINS).exe *.copy *.file *.data *.data.old *_dir $(OBJS)
