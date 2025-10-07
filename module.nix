{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.nixos-unattended-upgrade;
in
{
  options.services.nixos-unattended-upgrade = {
    enable = lib.mkEnableOption "nixos-unattended-upgrade, automatic system upgrades on steroids";

    cacheUrl = lib.mkOption {
      type = lib.types.url;
      example = "https://cache.example.com";
      description = ''
        URL of your binary cache
      '';
    };

    trustedPubkey = lib.mkOption {
      type = lib.types.string;
      example = "servers:asdf1337";
      description = ''
        Public key for your cache
      '';
    };

    netrcFile = lib.mkOption {
      type = lib.types.path;
      default = "/etc/nix/netrc";
      example = "/etc/nix/netrc";
      description = ''
        Path to your netrc file for authentication against the cache
      '';
    };

    updateEndpoint = lib.mkOption {
      type = lib.types.string;
      example = "/run/secrets/nixos-unattended-upgrade.toml";
      description = ''
        HTTPS address of your update endpoint
      '';
    };

    timerTime = lib.mkOption {
      type = lib.types.string;
      default = "*-*-* 4:00:00";
      example = "*-*-* 4:00:00";
      description = ''
        OnCalender value for the systemd timer
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    nix.settings = {
      netrc-file = "${cfg.netrcFile}";
      substituters = [
        cfg.cacheURL
      ];
      trusted-public-keys = [
        cfg.pubKey
      ];
    };

    systemd.services."nixos-unattended-upgrade" = {
      path = with pkgs; [
        curl
        cpio
        zstd
        kexec-tools
      ];
      script = builtins.readFile ./update.sh;
    };

    systemd.timers."nixos-unattended-upgrade" = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.timerTime;
      };
    };

  };
}
