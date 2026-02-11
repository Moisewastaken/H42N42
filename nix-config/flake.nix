{
  description = "Latest OCaml + Eliom + Ocsigen tutorial environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11"; # for build tools
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
		defaultPackage = null;
		defaultApp = null;
		
        devShells.default = pkgs.mkShell {
          buildInputs = [
            pkgs.ocaml
			pkgs.nodejs_20
            pkgs.dune_3
			pkgs.postgresql_15
			pkgs.sqlite
            pkgs.opam
            pkgs.git
			pkgs.gmp
            pkgs.pkg-config
            pkgs.libev
            pkgs.zlib
            pkgs.curl
          ];

          shellHook = ''
            echo "Setting up latest Eliom / Ocsigen via OPAM..."

			export PKG_CONFIG_PATH="${pkgs.gmp}/lib/pkgconfig:$PKG_CONFIG_PATH"

            # Initialize opam if not done
            if [ ! -d "$HOME/.opam" ]; then
              opam init --disable-sandboxing --bare
            fi

            eval $(opam env)

            # Create a switch for OCaml 5.1 if it doesn't existopam
            if ! opam switch list | grep -q "5.1.0"; then
              opam switch create 5.1.0
            fi

            eval $(opam env)

            # Install latest Eliom and Ocsigen packages
            opam install -y eliom ocsigenserver ocsigen-start ocsipersist-sqlite ocsigen-toolkit js_of_ocaml js_of_ocaml-ppx js_of_ocaml-lwt lwt tyxml --assume-depexts
          '';
        };
      });
}
