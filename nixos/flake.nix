{
  description = "My full NixOS system — Home-Manager, Zen Browser, Star Citizen, SilentSDDM";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Pinned revision for claude-code (works around upstream regressions)
    nixpkgs-claude.url = "github:NixOS/nixpkgs?rev=b2b9662ffe1e9a5702e7bfbd983595dd56147dbf";
    ## Secure Boot
    lanzaboote = {
      url    = "github:nix-community/lanzaboote";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ## Home Manager
    home-manager = {
      url    = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ## Zen Browser
    zen-browser = {
      url    = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ## Star Citizen
    nix-citizen.url = "github:LovingMelody/nix-citizen";
    nix-gaming.url  = "github:fufexan/nix-gaming";
    nix-citizen.inputs.nix-gaming.follows = "nix-gaming";
    ## SilentSDDM theme
    silentSDDM = {
      url    = "github:uiriansan/SilentSDDM";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = inputs @ {
    self, nixpkgs, nixpkgs-claude, home-manager,
    zen-browser, lanzaboote,
    nix-citizen, silentSDDM, ...
  }:
  let
    system = "x86_64-linux";
    pkgs-claude = import nixpkgs-claude {
      inherit system;
      config.allowUnfree = true;
    };
  in {
    nixosConfigurations.nixosbtw = nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = { inherit inputs system pkgs-claude; };
      modules = [
        ## Secure Boot
        lanzaboote.nixosModules.lanzaboote
        ./configuration.nix
        ./hardware-configuration.nix
        ## Home Manager
        home-manager.nixosModules.home-manager
        {
          nixpkgs.config.allowUnfree  = true;
          home-manager.useGlobalPkgs   = true;
          home-manager.useUserPackages = true;
          home-manager.extraSpecialArgs = { inherit pkgs-claude; };
          home-manager.users.daniel = { pkgs, pkgs-claude, ... }: {
            home.stateVersion = "24.11";
            imports = [ zen-browser.homeModules.beta ];
            programs.zen-browser.enable = true;
            home.packages = (with pkgs; [
              inputs.nix-citizen.packages.${system}.rsi-launcher
              fastfetch
              vscode
              discord
              rofi
              protonup-qt
              lutris
              bottles
              heroic
              spicetify-cli
              pavucontrol
              polychromatic
              fanctl
              lm_sensors
              brave
              btop
            ]) ++ [
              pkgs-claude.claude-code
            ];
          };
        }
        ## Star Citizen system module
        nix-citizen.nixosModules.default
        ## SilentSDDM
        silentSDDM.nixosModules.default
        {
          programs.silentSDDM.enable = true;
          programs.silentSDDM.theme  = "rei";
        }
      ];
    };
  };
}
