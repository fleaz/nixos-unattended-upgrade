{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkOption
    types
    ;

  cfg = config.services.nixos-unattended-upgrade;
in
{
  options.services.nixos-unattended-upgrade = {
    enable = lib.mkEnableOption "nixos-unattended-upgrade, automatic system upgrades on steroids";

    systemClosureEndpoint = mkOption {
      type = types.str;
      example = "https://nixos-closures-paths.s3.example.com/\${config.networking.fqdn}/latest-closure-path";
      description = ''
        Endpoint where a host can retrieve the store path to its latest system closure.
      '';
    };

    binaryCacheURL = mkOption {
      type = types.str;
      example = "https://cache.example.com";
      description = ''
        URL of your binary cache
      '';
    };

    trustedPubkey = mkOption {
      type = types.str;
      example = "servers:asdf1337";
      description = ''
        Public key for your cache
      '';
    };

    netrcFile = mkOption {
      type = types.path;
      default = "/etc/nix/netrc";
      example = "/etc/nix/netrc";
      description = ''
        Path to your netrc file for authentication against the cache
      '';
    };

    allowSwitch = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Whether to switch into the new generation.

        Disabling this can make sense e.g. when you want prevent disruptive behavior while using the machine.
      '';
    };

    allowKexec = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to kexec (using `systemctl kexec`) into the new generation, when the generation has a newer kernel than the booted kernel.
      '';
    };

    allowReboot = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to reboot into the new generation, when the generation has a newer kernel than the booted kernel.
      '';
    };

    timer = {
      time = mkOption {
        type = types.str;
        default = "*-*-* 4:00:00";
        example = "*-*-* 4:00:00";
        description = ''
          `OnCalender` expression for the systemd timer.

          For possible formats, please refer to {manpage}`systemd.time(7)`.
        '';
      };

      randomDelay = mkOption {
        type = types.str;
        default = "2h";
        example = "30m";
        description = ''
          Maximum value for a randomly applied delay to the timer start.

          Useful to scatter multiple machines across a shared timeframe.
        '';
      };

      persistent = mkOption {
        type = types.bool;
        default = false;
        example = true;
        description = ''
          Trigger unattended-upgrade immediately when the timer units gets activated, when the previous timer run was missed.

          Useful when a machine is not reliably up during the scheduled unattended upgrade run.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    nix.settings = {
      netrc-file = "${cfg.netrcFile}";
      substituters = [
        cfg.binaryCacheURL
      ];
      trusted-public-keys = [
        cfg.trustedPubkey
      ];
    };

    systemd.services."nixos-unattended-upgrade" = {
      path = with pkgs; [
        config.nix.package
        curl
      ];
      environment = {
        LATEST_CLOSURE_ENDPOINT_URL = cfg.systemClosureEndpoint;
        ALLOW_SWITCH = lib.boolToString cfg.allowSwitch;
        ALLOW_KEXEC = lib.boolToString cfg.allowKexec;
        ALLOW_REBOOT = lib.boolToString cfg.allowReboot;
      };
      script = builtins.readFile ./update.sh;
      restartIfChanged = false;
      serviceConfig.Type = "oneshot";
    };

    systemd.timers."nixos-unattended-upgrade" = {
      wantedBy = [ "timers.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      timerConfig = {
        OnCalendar = cfg.timer.time;
        Persistent = cfg.timer.persistent;
        # Don't hammer the cache
        RandomizedDelaySec = cfg.timer.randomDelay;
      };
    };
  };
}
