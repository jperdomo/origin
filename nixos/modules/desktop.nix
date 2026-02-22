{ config, pkgs, lib, ... }:

let
  tuigreet = "${pkgs.greetd.tuigreet}/bin/tuigreet";
in
{
  # ── Hyprland ──────────────────────────────────────────────────────
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-hyprland ];
  };

  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  # ── Login manager: greetd + tuigreet ──────────────────────────────
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${tuigreet} --time --remember --remember-session --asterisks --cmd Hyprland";
        user = "greeter";
      };
    };
  };

  systemd.services.greetd.serviceConfig = {
    Type = "idle";
    StandardInput = "tty";
    StandardOutput = "tty";
    StandardError = "journal";
    TTYReset = true;
    TTYVHangup = true;
    TTYVTDisallocate = true;
  };

  # ── PipeWire audio ────────────────────────────────────────────────
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
    wireplumber.enable = true;
  };

  # ── Polkit ────────────────────────────────────────────────────────
  security.polkit.enable = true;

  systemd.user.services.polkit-gnome-authentication-agent-1 = {
    description = "polkit-gnome-authentication-agent-1";
    wantedBy = [ "graphical-session.target" ];
    wants = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
      Restart = "on-failure";
      RestartSec = 1;
      TimeoutStopSec = 10;
    };
  };

  # ── Hyprlock PAM integration ──────────────────────────────────────
  security.pam.services.hyprlock = {};

  # ── Desktop packages ──────────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    kitty
    wofi
    waybar
    hyprpaper
    hyprlock
    hypridle
    dunst
    grim
    slurp
    wl-clipboard
    brightnessctl
    polkit_gnome
    xfce.thunar
    pavucontrol
    networkmanagerapplet
    nwg-look
    libsForQt5.qt5.qtwayland
    kdePackages.qtwayland
    firefox
  ];

  # ── Fonts ─────────────────────────────────────────────────────────
  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-emoji
    font-awesome
    (nerdfonts.override { fonts = [ "JetBrainsMono" ]; })
  ];
}
