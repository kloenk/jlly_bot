{
  description = "Discord bot for escapetheaverage";

  inputs.flake-compat = {
    url = "github:edolstra/flake-compat";
    flake = false;
  };

  outputs = { self, nixpkgs, ... }:
    let
      version = "${nixpkgs.lib.substring 0 8 self.lastModifiedDate}-${
          self.shortRev or "dirty"
        }";

      systems =
        [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];

      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system);

      # Memoize nixpkgs for different platforms for efficiency.
      nixpkgsFor = forAllSystems (system:
        import nixpkgs {
          inherit system;
          overlays = [ self.overlays.default ];
        });
    in {
      overlays.jlly = final: prev: {
        jlly_bot = final.callPackage ({ beam, rebar3 }:
          let
            packages = beam.packagesWith beam.interpreters.erlang;
            pname = "jlly_bot";
            src = self;
            mixEnv = "prod";
            mixDeps = packages.fetchMixDeps {
              pname = "mix-deps-${pname}";
              inherit src mixEnv version;
              sha256 = "sha256-aF16VFfDHHV9YTP6wtH4qmvmNdDmte6MSgqXGbJPgME=";
            };
          in packages.mixRelease {
            inherit pname version src mixEnv;

            mixFodDeps = mixDeps;

            nativeBuildInputs = [ rebar3 ];
          }) { };
      };
      overlays.default = self.overlays.jlly;

      packages = forAllSystems (system: {
        inherit (nixpkgsFor.${system}) jlly_bot;
        default = self.packages.${system}.jlly_bot;
      });

      legacyPackages = forAllSystems (system: nixpkgsFor.${system});

      nixosModules = {
        jlly_bot = import ./nix/jlly.nix;
        default = self.nixosModules.jlly_bot;
      };
    };

}
