CC := gcc
CFLAGS := -Wall -Werror -g
SHELL := /bin/bash
BIGFILE=1gb.file
SMALLFILE=20kb.file
CP=../_build/default/examples/cp.exe
URCP=../_build/default/examples/lib/urcp.exe

$(BIGFILE):
	fallocate -l 1Gb $@

$(SMALLFILE):
	fallocate -l 20Kb $@

build:
	dune build .

cp_c.exe: cp_c.c
	gcc -Wall -Werror -O2 $^ -luring -o $@

test.exe: test.c
	$(CC) $(CFLAGS) $^ -luring -o $@

bench: $(BIGFILE) build cp_c.exe
	# time $(CP) reg $< 4096
	# time $(CP) chan $< 4096
	# time $(CP) uring $< 4096
	# time $(CP) uring_vec $< 4096
	# time $(CP) uring_vec_fast $< 4096
	time cp $(BIGFILE) $(BIGFILE).copy
	time ./cp_c.exe $(BIGFILE) $(BIGFILE).copy
	time $(URCP) $(BIGFILE) $(BIGFILE).copy
	time $(URCP) --fixed $(BIGFILE) $(BIGFILE).copy
	# time $(URCP) --block-size=4096 --queue-depth=1 $(BIGFILE) $(BIGFILE).copy
	# time $(URCP) --block-size=4096 --queue-depth=64 $(BIGFILE) $(BIGFILE).copy
	# time $(URCP) --block-size=4096 --queue-depth=64 --fixed $(BIGFILE) $(BIGFILE).copy
	# time $(URCP) --block-size=4096 --queue-depth=64 --fixed --polling-timeout=100 $(BIGFILE) $(BIGFILE).copy


trace: $(SMALLFILE) build
	# $(CP) uring $< 4096
	# $(CP) uring_vec $< 4096
	# $(CP) uring_vec_fast $< 4096
	# $(URCP) --block-size=4096 --queue-depth=1 $(SMALLFILE) $(SMALLFILE).copy
	# $(URCP) --block-size=4096 --queue-depth=64 $(SMALLFILE) $(SMALLFILE).copy
	# $(URCP) --block-size=4096 --queue-depth=64 --fixed $(SMALLFILE) $(SMALLFILE).copy
	# $(URCP) --block-size=4096 --queue-depth=64 --fixed --polling-timeout=100 $(SMALLFILE) $(SMALLFILE).copy
	$(URCP) $(SMALLFILE) $(SMALLFILE).copy
	$(URCP) --fixed $(SMALLFILE) $(SMALLFILE).copy


clean:
	rm -rf *.exe *.file*
