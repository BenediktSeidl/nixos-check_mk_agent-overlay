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
      # https://github.com/tribe29/checkmk/blob/2.1.0/agents/scripts/super-server/0_systemd/check-mk-agent%40.service
      description = "Checkmk agent";

      requires = [ "check_mk_agent.socket" ];
      environment.MK_RUN_ASYNC_PARTS = "false";
      environment.MK_READ_REMOTE = "true";

      serviceConfig = {
        ExecStart = "-${cfg.package}/bin/check_mk_agent";
        Type = "simple";
        User = "root";
        StandardInput = "socket";
        StateDirectory = "check_mk_agent";  # creates /var/lib/check_mk_agent
      };
    };

    systemd.services."check-mk-agent-async" = {
      # https://github.com/tribe29/checkmk/blob/2.1.0/agents/scripts/super-server/0_systemd/check-mk-agent-async.service
      description = "Checkmk agent - Asynchronous background tasks";

      requires = [ "check_mk_agent.socket" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      environment.MK_RUN_SYNC_PARTS = "false";
      environment.MK_LOOP_INTERVAL = "60";
      serviceConfig = {
        ExecStart = "${cfg.package}/bin/check_mk_agent";
        Type = "simple";
        User = "root";
      };
    };

    systemd.sockets.check_mk_agent = {
      # https://github.com/tribe29/checkmk/blob/2.1.0/agents/scripts/super-server/0_systemd/check-mk-agent.socket.fallback
      description = "Checkmk Agent Socket";
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
