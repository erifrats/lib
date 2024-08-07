{
  core-inputs,
  user-inputs,
  starfire-lib,
  starfire-config,
}: let
  inherit (builtins) baseNameOf elem;
  inherit (core-inputs.nixpkgs.lib) foldl mapAttrs hasPrefix hasSuffix isFunction splitString tail singleton;

  user-modules-root = starfire-lib.fs.get-starfire-file "modules";
in {
  module = rec {
    ## Create flake output modules.
    ## Example Usage:
    ## ```nix
    ## create-modules { src = ./my-modules; overrides = { inherit another-module; }; alias = { default = "another-module" }; }
    ## ```
    ## Result:
    ## ```nix
    ## { another-module = ...; my-module = ...; default = ...; }
    ## ```
    #@ Attrs -> Attrs
    create-modules = {
      src ? "${user-modules-root}/nixos",
      overrides ? {},
      alias ? {},
    }: let
      user-modules = starfire-lib.fs.get-default-nix-files-recursive src;
      create-module-metadata = module: {
        name = let
          path-name = builtins.replaceStrings [(builtins.toString src) "/default.nix"] ["" ""] (builtins.unsafeDiscardStringContext module);
        in
          if hasPrefix "/" path-name
          then builtins.substring 1 ((builtins.stringLength path-name) - 1) path-name
          else path-name;
        path = module;
      };
      modules-metadata = builtins.map create-module-metadata user-modules;
      merge-modules = modules: metadata:
        modules
        // {
          # NOTE: home-manager *requires* modules to specify named arguments or it will not
          # pass values in. For this reason we must specify things like `pkgs` as a named attribute.
          ${metadata.name} = args @ {pkgs, ...}: let
            system = args.system or args.pkgs.system;
            target = args.target or system;

            format = let
              virtual-system-type = starfire-lib.system.get-virtual-system-type target;
            in
              if virtual-system-type != ""
              then virtual-system-type
              else if starfire-lib.system.is-darwin target
              then "darwin"
              else "linux";

            # Replicates the specialArgs from Starfire Lib's system builder.
            modified-args =
              args
              // {
                inherit system target format;
                virtual = args.virtual or (starfire-lib.system.get-virtual-system-type target != "");
                systems = args.systems or {};

                lib = starfire-lib.internal.system-lib;
                pkgs = user-inputs.self.pkgs.${system}.nixpkgs;

                inputs = starfire-lib.flake.without-src user-inputs;
                namespace = starfire-config.namespace;
              };
            imported-user-module = import metadata.path;
            user-module =
              if isFunction imported-user-module
              then imported-user-module modified-args
              else imported-user-module;
          in
            user-module // {_file = metadata.path;};
        };
      modules-without-aliases = foldl merge-modules {} modules-metadata;
      aliased-modules = mapAttrs (name: value: modules-without-aliases.${value}) alias;
      modules = modules-without-aliases // aliased-modules // overrides;
    in
      modules;

    # Recursively and contextually fetch all modules in the given path.
    # If a directory contains no default.nix, it will return all Nix files.
    # If it contains a default.nix, it will return its path.
    get-modules = src:
      (
        let
          entries = starfire-lib.fs.get-nix-files src;
          default = "${src}/default.nix";
        in
          if elem default entries
          then singleton default
          else entries
      )
      ++ foldl (
        mods: path:
          mods ++ get-modules path
      ) [] (starfire-lib.fs.get-directories src);

    get-modules' = src:
      foldl (mods: path:
        mods
        ++ (
          if hasPrefix "${user-modules-root}/home" path
          then []
          else singleton path
        ))
      []
      (get-modules src);
  };
}
