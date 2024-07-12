CC = gcc
CFLAGS = -Wall -Werror -g -O2
OBJS = traversal_strat cp_strat
BINS = cp

all: cp.exe

cp_strat.o: cp_strat.c
	$(CC) $(CFLAGS) $< -c $@

traversal_strat.o: traversal_strat.c
	$(CC) $(CFLAGS) $< -c $@

cp.exe: cp.c traversal_strat.o cp_strat.o
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

# validate: cp.exe
# 	# Probably write this as a loop

bench: cp.exe 1gb.file 4kb.file
	sudo -v
	# --prepare 'sync; echo 3 | sudo tee /proc/sys/vm/drop_caches'
	hyperfine --warmup 5 \
		  --parameter-list strategy rw,sp,sf,cf \
		  './$< {strategy} 1gb.file'

rw: cp.exe text.file
	./$< rw cp.c
	./$< rw text.file
	diff cp.c cp.c.copy
	diff text.file text.file.copy

sp: cp.exe text.file
	./$< sp cp.c
	./$< sp text.file
	diff cp.c cp.c.copy
	diff text.file text.file.copy

sf: cp.exe text.file
	./$< sf cp.c
	./$< sf text.file
	diff cp.c cp.c.copy
	diff text.file text.file.copy

cf: cp.exe text.file
	./$< cf cp.c
	./$< cf text.file
	diff cp.c cp.c.copy
	diff text.file text.file.copy


clean:
	rm -rf $(BINS).exe *.copy *.file *.data *.data.old *_dir
