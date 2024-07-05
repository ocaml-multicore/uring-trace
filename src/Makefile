PROJECT_ROOT=..

.PHONY=build

build:
	dune build

run: build uring.bpf.o
	sudo $(PROJECT_ROOT)/_build/default/src/main.exe
