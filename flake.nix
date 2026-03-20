{
  description = "tmux-aws - tmux plugin for AWS profile management";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          name = "tmux-aws";
          packages = with pkgs; [
            bash
            tmux
            awscli2
            aws-vault
            fzf
            bats
          ];
        };
      });
}
