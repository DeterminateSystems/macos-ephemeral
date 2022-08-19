{ config, lib, pkgs, ... }:
{
  environment.systemPackages =
    [
      config.nix.package
      pkgs.git
    ];

  programs.zsh.enable = true;
  programs.zsh.enableCompletion = false;
  programs.bash.enable = true;
  programs.bash.enableCompletion = false;

  #services.activate-system.enable = true;

  users.knownUsers = [ "buildkite-agent" ];
  users.knownGroups = [ "buildkite-agent" ];
  users.groups.buildkite-agent.gid = 531;
  users.users.buildkite-agent.uid = 531;
  users.users.buildkite-agent.gid = config.users.groups.buildkite-agent.gid;
  users.users.buildkite-agent.shell = "/bin/sh";


  services.nix-daemon.enable = true;

  nix.nixPath = [
    "nixpkgs=channel:nixpkgs-unstable"
    "darwin=https://github.com/LnL7/nix-darwin/archive/master.tar.gz"
    "darwin-config=/nix/home/darwin-config/configuration.nix"
  ];

  services.buildkite-agent = {
    enable = true;
    meta-data = "mac=1";
    openssh.privateKeyPath = "/dev/null";
    openssh.publicKeyPath = "/dev/null";
    tokenPath = "/nix/home/buildkite.token";
  };
  system.activationScripts.preActivation.text = ''
      mkdir -p '${config.users.users.buildkite-agent.home}'
      chown ${toString config.users.users.buildkite-agent.uid}:${toString config.users.users.buildkite-agent.gid} '${config.users.users.buildkite-agent.home}'
  '';

  launchd.daemons.prometheus-node-exporter = {
    script = ''
      exec ${pkgs.prometheus-node-exporter}/bin/node_exporter
    '';

    serviceConfig.KeepAlive = true;
    serviceConfig.StandardErrorPath = "/var/log/prometheus-node-exporter.log";
    serviceConfig.StandardOutPath = "/var/log/prometheus-node-exporter.log";
  };
}