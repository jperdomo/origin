{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./modules/user.nix
    ./modules/networking.nix
    ./modules/desktop.nix
  ];

  # ── Nix settings ──────────────────────────────────────────────────
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
  };

  nixpkgs.config.allowUnfree = true;

  # ── Boot ──────────────────────────────────────────────────────────
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # ── System ────────────────────────────────────────────────────────
  networking.hostName = "origin";
  time.timeZone = "America/New_York";

  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # ── Base packages ─────────────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    git
    gh
    nano
    curl
    htop
    bmon
    btop
    stress
    fastfetch
    net-tools
    nfs-utils
    gcc
    gnumake
  ];

  # ── System state version ──────────────────────────────────────────
  system.stateVersion = "24.11";
}
