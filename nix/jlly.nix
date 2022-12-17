{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.services.jlly_bot;

  isAbsolutePath = v: isString v && substring 0 1 v == "/";
  isSecret = v: isAttrs v && v ? _secret && isAbsolutePath v._secret;

  absolutePath = with types;
    mkOptionType {
      name = "absolutePath";
      description = "absolute path";
      descriptionClass = "noun";
      check = isAbsolutePath;
      inherit (str) merge;
    };

  secret = mkOptionType {
    name = "secret";
    description = "secret value";
    descriptionClass = "noun";
    check = isSecret;
    nestedTypes = { _secret = absolutePath; };
  };

  elixirValue = let
    elixirValue' = with types;
      nullOr (oneOf [
        bool
        int
        float
        str
        (attrsOf elixirValue')
        (listOf elixirValue')
      ]) // {
        description = "Elixir value";
      };
  in elixirValue';

  replaceSec = let
    replaceSec' = { }@args:
      v:
      if isAttrs v then
        if v ? _secret then
          if isAbsolutePath v._secret then
            sha256 v._secret
          else
            abort "Invalid secret path (_secret = ${v._secret})"
        else
          mapAttrs (_: val: replaceSec' args val) v
      else if isList v then
        map (replaceSec' args) v
      else
        v;
  in replaceSec' { };

  format = pkgs.formats.elixirConf { };
  configFile = format.generate "config.exs"
    (replaceSec (attrsets.updateManyAttrsByPath [ ] cfg.config));

  cookieWrapper = name:
    pkgs.writeShellApplication {
      inherit name;
      text = ''
        RELEASE_COOKIE="''${RELEASE_COOKIE:-$(<"''${RUNTIME_DIRECTORY:-/run/jlly_bot}/cookie")}" \
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

  copyScript = writeShell {
    name = "jlly-copy-cookie";
    runtimeInputs = with pkgs; [ coreutils ];
    text = ''
      install -m 0400 \
        -o ${escapeShellArg cfg.user} \
        -g ${escapeShellArg cfg.group} \
        ${escapeShellArg cfg.dist.cookie._secret} \
        "$RUNTIME_DIRECTORY/cookie"
    '';
  };

  sha256 = builtins.hashString "sha256";

  configScript = writeShell {
    name = "jlly_bot-config";
    runtimeInputs = with pkgs; [ coreutils replace-secret ];
    text = ''
      cd "$RUNTIME_DIRECTORY"
      tmp="$(mktemp config.exs.XXXXXXXXXX)"
      trap 'rm -f "$tmp"' EXIT TERM
      cat ${escapeShellArg configFile} >"$tmp"
      ${concatMapStrings (file: ''
        replace-secret ${escapeShellArgs [ (sha256 file) file ]} "$tmp"
      '') secretPaths}
      chown ${escapeShellArg cfg.user}:${escapeShellArg cfg.group} "$tmp"
      chmod 0400 "$tmp"
      mv -f "$tmp" config.exs
    '';
  };

  secretPaths = catAttrs "_secret" (collect isSecret cfg.config);
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

      package = mkOption {
        type = types.package;
        default = pkgs.jlly_bot;
        defaultText = literalExpression "pkgs.jlly_bot";
        description = mdDoc "Jlly package to use.";
      };

      dist = {
        cookie = mkOption {
          type = types.nullOr secret;
          default = null;
          example = { _secret = "/var/lib/secrets/jlly_bot/releaseCookie"; };
          description = mdDoc ''
            Erlang release cookie.
            If set to `null`, a temporary random cookie will be generated.
          '';
        };
      };

      tokenFile = mkOption {
        type = types.nullOr absolutePath;
        default = null;
        example = "/var/lib/secrets/jlly_bot/token";
      };

      config = mkOption {
        description = mdDoc ''
          Config

          Settings containing secret data should be set to an attribute set containing the
          attribute `_secret` - a string pointing to a file containing the value the option
          should be set to.
        '';

        type = types.submodule {
          freeformType = format.type;
          options = {
            ":nostrum" = {
              ":token" = mkOption {
                type = secret;
                description = "Discord bot token";
                default = cfg.tokenFile;
              };
            };
            ":jlly_bot" = {
              "JllyBot.Repo" = mkOption {
                type = elixirValue;
                default = {
                  socket_dir = "/run/postgresql";
                  username = cfg.user;
                  database = "jlly_bot";
                };
                defaultText = literalExpression ''
                  {
                    adapter = (pkgs.formats.elixirConf { }).lib.mkRaw "Ecto.Adapters.Postgres";
                    socket_dir = "/run/postgresql";
                    username = config.services.jlly_bot.user;
                    database = "jlly_bot";
                  }
                '';
                description = mdDoc ''
                  Database configuration.
                  Refer to
                  <https://hexdocs.pm/ecto_sql/Ecto.Adapters.Postgres.html#module-connection-options>
                  for options.
                '';
              };
            };
          };
        };
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

    services.postgresql = {
      enable = true;
      ensureUsers = [{
        name = "jlly_bot";
        ensurePermissions."DATABASE jlly_bot" = "ALL PRIVILEGES";
      }];
      ensureDatabases = [ "jlly_bot" ];
    };

    systemd.services.jlly_bot-config = {
      description = "Jlly Bot configuration";
      reloadTriggers = [ configFile ] ++ secretPaths;

      serviceConfig = {
        PropagateReloadTo = [ "jlly_bot.service" ];
        Type = "oneshot";
        RemainAfterExit = true;
        UMask = "0077";

        RuntimeDirectory = "jlly_bot";
        RuntimeDirectoryMode = "0711";

        ExecStart =
          (if cfg.dist.cookie == null then [ genScript ] else [ copyScript ])
          ++ [ configScript ];
        ExecReload = [ configScript ];
      };
    };

    systemd.services.jlly_bot = {
      description = "Jlly Bot for escapetheaverage";

      bindsTo = [ "jlly_bot-config.service" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      after =
        [ "jlly_bot-config.service" "network.target" "network-online.target" ];

      environment = { JLLY_CONFIG_PATH = "%t/jlly_bot/config.exs"; };

      #environment
      serviceConfig = {
        Type = "exec";
        User = cfg.user;
        Group = cfg.group;
        UMask = "0077";

        RuntimeDirectory = "jlly_bot";
        RuntimeDirectoryMode = "0711";
        RuntimeDirectoryPreserve = true;
        StateDirectory = "jlly_bot";
        StateDirectoryMode = "0700";

        BindReadOnlyPaths = [ "/etc/hosts" "/etc/resolv.conf" ];

        ExecStartPre =
          "${jlly_bot}/bin/jlly_bot eval 'JllyBot.ReleaseTasks.run(\"migrate\")'";
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

        RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];
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
      };
    };

    environment.systemPackages = [ jlly_bot ];
  };
}
