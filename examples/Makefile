SHELL := /bin/bash
BIGFILE=1gb.file
SMALLFILE=20kb.file
CP=../_build/default/examples/cp.exe


$(BIGFILE):
	fallocate -l 1Gb $@

$(SMALLFILE):
	fallocate -l 20Kb $@

build:
	dune build .

cat_c:
	gcc -Wall -Werror -O2 cat.c -luring -o cat.exe

run: $(BIGFILE) build
	time $(CP) reg $< 4096
	time $(CP) chan $< 4096
	time cat_c $< 1gb.file.copy
	time $(CP) uring $< 4096
	time $(CP) uring_vec $< 4096
	time $(CP) uring_vec_fast $< 4096

trace: $(SMALLFILE) build
	$(CP) uring $< 4096
	$(CP) uring_vec $< 4096
	$(CP) uring_vec_fast $< 4096
