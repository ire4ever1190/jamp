{
  description = "Basic nimble application";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.zst";
  };
  outputs =
    {
      flake-utils,
      nixpkgs,
      ...
    }:

    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };
      in
      {
        devShells.default = pkgs.mkShell {
          nativeBuildInputs = with pkgs; [
            nimble
            nim
            gcc
            docker
          ];
          buildInputs = with pkgs; [ openssl ];
        };
      }
    );
}
