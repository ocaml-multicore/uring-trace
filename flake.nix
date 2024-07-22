{
  description = "Nix Flake";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.nix-filter.url = "github:numtide/nix-filter";

  outputs = { self, nixpkgs, nix-filter, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = (import nixpkgs {
          inherit system;
        });
        vmlinux = pkgs.linuxPackages_6_1.kernel.dev;
        sources = {
          ocaml = nix-filter.lib {
            root = ./.;
            include = [
              ".ocamlformat"
              "dune-project"
              (nix-filter.lib.inDirectory "src")
              (nix-filter.lib.inDirectory "fxt")
              (nix-filter.lib.inDirectory "bpf")
            ];
          };
        };
        ocaml-libbpf = with pkgs;
          ocamlPackages.buildDunePackage rec {
            pname = "libbpf";
            version = "0.1.0";

            src = fetchFromGitHub {
              owner = "koonwen";
              repo = "ocaml-libbpf";
              rev = "v${version}";
              hash = "sha256-QinduR6/4dt21zULRNBw7F+jISMSf33xA4WFatAMJZc=";
            };

            buildInputs = [
              libbpf
            ];

            minimalOCamlVersion = "4.08";

            outputs = [ "out" "dev" ];

            propagatedBuildInputs = with ocamlPackages; [
              ctypes
              ppx_deriving
              ppx_expect
              # conf-libbpf
              # conf-bpftool
              # conf-clang
            ];

            # Tests need opam-monorepo
            # doCheck = false;
            # checkInputs = [
            #   alcotest
            # ];
            #
            # buildPhase = ''
            #   dune build libbpf_maps
            # '';

            meta = ocamlPackages.mirage-runtime.meta // {
              description = "lib2";
            };
          };
        ocaml-libbpf-maps = with pkgs;
          ocamlPackages.buildDunePackage rec {
            pname = "libbpf_maps";
            version = "0.1.0";

            src = fetchFromGitHub {
              owner = "koonwen";
              repo = "ocaml-libbpf";
              rev = "v${version}";
              hash = "sha256-QinduR6/4dt21zULRNBw7F+jISMSf33xA4WFatAMJZc=";
            };

            buildInputs = [
              libbpf
            ];

            minimalOCamlVersion = "4.08";

            outputs = [ "out" "dev" ];

            propagatedBuildInputs = with ocamlPackages; [
              ocaml-libbpf
              ctypes
              ctypes-foreign
              ppx_deriving
              ppx_expect
              # conf-libbpf
              # conf-bpftool
              # conf-clang
            ];

            # Tests need opam-monorepo
            # doCheck = false;
            # checkInputs = [
            #   alcotest
            # ];
            #
            # buildPhase = ''
            #   dune build libbpf_maps
            # '';

            meta = ocamlPackages.mirage-runtime.meta // {
              description = "lib2";
            };
          };
      in with pkgs;
      {
        packages = {
          default = self.packages.${system}.uring-trace;
          uring-trace = ocamlPackages.buildDunePackage rec {
            pname = "uring-trace";
            src = sources.ocaml;
            version = "0.0.1";

            # minimalOCamlVersion = "4.08";
            outputs = [ "out" "dev" ];

            buildInputs = [
              liburing
              libbpf
              bpftool
              clang_14
            ];

            propagatedBuildInputs = with ocamlPackages; [
              eio
              # libbpf
              # libbpf_maps
              # conf-liburing
              ocaml-libbpf
              ocaml-libbpf-maps
              ctypes
              eio
              eio_linux
              ppx_deriving
            ];

            # Tests need opam-monorepo
            # doCheck = false;
            # checkInputs = [
            #   alcotest
            # ];

            # buildPhase = ''
            #   cp ${vmlinux}/vmlinux bpf/vmlinux
            #   ${pkgs.bpftool.out}/bin/bpftool btf dump file bpf/vmlinux format c > bpf/vmlinux.h
            #   export PATH=$PATH:${clang_14.out}/bin
            #   export PATH=$PATH:${bpftool.out}/bin
            #   make -C bpf
            # '';

            installPhase = ''
              runHook preInstall
              cp ${vmlinux}/vmlinux bpf/vmlinux
              ${pkgs.bpftool.out}/bin/bpftool btf dump file bpf/vmlinux format c > bpf/vmlinux.h
              export PATH=$PATH:${clang_14.out}/bin
              export PATH=$PATH:${bpftool.out}/bin
              make -C bpf
              dune install --prefix=$out --libdir=$dev/lib/ocaml/${ocaml.version}/site-lib/ ${pname}
              cp bpf/output/uring.bpf.o $out/bin
              runHook postInstall
            '';

            meta = ocamlPackages.mirage-runtime.meta // {
              description = "lib";
            };
          };
        };
      });
}
