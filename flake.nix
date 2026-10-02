# Copyright 2026 Department of Code LLC.
# SPDX-License-Identifier: AGPL-3.0-or-later

{
  description = "Minimal verified F* project template (example)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/c31cf09";
    flake-utils.url = "github:numtide/flake-utils";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    fstar = {
      # Fork of F* with the LSP server ported onto the v2026.09.20 base
      # (first stable tag shipping the Custard extractor).
      url = "github:dysinger/fstar/v2026.09.20+lsp";
      flake = false;
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      flake-utils,
      treefmt-nix,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            (
              _final: prev:
              if prev.stdenv.isDarwin && prev.stdenv.isAarch64 then
                {
                  # Skip OCaml's own testsuite on aarch64-darwin.
                  ocaml-ng = prev.ocaml-ng // {
                    ocamlPackages_5_3 = prev.ocaml-ng.ocamlPackages_5_3.overrideScope (
                      _: _: {
                        ocaml = prev.ocaml-ng.ocamlPackages_5_3.ocaml.overrideAttrs (_: {
                          checkPhase = "true";
                        });
                      }
                    );
                  };
                }
              else
                { }
            )
            (
              _final: prev:
              let
                ocamlPackages = prev.ocaml-ng.ocamlPackages_5_3;
                z3 = prev.callPackage (inputs.fstar + "/.nix/z3.nix") { };
                version = "2026.09.20+lsp";
                fstar =
                  (ocamlPackages.callPackage (inputs.fstar + "/.nix/fstar.nix") {
                    inherit version z3;
                    karamel-src = prev.emptyDirectory;
                    karamelOcamlDeps = [ ];
                    ocamlLibraryPath = "";
                  }).overrideAttrs
                    (old: {
                      nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ prev.git ];
                      # Raise the bootstrap rlimit: the default (5) makes the
                      # 4-stage F* bootstrap's FStar.Math.Fermat.binomial_theorem
                      # deterministically time out under z3 4.13.3.
                      buildPhase = ''
                        export PATH="${z3}/bin:$PATH"
                        export FSTAR_USE_KRML_EXE=1 KRML_EXE=/bin/true
                        mkdir -p karamel
                        printf 'all:\n\t@true\ninstall:\n\t@true\n' > karamel/Makefile
                        make OTHERFLAGS='--z3rlimit 20 --retry 3'
                      '';
                      installPhase = ''
                        export FSTAR_USE_KRML_EXE=1 KRML_EXE=/bin/true
                        mkdir -p karamel
                        printf 'all:\n\t@true\ninstall:\n\t@true\n' > karamel/Makefile
                        PREFIX=$out make install
                        for binary in $out/bin/*
                        do
                          wrapProgram $binary --prefix PATH ":" ${z3}/bin
                        done
                        cd $out
                        installShellCompletion --bash ${inputs.fstar + "/.completion/bash/fstar.exe.bash"}
                        installShellCompletion --fish ${inputs.fstar + "/.completion/fish/fstar.exe.fish"}
                        installShellCompletion --zsh --name _fstar.exe ${inputs.fstar + "/.completion/zsh/__fstar.exe"}
                      '';
                    });
                fstar-checked = prev.runCommand "fstar-checked" { nativeBuildInputs = [ fstar ]; } ''
                  mkdir -p $out
                  cp ${fstar}/lib/fstar/ulib.checked/*.checked $out/ 2>/dev/null || true
                  echo "checked: $(ls $out/*.checked 2>/dev/null | wc -l) files"
                '';
              in
              {
                inherit fstar fstar-checked;
                inherit ocamlPackages;
              }
            )
          ];
        };

        inherit (pkgs)
          stdenv
          fstar
          fstar-checked
          lib
          dotnet-sdk_10
          ;
        inherit (pkgs) ocamlPackages;

        _pkg = import ./default.nix {
          inherit
            fstar
            fstar-checked
            lib
            ocamlPackages
            stdenv
            ;
          dotnet = dotnet-sdk_10;
        };

        treefmtModule = treefmt-nix.lib.evalModule pkgs ./treefmt.nix;

      in
      {
        formatter = treefmtModule.config.build.wrapper;

        checks.formatting = treefmtModule.config.build.check self;

        # The build targets are named by deliverable (no `example-`
        # prefix), mirroring codec exactly: `default` aliases `native`
        # (the C11 shared/static lib), plus `checked`/`ocaml`/`fsharp`.
        # `cli` is the one template-only addition (codec has no CLI).
        # Note `native` IS `checked`+`ocaml`+`fsharp`'s sibling; the four
        # library targets are exactly codec's set.
        packages.default = _pkg.native;
        packages.checked = _pkg.checked;
        packages.ocaml = _pkg.ocaml;
        packages.native = _pkg.native;
        packages.fsharp = _pkg.fsharp;
        packages.cli = _pkg.cli;

        apps = {
          default = flake-utils.lib.mkApp { drv = self.packages.${system}.cli; };
          cli = flake-utils.lib.mkApp { drv = self.packages.${system}.cli; };
        };

        devShells.default = pkgs.mkShell {
          dontDetectOcamlConflicts = true;
          shellHook = ''
            export FSTAR_CHECKED="${fstar-checked}"
          '';
          buildInputs = with pkgs; [
            fstar
            dotnet-sdk_10
            git
            ocaml
            ocamlPackages.ocaml-lsp
          ];
        };
      }
    )
    // {
      # Nix flake template (`nix flake init -t .`).  The path is the repository
      # root: `init` copies flake.nix, default.nix, Makefile, src/ directly.
      templates.default = {
        path = ./.;
        description = "Minimal verified F* project: Custard C/OCaml extraction + a packaged CLI";
        welcomeText = ''
          # F* verified project template

          A verified F* library (pure spec + Pulse leaf) extracted to C and
          OCaml via Custard, plus a packaged command-line executable.

          Create a new project (see README):

          1. nix flake init -t github:dysinger/fstar-nix-flake-template
          2. rename the example modules + edit `pname` (see "Renaming" in README)
          3. nix build

          - Build everything: nix build \
              .#checked .#ocaml .#native .#fsharp .#cli
          - Dev loop:   nix develop && make check
          - Run the CLI: nix run .#cli
        '';
      };
    };
}
