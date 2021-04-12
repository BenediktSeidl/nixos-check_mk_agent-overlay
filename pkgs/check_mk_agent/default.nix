{ stdenv
, lib
, pkgs
, fetchFromGitHub
, enablePluginSmart ? false
, enablePluginDocker ? false
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
  ];
  python = pkgs.python38;
  pythonPackages = pkgs.python38Packages;
  plugins = [
    {
      name = "smart";
      enabled = enablePluginSmart;
      deps = with pkgs; [ smartmontools which gawk gnugrep gnused ];
    }
    {
      name = "mk_docker.py";
      enabled = enablePluginDocker;
      isPythonPlugin = true;
      pythonDeps = with pythonPackages; [ docker ];
    }
  ];
  pluginInstallPhase = plugin:
    let
      isPythonPlugin = plugin ? isPythonPlugin && plugin.isPythonPlugin == true;
    in
    ''
    '' + (if isPythonPlugin then ''
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
    '' else ''
      install -m755 -D \
        agents/plugins/${plugin.name} \
        "$out/usr/lib/check_mk_agent/plugins/${plugin.name}"
      wrapProgram "$out/usr/lib/check_mk_agent/plugins/${plugin.name}" \
        --prefix PATH : ${lib.makeBinPath plugin.deps}
    '');
  pluginsToInstall = (lib.filter (plugin: plugin.enabled) plugins);
in
stdenv.mkDerivation rec {
  pname = "check_mk_agent";
  version = "v2.0.0p1";

  src = fetchFromGitHub {
    owner = "tribe29";
    repo = "checkmk";
    rev = version;
    sha256 = "0kda806q72j333vfc3mj32iw3i0vrrz26kziv01pxzfppcxykkdh";
  };

  buildInputs = [ pkgs.makeWrapper python.pkgs.wrapPython ];

  # don't use the makefile for the main project, we only want the agent files
  patchPhase = ''
    rm Makefile
  '';

  installPhase = ''
    install -m755 -D agents/check_mk_agent.linux "$out/bin/check_mk_agent"
    wrapProgram "$out/bin/check_mk_agent" \
      --prefix PATH : ${lib.makeBinPath deps} \
      --set-default MK_LIBDIR $out/usr/lib/check_mk_agent/ \
      --set-default MK_CONFDIR $out/etc/check_mk_agent/ \
      --set-default MK_VARDIR $out/var/lib/check_mk_agent/
  '' + lib.concatStringsSep "\n" (map pluginInstallPhase pluginsToInstall) + ''
    patchShebangs $out/bin/
  '' + (if (lib.length pluginsToInstall) != 0 then "patchShebangs $out/usr/lib/check_mk_agent/" else "");
}
