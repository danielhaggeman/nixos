# Desktop PC — nixosbtw
# AMD double GPU · Hyprland + KDE Plasma · SDDM · Secure Boot

{ config, lib, pkgs, ... }:

{
  nixpkgs.config.allowUnfree = true;
  services.udisks2.enable = true;

  imports = [ ./hardware-configuration.nix ];

  ## Bootloader — lanzaboote (Secure Boot)
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.lanzaboote = {
    enable    = true;
    pkiBundle = "/var/lib/sbctl";
  };
 
programs.nix-ld.enable = true;

  ## Star Citizen kernel settings
  boot.kernel.sysctl = {
    "vm.max_map_count" = 16777216;
    "fs.file-max"      = 524288;
  };

  ## Virtual camera (OBS virtual cam)
  boot.extraModulePackages = with config.boot.kernelPackages; [
    v4l2loopback
  ];
  boot.kernelModules = [ "v4l2loopback" ];
  boot.extraModprobeConfig = ''
    options v4l2loopback devices=1 video_nr=1 card_label="OBS Virtual Camera" exclusive_caps=1
  '';

  ## Networking
  networking.hostName = "nixosbtw";
networking.networkmanager.enable = true;
networking.networkmanager.connectionConfig = {
  "ipv4.dns-search" = "";
  "ipv6.dns-search" = "";
  "ipv4.ignore-auto-dns" = true;
  "ipv6.ignore-auto-dns" = true;
};
networking.nameservers = [
  "192.168.10.253"
  "192.168.10.254"
  "1.1.1.1"
];
networking.search = lib.mkForce [ ];
  ## Timezone
  time.timeZone = "Europe/Amsterdam";

  ## Udev rules
  services.udev.extraRules = ''
    SUBSYSTEM=="hidraw", ATTRS{idVendor}=="3633", MODE="0666"
    SUBSYSTEM=="hidraw", ATTRS{idVendor}=="34d3", ATTRS{idProduct}=="1100", MODE="0666"
  '';

  ## Shell (ZSH)
  programs.zsh = {
    enable             = true;
    enableCompletion   = true;
    syntaxHighlighting.enable = false;
    autosuggestions.enable   = false;
  };
  users.defaultUserShell = pkgs.zsh;

  ## AMD GPU — both iGPU and dGPU are AMD
  services.xserver.videoDrivers = [ "amdgpu" ];
  hardware.graphics = {
    enable      = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      mesa
      vulkan-loader
    ];
    extraPackages32 = with pkgs; [
      driversi686Linux.mesa
    ];
  };

  ## Gaming
  programs.steam = {
    enable               = true;
    gamescopeSession.enable = true;
  };
  programs.gamemode.enable = true;

  ## Audio
  security.rtkit.enable = true;
  services.pulseaudio.enable = false;
  services.pipewire = {
    enable             = true;
    alsa.enable        = true;
    pulse.enable       = true;
    wireplumber.enable = true;
  };

  ## Security
  security.polkit.enable           = true;
  security.sudo.wheelNeedsPassword  = false;

  ## User
  users.users.daniel = {
    isNormalUser = true;
    shell        = pkgs.zsh;
    extraGroups  = [ "wheel" "networkmanager" "video" "audio" ];
  };

  ## Browser
  programs.firefox.enable = true;

  ## Hyprland
  programs.hyprland = {
    enable          = true;
    xwayland.enable = true;
  };

  ## KDE Plasma 6
  services.desktopManager.plasma6.enable = true;

  ## Display Manager — SDDM
  services.displayManager.sddm = {
    enable         = true;
    wayland.enable = true;
  };
  services.greetd.enable = lib.mkForce false;

  ## OBS
  programs.obs-studio.enable = true;

  ## XDG portals — required for Wayland screen capture
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-hyprland
      xdg-desktop-portal-gtk
    ];
  };

  ## System packages
  environment.systemPackages = with pkgs; [
    kitty
    alacritty
    hyprpaper
    wget
    lxqt.lxqt-policykit
    git
    htop
    vulkan-tools
    mesa-demos
    unzip
    sudo
    swappy
    slurp
    tailscale
    grim
    yazi
    xfce.thunar
    xfce.thunar-volman
    wl-clipboard
    zsh
    zsh-autosuggestions
    zsh-syntax-highlighting
    deepcool-digital-linux
    ethtool
    fzf
    networkmanager
    neovim
    ripgrep
    fd
    nodejs
    gvfs
    pkg-config
    libvterm
    gcc
    gnumake
    cmake
    bibata-cursors
    gobject-introspection
    gtk3
    (python3.withPackages (ps: with ps; [ pygobject3 ]))
    playerctl
    xfce.xfconf
    sbctl
    gpu-screen-recorder
    ## SilentSDDM dependencies
    qt6.qtbase
    qt6.qtsvg
    qt6.qtvirtualkeyboard
    qt6.qtmultimedia
    libsForQt5.qt5.qtgraphicaleffects
    element-desktop
    putty
    thunderbird
    gpu-screen-recorder
    gpu-screen-recorder-gtk 
    mpv
    haruna
    losslesscut-bin
    kdePackages.kdenlive
    hyprviz
#    claude-code

    ## Dynamic Island / Media
    easyeffects
    socat
    jq

    ## Wallpaper + dynamic theming
    swww
    pywal
    imagemagick

    ## Quickshell bar
    quickshell
    swayosd
    matugen
    hyprlock
    inotify-tools
    pamixer
  ];

  ## Tailscale
  services.tailscale.enable = true;

  ## Flatpak
  services.flatpak.enable = true;

  ## Environment variables
  environment.variables = {
    XCURSOR_THEME = "Bibata-Modern-Classic";
    XCURSOR_SIZE  = "24";
  };

  ## Openrazer
  hardware.openrazer = {
    enable = true;
    users  = [ "daniel" ];
  };

  ## Fonts
  fonts = {
    fontconfig.enable = true;
    packages = with pkgs; [
      nerd-fonts.commit-mono
      nerd-fonts.fira-code
      nerd-fonts.symbols-only
      fira-sans
      roboto
      font-awesome
    ];
  };

services.hardware.openrgb = {
  enable = true;
  motherboard = "amd"; # or "intel" depending on your platform
};

  ## Deepcool AIO service
  systemd.services.deepcool-digital-linux = {
    description = "Deepcool Digital Linux Service";
    wantedBy    = [ "multi-user.target" ];
    after       = [ "network.target" ];
    serviceConfig = {
      ExecStart  = "/opt/deepcool/deepcool-digital-linux";
      Restart    = "on-failure";
      RestartSec = 2;
      User       = "root";
    };
  };

  ## Nix settings
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  system.stateVersion = "25.11";
}


