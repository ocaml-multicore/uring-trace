# SPDX-License-Identifier: (LGPL-2.1 OR BSD-2-Clause)
OUTPUT := output
CLANG ?= clang
LLVM_STRIP ?= llvm-strip
BPFTOOL ?= /usr/sbin/bpftool
CFLAGS := -g -Wall -fPIC
ARCH := $(shell uname -m)
ARCH_SHORTHAND ?= $(shell uname -m | sed 's/x86_64/x86/' \
				| sed 's/arm.*/arm/' \
				| sed 's/aarch64/arm64/' \
				| sed 's/ppc64le/powerpc/' \
				| sed 's/mips.*/mips/' \
				| sed 's/riscv64/riscv/' \
				| sed 's/loongarch64/loongarch/')
# Kernel version
MAJOR_VERSION := $(shell uname -r | sed -E 's/^([0-9]+).*/\1/')
MINOR_VERSION := $(shell uname -r | sed -E 's/^[0-9]+\.([0-9]+)\..*/\1/')
VMLINUX := ./vmlinux.h
INCLUDES := -I$(OUTPUT) -I/usr/include/$(ARCH)-linux-gnu/

BINS = size
PROBES = uring

ifeq ($(V),1)
	Q =
	msg =
else
	Q = @
	msg = @printf '  %-8s %s%s\n'					\
		      "$(1)"						\
		      "$(patsubst $(abspath $(OUTPUT))/%,%,$(2))"	\
		      "$(if $(3), $(3))";
	MAKEFLAGS += --no-print-directory
endif

.PHONY: all

all: $(addprefix $(OUTPUT)/,$(addsuffix .skel.h,$(PROBES))) $(addprefix $(OUTPUT)/,$(addsuffix .bpf.o,$(PROBES))) $(addprefix $(OUTPUT)/,$(BINS))

.PHONY: clean
clean:
	$(call msg,CLEAN)
	$(Q)rm -rf $(OUTPUT)

$(OUTPUT):
	$(call msg,MKDIR,$@)
	$(Q)mkdir -p $@

# Generate BPF skeletons
$(OUTPUT)/%.skel.h: $(OUTPUT)/%.bpf.o | $(OUTPUT)
	$(call msg,GEN-SKEL,$@)
	$(Q)$(BPFTOOL) gen skeleton $< > $@

# Build BPF code
$(OUTPUT)/%.bpf.o: %.bpf.c $(LIBBPF_OBJ) $(VMLINUX) | $(OUTPUT)
	$(call msg,BPF,$@)
	$(Q)$(CLANG) -g -O2 -target bpf \
		-D__TARGET_ARCH_$(ARCH_SHORTHAND) \
		-DMAJOR_VERSION=$(MAJOR_VERSION)  \
		-DMINOR_VERSION=$(MINOR_VERSION)  \
		     $(INCLUDES) -c $(filter %.c,$^) -o $@
	# $(Q)$(LLVM_STRIP) -g $@

$(VMLINUX):
	/sbin/bpftool btf dump file /sys/kernel/btf/vmlinux format c > $(VMLINUX)
	cat $(VMLINUX) | grep 'trace_event_raw_io_uring' -A 10
	uname -r

# delete failed targets
.DELETE_ON_ERROR:

# keep intermediate (.skel.h, .bpf.o, etc) targets
.SECONDARY:

$(OUTPUT)/% : %.c
	$(call msg,BINS,$@)
	$(Q)$(CLANG) -g -O2 -o $@ $^
