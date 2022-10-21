{
  description = "macos-ephemeral";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    darwin = { url = "github:LnL7/nix-darwin"; inputs.nixpkgs.follows = "nixpkgs"; };
  };

  outputs =
    { nixpkgs
    , darwin
    , ...
    }@inputs:
    {
      inputs = {
        nixpkgs = "${nixpkgs}";
        darwin = "${darwin}";
      };

      darwinConfigurations =
        let
          ephemeral = system: darwin.lib.darwinSystem {
            inherit system;
            inputs = { inherit darwin nixpkgs; };

            modules = [
              ./configuration.nix
            ];
          };
        in
        {
          arm64 = ephemeral "aarch64-darwin";
          x86_64 = ephemeral "x86_64-darwin";
        };
    };
}
