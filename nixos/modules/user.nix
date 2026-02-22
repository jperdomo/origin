{ config, pkgs, ... }:

{
  users.users.jperdomo = {
    isNormalUser = true;
    description = "jperdomo";
    shell = pkgs.bash;
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "audio"
      "input"
    ];
  };

  security.sudo.wheelNeedsPassword = true;
}
