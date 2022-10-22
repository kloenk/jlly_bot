{ config, lib, pkgs, ... }:

let
  cfg = config.services.jlly_bot;
  inherit (lib) mkOption mkEnableOption types mdDoc mkIf escapeShellArg literalExpression;

  cookieWrapper = name:
    pkgs.writeShellApplication {
      inherit name;
      text = ''
        RELEASE_COOKIE="''${RELEASE_COOKIE:-$(<"''${RUNTIME_DIRECTORY:-/run/akkoma}/cookie")}" \
          exec "${cfg.package}/bin/${name}" "$@"
      '';
    };

  jlly_bot = cookieWrapper "jlly_bot";

  writeShell = { name, text, runtimeInputs ? [ ] }:
    pkgs.writeShellApplication { inherit name text runtimeInputs; }
    + "/bin/${name}";

  genScript = writeShell {
    name = "jlly-gen-cookie";
    runtimeInputs = with pkgs; [ coreutils util-linux ];
    text = ''
      install -m 0400 \
        -o ${escapeShellArg cfg.user} \
        -g ${escapeShellArg cfg.group} \
        <(dd if=/dev/urandom bs=16 count=1 iflag=fullblock status=none | hexdump -e '16/1 "%02x"') \
        "$RUNTIME_DIRECTORY/cookie"
    '';
  };
in {
  options = {
    services.jlly_bot = {
      enable = mkEnableOption (mdDoc "Jlly Discord bot");

      user = mkOption {
        type = types.nonEmptyStr;
        default = "jlly_bot";
        description = mdDoc "User account under which jlly_bot runs.";
      };

      group = mkOption {
        type = types.nonEmptyStr;
        default = "jlly_bot";
        description = mdDoc "Group account under which jlly_bot runs.";
      };

      stateDir = mkOption {
        type = types.nonEmptyStr;
        default = "/var/lib/jlly_bot";
        readOnly = true;
        description = mdDoc "Directory where jlly_bot will save state.";
      };

      env = mkOption {
        type = types.nullOr types.nonEmptyStr;
        default = null;
        description = mdDoc "Path to secret file for bot token";
      };

      package = mkOption {
        type = types.package;
        default = pkgs.jlly_bot;
        defaultText = literalExpression "pkgs.jlly_bot";
        description = mdDoc "Jlly package to use.";
      };
    };
  };

  config = mkIf cfg.enable {
    users = {
      users."${cfg.user}" = {
        description = "jlly_bot user";
        group = cfg.group;
        isSystemUser = true;
      };
      groups."${cfg.group}" = { };
    };

    systemd.services.jlly_bot = {
      description = "Jlly Bot for escapetheaverage";

      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" "network-online.target" ];

      #environment
      serviceConfig = {
        Type = "exec";
        User = cfg.user;
        Group = cfg.group;
        UMask = "0077";

        RuntimeDirectory = "akkoma";
        RuntimeDirectoryMode = "0711";
        RuntimeDirectoryPreserve = true;
        StateDirectory = "jlly_bot";
        StateDirectoryMode = "0700";

        BindReadOnlyPaths = [ "/etc/hosts" "/etc/resolv.conf" ];

        ExecStartPre = genScript;
        ExecStart = "${jlly_bot}/bin/jlly_bot start";

        ProtectProc = "noaccess";
        ProcSubset = "pid";
        ProtectHome = true;
        PrivateTmp = true;
        PrivateDevices = true;
        PrivateIPC = true;
        ProtectHostname = true;
        ProtectClock = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectKernelLogs = true;
        ProtectControlGroups = true;

        RestrictAddressFamilies = [ "AF_INET" "AF_INET6" ];
        RestrictNamespaces = true;
        LockPersonality = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        RemoveIPC = true;

        NoNewPrivileges = true;
        SystemCallFilter = [ "@system-service" "~@privileged" "@chown" ];
        SystemCallArchitectures = "native";

        DeviceAllow = null;
        DevicePolicy = "closed";

        SocketBindDeny = "any";

        ProtectSystem = "strict";

        EnvironmentFile = lib.optional (cfg.env != null) cfg.env;
      };
    };

    environment.systemPackages = [ jlly_bot ];
  };
}
