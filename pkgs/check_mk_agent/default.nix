{ stdenv
, lib
, pkgs
, fetchFromGitHub
, writeShellScript
, runtimeShell
, enablePluginSmart ? false
, enablePluginDocker ? false
, localChecks ? [ ]
}:
let
  deps = with pkgs; [
    # TODO: check if really all of these are needed
    coreutils
    bash
    systemd
    gnugrep
    socat
    findutils
    openssl
    zfs
    ethtool
    gnused
    gawk
    iproute
    time
  ];
  python = pkgs.python38;
  pythonPackages = pkgs.python38Packages;
  plugins = [
    {
      name = "smart";
      enabled = enablePluginSmart;
      type = "bash";
      deps = with pkgs; [ smartmontools which gawk gnugrep gnused ];
    }
    {
      name = "mk_docker.py";
      enabled = enablePluginDocker;
      type = "python";
      pythonDeps = with pythonPackages; [ docker ];
    }
  ];
  localChecksToPlugin = localCheck:
    {
      name = localCheck.name;
      localCheck = writeShellScript "localcheck" ''
        export PATH="${lib.makeBinPath localCheck.deps}:$PATH"
        ${localCheck.script}
      '';
      type = "local";
    };
  pluginInstallPhase = plugin:
    ''
    '' + (if plugin.type == "python" then ''
      # we want to wrap only a sinlge python script, so we move the script
      # into it's own folder, wrap all scripts in that folder and create a symlink
      FOLDER_WRAPPED=$out/usr/lib/check_mk_agent/plugins/.${plugin.name}.wrapped
      install -m755 -D agents/plugins/${plugin.name} $FOLDER_WRAPPED/${plugin.name}
      wrapPythonProgramsIn $FOLDER_WRAPPED ${toString plugin.pythonDeps}
      # checkmk tries to choose the correct python interpreter when the plugin ends with
      # .py so we create the symlink without file extension, we already patched the interpreter
      ln -s \
        $FOLDER_WRAPPED/${plugin.name} \
        "$out/usr/lib/check_mk_agent/plugins/${lib.removeSuffix ".py" plugin.name}"
    '' else if plugin.type == "bash" then ''
      install -m755 -D \
        agents/plugins/${plugin.name} \
        "$out/usr/lib/check_mk_agent/plugins/${plugin.name}"
      wrapProgram "$out/usr/lib/check_mk_agent/plugins/${plugin.name}" \
        --prefix PATH : ${lib.makeBinPath plugin.deps}
    '' else ''
      mkdir -p "$out/usr/lib/check_mk_agent/local/"
      ln -s \
        ${plugin.localCheck} \
        "$out/usr/lib/check_mk_agent/local/${plugin.name}"
    '');
  pluginsToInstall = (lib.filter (plugin: plugin.enabled) plugins) ++ (map localChecksToPlugin localChecks);
in
stdenv.mkDerivation rec {
  pname = "check_mk_agent";
  version = "v2.1.0p6";

  src = fetchFromGitHub {
    owner = "tribe29";
    repo = "checkmk";
    rev = version;
    sha256 = "1kzik7jpsilsidxvfz8vyaqr6lq0fg9794nmdczg4ypfmanfjrhm";
  };

  buildInputs = [ pkgs.makeWrapper python.pkgs.wrapPython ];

  # don't use the makefile for the main project, we only want the agent files
  patchPhase = ''
    rm Makefile
  '';

  installPhase = ''
    sed -i "s#/usr/bin/time#${pkgs.time}/bin/time#g" agents/mk-job
    install -m755 -D agents/mk-job "$out/bin/mk-job"
    wrapProgram "$out/bin/mk-job" \
      --prefix PATH : ${pkgs.lib.makeBinPath deps}
    install -m755 -D agents/check_mk_agent.linux "$out/bin/check_mk_agent"
    wrapProgram "$out/bin/check_mk_agent" \
      --prefix PATH : ${lib.makeBinPath deps} \
      --set-default MK_LIBDIR $out/usr/lib/check_mk_agent \
      --set-default MK_CONFDIR $out/etc/check_mk_agent
  '' + lib.concatStringsSep "\n" (map pluginInstallPhase pluginsToInstall) + ''
    patchShebangs $out/bin/
  '' + (if (lib.length pluginsToInstall) != 0 then "patchShebangs $out/usr/lib/check_mk_agent/" else "");
}
