# System configuration: the user account, nix settings and the services this
# dev VM runs. Platform glue lives in orbstack.nix, the user environment in
# home.nix.

{ config, lib, pkgs, unstable, base16-shell, ... }:

{
  imports = [ ./opencode-widget ];
  # The widget is off by default. To turn it on for a machine, add e.g.
  #   opencode-widget.enable = config.networking.hostName == "play";

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.auto-optimise-store = true;
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  time.timeZone = "Europe/London";

  users.mutableUsers = false;
  users.defaultUserShell = pkgs.zsh;
  users.users.duncanbrown = {
    uid = 501;
    extraGroups = [ "wheel" "orbstack" "audio" "docker" ];

    # simulate isNormalUser, but with an arbitrary UID
    isSystemUser = true;
    group = "users";
    createHome = true;
    home = "/home/duncanbrown";
    homeMode = "700";

    # Start the user manager at boot so the opencode user service (home.nix)
    # runs without a login.
    linger = true;
  };
  security.sudo.wheelNeedsPassword = false;

  programs.zsh.enable = true;

  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    icu
  ];

  virtualisation.docker = {
    enable = true;
    # 25.11 defaults to the unmaintained docker 28.
    package = pkgs.docker_29;
  };

  services.postgresql = {
    enable = true;
    # Single-user dev VM on localhost: trust auth is deliberate.
    # Don't copy this anywhere with real data or multiple users.
    authentication = lib.mkForce ''
      #type database  DBuser  auth-method
      local all       all     trust
      host  all       all     127.0.0.1/32   trust
      host  all       all     ::1/128        trust
      '';
    settings.port = 5434;
  };

  services.neo4j = {
    enable = true;
    # Single-user dev VM on localhost — simple auth, same principle as pg.
    # Don't copy this anywhere with real data or multiple users.
    defaultListenAddress = "0.0.0.0";
    https.enable = false;
    bolt = {
      listenAddress = "0.0.0.0:7687";
      advertisedAddress = "work.orb.local:7687";
      tlsLevel = "DISABLED";
    };
    http.listenAddress = "0.0.0.0:7474";
    http.advertisedAddress = "work.orb.local:7474";
  };

  # Serves ~/projects at http://<hostname>.orb.local/ (one path per app,
  # e.g. /planet-wars/). Runs as duncanbrown so it can read the 700-mode
  # home directory; this is a single-user dev VM, so that's fine.
  services.nginx = {
    enable = true;
    user = "duncanbrown";
    virtualHosts."${config.networking.hostName}.orb.local" = {
      default = true;
      root = "/home/duncanbrown/projects";
      extraConfig = ''
        autoindex on;
      '';
    };
  };
  # The nginx unit hardening hides /home by default (ProtectHome=true);
  # relax it to read-only so nginx can serve ~/projects.
  systemd.services.nginx.serviceConfig.ProtectHome = "read-only";

  # 80 nginx, 4096 opencode web UI, 7474/7687 neo4j
  networking.firewall.allowedTCPPorts = [ 80 4096 7474 7687 ];

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.extraSpecialArgs = { inherit unstable base16-shell; };
  home-manager.users.duncanbrown = import ./home.nix;
}
