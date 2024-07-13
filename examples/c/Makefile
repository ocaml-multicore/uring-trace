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
	dune exec -- ../fs_gen.exe 5 7 . $@

small_dir:
	dune exec -- ../fs_gen.exe 2 2 . $@

seq_rw: cp.exe small_dir
	rm -rf small_dir.copy
	./$< rw seq small_dir small_dir.copy

validate: cp.exe cp.c text.file
	for cp_strat in rw sp sf cf; do	./$< $$cp_strat cp.c && ./$< $$cp_strat text.file && diff cp.c cp.c.copy && diff text.file text.file.copy; done

bench: cp.exe 1gb.file 4kb.file
	sudo -v
	# --prepare 'sync; echo 3 | sudo tee /proc/sys/vm/drop_caches'
	hyperfine --warmup 5 \
		  --parameter-list strategy rw,sp,sf,cf \
		  './$< {strategy} 1gb.file'

clean:
	rm -rf $(BINS).exe *.copy *.file *.data *.data.old *_dir $(OBJS)
