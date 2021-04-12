{
  imports = [
    ./modules/check_mk_agent.nix
  ];
  nixpkgs.overlays = [
    (import ./overlays.nix)
  ];
}
