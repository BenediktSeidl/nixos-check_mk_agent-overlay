{
  description = "check_mk agent";
  inputs.nixpkgs.url = "nixpkgs/nixos-unstable";
  inputs.checkmk = {
    url = "github:tribe29/checkmk/2.2.0";
    flake = false;
  };

  outputs = { self, nixpkgs, checkmk }:
    (
      let
        supportedSystems = [ "x86_64-linux" ];
        forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
        pkgs = forAllSystems (system: nixpkgs.legacyPackages.${system});
        pkg = withCallPackage: withCallPackage.callPackage ./pkgs/check_mk_agent {
          cmkaSrc = checkmk;
          cmkaVersion = checkmk.lastModifiedDate;
        };

      in
      {
        overlays.default = final: prev: {
          check_mk_agent = pkg prev;
        };

        packages = forAllSystems (system: {
          default = pkg pkgs.${system};
        });

        nixosModules.check_mk_agent = { config, lib, pkgs, ... }: {
          nixpkgs.overlays = [ self.overlays.default ];
          imports = [ ./modules/check_mk_agent.nix ];
        };

        checks = forAllSystems (system:
          let
            pkgs = import nixpkgs {
              inherit system;
            };
            pythonTest = import ("${nixpkgs}/nixos/lib/testing-python.nix") {
              inherit (pkgs.stdenv.hostPlatform) system;
            };
          in
          {
            default = pythonTest.runTest {
              name = "default config";

              nodes.simple = { config, pkgs, ... }: {
                imports = [ self.nixosModules.check_mk_agent ];
                environment.systemPackages = with pkgs; [
                  inetutils
                ];
                # config start
                services.check_mk_agent = {
                  enable = true;
                };
                # config end
              };

              nodes.configured = { config, pkgs, ... }: {
                imports = [ self.nixosModules.check_mk_agent ];
                # config start
                services.check_mk_agent = {
                  enable = true;
                  bind = "0.0.0.0";
                  openFirewall = true;
                  package = pkgs.check_mk_agent.override {
                    enablePluginSmart = true;
                  };
                };
                # config end
              };

              testScript = ''
                simple.start()
                configured.start()
                simple.wait_for_unit("multi-user.target")
                simple.succeed("telnet 127.0.0.1 6556")
                configured.wait_for_unit("multi-user.target")
                simple.succeed("telnet configured 6556 | grep '<<<smart>>>'")
              '';
            };
          });
      }
    );
}
