{
  description = "Starfire Lib";

  inputs = {
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };

    flake-utils = {
      url = "github:numtide/flake-utils?rev=ff7b65b44d01cf9ba6a71320833626af21126384";
      inputs.systems.follows = "systems";
    };

    flake-utils-plus = {
      url = "github:gytis-ivaskevicius/flake-utils-plus?rev=3542fe9126dc492e53ddd252bb0260fe035f2c0f";
      inputs.flake-utils.follows = "flake-utils";
    };

    nixpkgs.url = "github:nixos/nixpkgs/release-24.05";
    systems.url = "github:nix-systems/default-linux";
  };

  outputs = inputs: let
    core-inputs =
      inputs
      // {
        src = ./.;
      };

    # Create the library, extending the nixpkgs library and merging
    # libraries from other inputs to make them available like
    # `lib.flake-utils-plus.mkApp`.
    # Usage: mkLib { inherit inputs; src = ./.; }
    #   result: lib
    mkLib = import ./src core-inputs;

    # A convenience wrapper to create the library and then call `lib.mkFlake`.
    # Usage: mkFlake { inherit inputs; src = ./.; ... }
    #   result: <flake-outputs>
    mkFlake = flake-and-lib-options @ {
      inputs,
      src,
      starfire ? {},
      ...
    }: let
      lib = mkLib {
        inherit inputs src starfire;
      };
      flake-options = builtins.removeAttrs flake-and-lib-options ["inputs" "src"];
    in
      lib.mkFlake flake-options;
  in
    {
      inherit mkLib mkFlake;

      nixosModules = {
        user = ./modules/nixos/user/default.nix;
      };

      darwinModules = {
        user = ./modules/darwin/user/default.nix;
      };

      homeModules = {
        user = ./modules/home/user/default.nix;
      };

      formatter = {
        x86_64-linux = inputs.nixpkgs.legacyPackages.x86_64-linux.alejandra;
        aarch64-linux = inputs.nixpkgs.legacyPackages.aarch64-linux.alejandra;
        x86_64-darwin = inputs.nixpkgs.legacyPackages.x86_64-darwin.alejandra;
        aarch64-darwin = inputs.nixpkgs.legacyPackages.aarch64-darwin.alejandra;
      };

      starfire = rec {
        raw-config = config;

        config = {
          root = ./.;
          src = ./.;
          namespace = "starfire";
          lib-dir = "src";

          meta = {
            name = "starfire-lib";
            title = "starfire Lib";
          };
        };

        internal-lib = let
          lib = mkLib {
            src = ./.;

            inputs =
              inputs
              // {
                self = {};
              };
          };
        in
          builtins.removeAttrs
          lib.starfire
          ["internal"];
      };
    }
    // (
      inputs.flake-utils-plus.lib.eachDefaultSystem (
        system:
          with import inputs.nixpkgs {
            inherit system;
          }; {
            devShells.default = mkShell {
              packages = [nil alejandra];
            };
          }
      )
    );
}
