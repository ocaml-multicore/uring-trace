# SPDX-License-Identifier: (LGPL-2.1 OR BSD-2-Clause)
OUTPUT := output
CLANG ?= clang
LLVM_STRIP ?= llvm-strip
BPFTOOL ?= /usr/sbin/bpftool
CFLAGS := -g -Wall -fPIC
ARCH := $(shell uname -m | sed 's/x86_64/x86/')
VMLINUX := ./vmlinux.h
INCLUDES := -I$(OUTPUT) -I/usr/include/x86_64-linux-gnu/ -I$(dir $(VMLINUX))

PROBES = uring
BINS = size

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
	$(Q)$(CLANG) -g -O2 -target bpf -D__TARGET_ARCH_$(ARCH)		      \
		     $(INCLUDES) -c $(filter %.c,$^) -o $@
	# $(Q)$(LLVM_STRIP) -g $@

$(VMLINUX):
	sudo bpftool btf dump file /sys/kernel/btf/vmlinux format c > $(VMLINUX)

# delete failed targets
.DELETE_ON_ERROR:

# keep intermediate (.skel.h, .bpf.o, etc) targets
.SECONDARY:

$(OUTPUT)/% : %.c
	$(call msg,BINS,$@)
	$(Q)$(CLANG) -g -O2 -o $@ $^
