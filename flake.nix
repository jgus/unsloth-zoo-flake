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

      overlay = final: prev: {
        pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
          (_pyfinal: pyprev: {
            torchao = pyprev.torchao.overridePythonAttrs (prevAttrs:
              final.lib.optionalAttrs
                ((prevAttrs.disabled or false) && prevAttrs.version == "0.17.0")
                {
                  disabled = false;
                  patches = (prevAttrs.patches or [ ]) ++ [
                    (final.fetchpatch {
                      url = "https://github.com/pytorch/ao/commit/5e92da482ba8f2e3aa64d74fbfa7131c259b693d.patch";
                      hash = "sha256-OZKPy92Fy+09SDx4wSnGBH/4QbbRsYJOu8d/oX2NkkA=";
                    })
                  ];
                });
          })
          (pyfinal: pyprev: {
            unsloth-zoo = pyprev.unsloth-zoo.overridePythonAttrs (prevAttrs: {
              inherit version;
              src = pyfinal.fetchPypi {
                pname = "unsloth_zoo";
                inherit version hash;
              };
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
