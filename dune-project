(lang dune 3.13)
(using dune_site 0.1)

(name uring-trace)
(source
 (github koonwen/uring-trace))
(authors "Lee Koon Wen")
(maintainers "koonwen@gmail.com")
(license ISC BSD-3-Clause)
(documentation https://github.com/koonwen/uring-trace)

(package
 (name conf-liburing)
 (allow_empty)
 (synopsis "Virtual package for system installation of liburing")
 (depends))

(package
 (name uring-trace)
 (sites
  (share bpf))
 (synopsis "IO-uring tracing tool using eBPF probes")
 (depends
  (ppx_deriving
   (>= 6.0.2))
  (eio
   (>= 1.1))
  ocaml
  dune
  dune-site
  (cmdliner
   (>= 1.1.0))
  eio_linux
  libbpf
  libbpf_maps
  (lwt (and :with-test))
  (logs (and :with-test))
  (fmt (and :with-test))
  conf-liburing
  conf-bpftool
  ctypes))
