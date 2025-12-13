{
  description = "My NixOS system with Home-Manager and Zen Browser";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ { nixpkgs, home-manager, zen-browser, ... }: {
    nixosConfigurations.nixosbtw = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        ./hardware-configuration.nix

        # Home Manager module
        home-manager.nixosModules.home-manager

        # Home Manager config for user daniel
        {
          home-manager.users.daniel = { pkgs, ... }: {
            home.stateVersion = "24.11";
            nixpkgs.config.allowUnfree = true;

            # Import Zen Browser module
            imports = [
              zen-browser.homeModules.beta
            ];

            programs.zen-browser.enable = true;
  
            home.packages = with pkgs; [
              fastfetch
              vscode
              #spotify # use flatpak for spicetify
              discord
              rofi
              protonup-qt
              lutris
              bottles
              heroic
              spicetify-cli
              pavucontrol
              polychromatic
              openrazer-daemon
              fanctl
 	      lm_sensors
              spicetify-cli
            ];
          };
        }
      ];
    };
  };
}
