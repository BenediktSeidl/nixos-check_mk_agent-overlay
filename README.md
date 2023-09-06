# check_mk_agent for nixos

## How to add

### nixos

``` nix
# /etc/nixos/configuration.nix
{
  # ...
  imports =
    [
      /path/to/this/repo
    ];
  # ...
  services.check_mk_agent = {
    enable = true;
    bind = "0.0.0.0";
    openFirewall = true;
    package = pkgs.check_mk_agent.override { enablePluginSmart = true; };
  };
  # ...
}
```

### flakes

``` nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.05";
    check_mk_agent = {
      url = "github:BenediktSeidl/nixos-check_mk_agent-overlay";
      # optional:
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = { self, nixpkgs, check_mk_agent, ... }@inputs: {
    nixosConfigurations."hostname" = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        check_mk_agent.nixosModules.check_mk_agent
        ({ config, ... }: {
          services.check_mk_agent = {
            enable = true;
            bind = "0.0.0.0";
            openFirewall = true;
            package = pkgs.check_mk_agent.override {
              enablePluginSmart = true;
            };
          };
        })
      ];
    };
  };
}
```


## How to configure

[local checks](https://docs.checkmk.com/latest/en/localchecks.html):

``` nix
{
#   ... .override {
      localChecks = [
        {
          name = "my_custom_local_check";
          script = ''
            count=`curl "https://www.random.org/integers/?num=1&min=1&max=100&col=1&base=10&format=plain&rnd=new"`
            echo "P \"my_custom_local_check\" random_count=$count;25;50"
          '';
          deps = [ pkgs.curl ];
        }
      ];
    };
# ...
}
```
