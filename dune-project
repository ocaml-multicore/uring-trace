(lang dune 3.13)

(generate_opam_files true)

(name uring-trace)
(source
 (github koonwen/uring-trace))
(authors "Lee Koonwen")
(maintainers "Lee Koonwen")
(documentation "https://github.com/koonwen/uring-trace")

(package
 (name conf-liburing)
 (allow_empty)
 (synopsis "Virtual package for system installation of liburing"))

(package
 (name uring-trace)
 (synopsis "IO-uring tracing tool using eBPF probes")
 (depends ocaml dune eio_linux libbpf libbpf_maps conf-liburing conf-bpftool ctypes))

; See the complete stanza docs at https://dune.readthedocs.io/en/stable/dune-files.html#dune-project
