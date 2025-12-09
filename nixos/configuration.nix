# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).


{ config, lib, pkgs, ... }:

{
nixpkgs.config.allowUnfree = true;

  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nixosbtw"; # Define your hostname.

  # Configure network connections interactively with nmcli or nmtui.
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Europe/Amsterdam";

 
  # Select internationalisation properties.
  # i18n.defaultLocale = "en_US.UTF-8";
  # console = {
  #   font = "Lat2-Terminus16";
  #   keyMap = "us";
  #   useXkbConfig = true; # use xkb.options in tty.
  # };

  # Enable the X11 windowing system.
  # services.xserver.enable = true;

services.udev.extraRules = ''
  SUBSYSTEM=="hidraw", ATTRS{idVendor}=="3633", MODE="0666"
  SUBSYSTEM=="hidraw", ATTRS{idVendor}=="34d3", ATTRS{idProduct}=="1100", MODE="0666"
'';

# ZSH

programs.zsh.enable = true;

users.users.daniel = {
  shell = pkgs.zsh;
};




# AMD GPU drivers
services.xserver.videoDrivers = [ "amdgpu" ];

hardware.graphics = {
  enable = true;
  enable32Bit = true;

  extraPackages = with pkgs; [
    mesa
    vulkan-loader
  ];

  extraPackages32 = with pkgs; [
    driversi686Linux.mesa
  ];
};

# Steam
programs.steam = {
  enable = true;
  gamescopeSession.enable = true;
};

programs.gamemode.enable = true;

  
  # Configure keymap in X11
  # services.xserver.xkb.layout = "us";
  # services.xserver.xkb.options = "eurosign:e,caps:escape";

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable sound.
  services.pulseaudio.enable = true;
  services.pipewire.enable = false;
  services.pipewire.pulse.enable = false;
  services.pipewire.alsa.enable = false;
  
  # polkit
  security.polkit.enable = true;
  # Enable touchpad support (enabled default in most desktopManager).
  # services.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
   users.users.daniel = {
     isNormalUser = true;
     extraGroups = [ "wheel" "networkmanager" "video" ]; 
     };
 security.sudo.wheelNeedsPassword = false; 
 programs.firefox.enable = true;

  # HYPRLAND
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };
  
  # Zen Browser


  # Greetd
  services.greetd = {
    enable = true;

    settings = {
      default_session = {
        command = "hyprland";
        user = "daniel";
      };
    };
  };
  # List packages installed in system profile.
  # You can use https://search.nixos.org/ to find more packages (and options).
   environment.systemPackages = with pkgs; [
     kitty
     waybar
     hyprpaper
     vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
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
     grim
     pulseaudio
   ];


# Custom Systemd

# Backup Script
systemd.services.backup = {
  description = "Backup NixOS, Hyprland and Rofi configs to GitHub";

  wantedBy = [ "multi-user.target" ];

  serviceConfig = {
    Type = "oneshot";

    # REQUIRED: give systemd access to bash and core tools
    Path = [
      pkgs.bash
      pkgs.git
      pkgs.rsync
      pkgs.coreutils
    ];

    ExecStart = "/etc/nixos/scripts/backup.sh";
  };
};

# Deepcool AIO
systemd.services.deepcool-digital-linux = {
  description = "Deepcool Digital Linux Service";

  wantedBy = [ "multi-user.target" ];
  after = [ "network.target" ];

  serviceConfig = {
    ExecStart = "/opt/deepcool/deepcool-digital-linux";
    Restart = "on-failure";
    RestartSec = 2;
    User = "root";
  };
};


  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.11"; # Did you read the comment?

}

