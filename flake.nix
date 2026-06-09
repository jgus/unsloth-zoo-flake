{
  description = "unsloth-zoo: utils for Unsloth, version-bumped ahead of nixpkgs via an overlay over the nixpkgs python3Packages.unsloth-zoo derivation.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    flake-lib = {
      url = "github:jgus/flake-lib/v1";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
  };

  outputs = { self, nixpkgs, flake-utils, flake-lib }:
    let
      pin = import ./pin.nix;
      inherit (pin) version hash;
      source = { type = "pypi"; pname = "unsloth_zoo"; format = "sdist"; };

      # Bump via pythonPackagesExtensions, not packageOverrides: consumers (unsloth-studio) resolve deps through the interpreter self-reference `python.pkgs`, which only reflects extensions, not packageOverrides. Reuse nixpkgs' curated derivation (deps, pythonRelaxDeps) and change only version + src; cuda config flows through nixpkgs' torch/triton/torchao unchanged.
      overlay = final: prev: {
        pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
          (pyfinal: pyprev: {
            unsloth-zoo = pyprev.unsloth-zoo.overridePythonAttrs (prevAttrs: {
              inherit version;
              src = pyfinal.fetchPypi {
                pname = "unsloth_zoo";
                inherit version hash;
              };
              # nixpkgs' dont-require-unsloth.patch is pinned to an older __init__.py and no longer applies. Reapply its intent — drop the import-time guards that abort without unsloth, which would otherwise deadlock the unsloth <-> unsloth-zoo build cycle — as line-robust substitutions.
              patches = [ ];
              postPatch = (prevAttrs.postPatch or "") + ''
                substituteInPlace unsloth_zoo/__init__.py \
                  --replace-fail 'if find_spec("unsloth") is None:' 'if False:' \
                  --replace-fail 'if not ("UNSLOTH_IS_PRESENT" in os.environ):' 'if False:'
              '';
            });
          })
        ];
      };
    in
    flake-utils.lib.eachDefaultSystem
      (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
            overlays = [ overlay ];
          };
        in
        {
          packages = {
            unsloth-zoo = pkgs.python3.pkgs.unsloth-zoo;
            default = pkgs.python3.pkgs.unsloth-zoo;
            update-version = flake-lib.lib.mkUpdateVersion {
              inherit pkgs source;
              buildAttr = "unsloth-zoo";
            };
            update-branches = flake-lib.lib.mkUpdateBranches {
              inherit pkgs source;
              pinSchema = "pypi";
            };
          };
        }) // {
      overlays.default = overlay;
    };
}
