self: super:
{
  check_mk_agent = super.callPackage (import ./pkgs/check_mk_agent) {};
}
