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

  nix = {
    settings = {
      "extra-experimental-features" = [ "nix-command" "flakes" ];
    };

    nixPath = [
      "nixpkgs=channel:nixpkgs-unstable"
      "darwin=https://github.com/LnL7/nix-darwin/archive/master.tar.gz"
      "darwin-config=/nix/home/darwin-config/configuration.nix"
    ];
  };

  services.buildkite-agent = {
    enable = true;
    meta-data = "mac=1";
    openssh.privateKeyPath = "/dev/null";
    openssh.publicKeyPath = "/dev/null";
    tokenPath = "/nix/home/buildkite.token";
    extraConfig = ''
      spawn = 4
    '';
  };
  system.activationScripts.preActivation.text =
    let
      svc = config.services.buildkite-agent;
      buildkite-agent = config.users.users.buildkite-agent;

      ssh_key = "/Volumes/CONFIG/buildkite-agent/sshkey";
    in
    ''
      if [ ! -f ${lib.escapeShellArg ssh_key} ]; then
        mkdir -p "$(dirname ${lib.escapeShellArg ssh_key})" || true
        ssh-keygen -t ed25519 -f ${lib.escapeShellArg ssh_key}
      fi

      mkdir -p ${lib.escapeShellArg buildkite-agent.home} || true

      mkdir -m 0700 -p ${lib.escapeShellArg buildkite-agent.home}/.ssh
      cp ${lib.escapeShellArg ssh_key} ${lib.escapeShellArg buildkite-agent.home}/.ssh/id_ed25519
      cp ${lib.escapeShellArg ssh_key}.pub ${lib.escapeShellArg buildkite-agent.home}/.ssh/id_ed25519.pub
      chmod 600 ${lib.escapeShellArg buildkite-agent.home}/.ssh/id_ed25519

      chown ${toString buildkite-agent.uid}:${toString buildkite-agent.gid} \
        ${lib.escapeShellArg buildkite-agent.home} \
        ${lib.escapeShellArg config.services.buildkite-agent.tokenPath} \
        ${lib.escapeShellArg buildkite-agent.home}/.ssh \
        ${lib.escapeShellArg buildkite-agent.home}/.ssh/id_ed25519 \
        ${lib.escapeShellArg buildkite-agent.home}/.ssh/id_ed25519.pub

      chmod 0600 '${lib.escapeShellArg config.services.buildkite-agent.tokenPath}'
    '';

  launchd.daemons.prometheus-node-exporter = {
    script = ''
      exec ${pkgs.prometheus-node-exporter}/bin/node_exporter
    '';

    serviceConfig.KeepAlive = true;
    serviceConfig.StandardErrorPath = "/var/log/prometheus-node-exporter.log";
    serviceConfig.StandardOutPath = "/var/log/prometheus-node-exporter.log";
  };

  launchd.daemons.tailscaled = {
    script = ''
      exec ${pkgs.tailscale}/bin/tailscaled
    '';

    serviceConfig.KeepAlive = true;
    serviceConfig.StandardErrorPath = "/var/log/tailscaled.log";
    serviceConfig.StandardOutPath = "/var/log/tailscaled.log";
  };

  launchd.daemons.tailscale-auth = {
    script = ''
      set -eux

      sleep 5
      ${pkgs.tailscale}/bin/tailscale up --auth-key file:/nix/home/tailscale.token
      sleep infinity
    '';

    serviceConfig.KeepAlive = true;
    serviceConfig.StandardErrorPath = "/var/log/tailscale-auth.log";
    serviceConfig.StandardOutPath = "/var/log/tailscale-auth.log";
  };
}
