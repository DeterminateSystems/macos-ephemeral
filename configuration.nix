{ config, lib, pkgs, ... }:
{
  environment.systemPackages =
    [
      config.nix.package
    ];

  programs.zsh.enable = true;
  programs.zsh.enableCompletion = false;
  programs.bash.enable = true;
  programs.bash.enableCompletion = false;

  #services.activate-system.enable = true;

  services.nix-daemon.enable = true;
  
  nix.nixPath = [ "nixpkgs=channel:nixpkgs-unstable" ];
}