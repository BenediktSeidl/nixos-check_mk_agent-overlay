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

It's also possible to configure [local checks](https://docs.checkmk.com/latest/en/localchecks.html):

``` nix
{
# ...
    package = pkgs.check_mk_agent.override {
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
