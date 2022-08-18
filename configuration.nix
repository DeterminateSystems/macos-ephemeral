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
  
  services.buildkite-agent = {
    enable = true;
    extraConfig = "yolo=1";
    openssh.privateKeyPath = "/dev/null";
    openssh.publicKeyPath = "/dev/null";
    tokenPath = "/nix/home/buildkite.token";
    dataDir = "/nix/buildkite/";
  };

  
  nix.nixPath = [ "nixpkgs=channel:nixpkgs-unstable" ];
    launchd.daemons.prometheus-node-exporter = {
    script = ''
      exec ${pkgs.prometheus-node-exporter}/bin/node_exporter
    '';

    serviceConfig.KeepAlive = true;
    serviceConfig.StandardErrorPath = "/var/log/prometheus-node-exporter.log";
    serviceConfig.StandardOutPath = "/var/log/prometheus-node-exporter.log";
  };
}