# check_mk_agent for nixos

## How to use

``` nix
# /etc/nixos/configuration.nix
# ...
{
  imports =
    [
      /path/to/this/repo/
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
