{ config, lib, pkgs, ... }:

with lib;

let
  callPackage = pkgs.lib.callPackageWith (pkgs);
  cfg = config.services.check_mk_agent;
  listenStream = (if cfg.bind != null then cfg.bind + ":" else "") + toString cfg.port;
in
{
  options = {
    services.check_mk_agent = {
      enable = mkOption {
        type = types.bool;
        default = false;
      };

      package = mkOption {
        type = lib.types.package;
        default = pkgs.check_mk_agent;
      };

      port = mkOption {
        type = types.int;
        default = 6556;
        description = "The port for check_mk_agent to listen to.";
      };

      bind = mkOption {
        type = with types; nullOr str;
        default = "127.0.0.1";
        description = ''
          The IP address to bind to.
          <literal>null</literal> means "all interfaces".
        '';
        example = "10.10.10.1";
      };

      openFirewall = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Whether to open the port in the firewall for the agent.
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    networking.firewall = mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };

    systemd.services."check_mk_agent@" = {
      # https://github.com/tribe29/checkmk/blob/v2.0.0p1/agents/cfg_examples/systemd/check_mk@.service
      description = "checkmk agent";

      requires = [ "check_mk_agent.socket" ];

      serviceConfig = {
        ExecStart = "-${cfg.package}/bin/check_mk_agent";
        Type = "forking";
        User = "root";
        Group = "root";
        StandardInput = "socket";
      };
    };

    systemd.sockets.check_mk_agent = {
      # https://github.com/tribe29/checkmk/blob/v2.0.0p1/agents/cfg_examples/systemd/check_mk.socket
      description = "checkmk agent socket";
      partOf = [ "check_mk_agent@.service" ];
      wantedBy = [ "sockets.target" ];

      listenStreams = [ listenStream ];

      socketConfig = {
        Accept = true; # create new process for each request
        MaxConnectionsPerSource = 3;
      };
    };
  };
}
