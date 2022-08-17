{ config, lib, pkgs, ... }:

with lib;
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

  nix.gc.automatic = true;
  nix.gc.interval = { Minute = 15; };
  nix.gc.options = let
      gbFree = 50;
  in "--max-freed $((${toString gbFree} * 1024**3 - 1024 * $(df -P -k /nix/store | tail -n 1 | awk '{ print $4 }')))";

  # If we drop below 20GiB during builds, free 20GiB
  nix.extraOptions = ''
    min-free = ${toString (30*1024*1024*1024)}
    max-free = ${toString (50*1024*1024*1024)}
  '';

  launchd.daemons.prometheus-node-exporter = {
    script = ''
      exec ${pkgs.prometheus-node-exporter}/bin/node_exporter
    '';

    serviceConfig.KeepAlive = true;
    serviceConfig.StandardErrorPath = "/var/log/prometheus-node-exporter.log";
    serviceConfig.StandardOutPath = "/var/log/prometheus-node-exporter.log";
  };
  
  services.buildkite-agent = {
    enable = true;
    package = buildkite-agent;
    extraConfig = "aarch64darwin=1";
    openssh.privateKeyPath = "/dev/null";
    openssh.publicKeyPath = "/dev/null";
    tokenPath = "/root/buildkite.token";
  };
}