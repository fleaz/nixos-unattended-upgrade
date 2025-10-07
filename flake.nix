{
  outputs =
    { self, ... }:
    {
      nixosModules = {
        default = self.nixosModules.nixos-unattended-upgrade;

        nixos-unattended-upgrade = {
          imports = [ ./module.nix ];
        };
      };

    };
}
