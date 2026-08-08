# unstable and base16-shell come from the flake via specialArgs.
{ config, pkgs, modulesPath, unstable, base16-shell, ... }:

{
  imports = [ ./opencode-widget ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.auto-optimise-store = true;
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  systemd.units."sys-kernel-debug.mount".enable = false;

  programs.zsh.enable = true;
  users.users.duncanbrown.shell = pkgs.zsh;
  users.users.duncanbrown.extraGroups = [ "docker" ];
  nixpkgs.config.permittedInsecurePackages = [
    "docker-28.5.2"
  ];

  services.postgresql = {
    enable = true;
    # Single-user dev VM on localhost: trust auth is deliberate.
    # Don't copy this anywhere with real data or multiple users.
    authentication = pkgs.lib.mkOverride 10 ''
      #type database  DBuser  auth-method
      local all       all     trust
      host  all       all     127.0.0.1/32   trust
      host  all       all     ::1/128        trust
      '';
    settings.port = 5434;
  };

  virtualisation.docker.enable = true;

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

  # The opencode web UI daemon runs as a home-manager user service (defined
  # in the home-manager block below); these are the system-level bits it
  # needs. Linger makes the user manager (and the service) start at boot.
  users.users.duncanbrown.linger = true;
  networking.firewall.allowedTCPPorts = [ 80 4096 ];

  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    icu
  ];

  home-manager.users.duncanbrown = { pkgs, lib, config, ... }: {
    home.stateVersion = "25.11";  # match your nixos version
    nixpkgs.config.allowUnfreePredicate = _: true;

    home.packages = with pkgs; [
      ripgrep
      fzf
      rcm
      tmux
      curl
      difftastic
      graphviz
      hugo
      jq
      tig
      wget
      tree
      oh-my-zsh
      silver-searcher
      gh
      base16-universal-manager
      gnumake
      nodejs # to install LSPs
      fnm # reads .nvmrc per-project
      python3 # to install LSPs
      unzip # to install LSPs
      ghostty.terminfo
      awscli2
      imagemagick
      uv
      glow
      gitleaks
      ghc
      cabal-install
      haskell-language-server
      tree-sitter
      gcc
      unstable.opencode
      duc
      zip
      adr-tools
      rich-cli
    ];

    home.homeDirectory = "/home/duncanbrown";

    # opencode web UI daemon: runs as a user service so it shares the
    # interactive CLI's auth/config/sessions under ~. Started at boot via
    # linger (set in the system config above).
    systemd.user.services.opencode = {
      Unit = {
        Description = "opencode web server";
        After = [ "network-online.target" ];
        Wants = [ "network-online.target" ];
      };
      Service = {
        ExecStart = "${unstable.opencode}/bin/opencode serve --hostname 0.0.0.0 --port 4096 --print-logs";
        WorkingDirectory = "%h";
        Restart = "on-failure";
        RestartSec = 5;
        # The user manager's default PATH knows nothing about nix profiles;
        # include the home-manager profile so LSPs/tools installed there work.
        Environment = [
          "PATH=${config.home.profileDirectory}/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin"
        ];
      };
      Install.WantedBy = [ "default.target" ];
    };

    # Satisfy fzf.vim
    home.file.".fzf".source = "${pkgs.fzf}/share/vim-plugins/fzf";

    # base16-shell: provides ~/.zsh/base16's profile_helper.sh and the active theme
    home.file.".config/base16-shell".source = base16-shell;
    home.file.".base16_theme".source = "${base16-shell}/scripts/base16-oceanicnext.sh";

    programs.zsh = {
      enable = true;
      dotDir = "${config.home.homeDirectory}/.config/zsh";
      syntaxHighlighting.enable = true;
      initContent = ''
        export PAGER=less

        for rc in aliases functions base16 fzf ssh; do
          [ -f "$HOME/.zsh/$rc" ] && source "$HOME/.zsh/$rc"
        done

        [ -f "$HOME/.fzf.zsh" ] && source "$HOME/.fzf.zsh"

        eval "$(${pkgs.fnm}/bin/fnm env --use-on-cd --shell zsh)"

        function precmd () {
          echo -ne "\033]0;''${PWD}\007"
        }
      '';
      oh-my-zsh = {
        enable = true;
        plugins = [ "git" "fzf" ];
        custom = "${config.home.homeDirectory}/.dotfiles/oh-my-zsh";
        theme = "gallois-docker";
      };
    };

    programs.neovim = {
      enable = true;
      defaultEditor = true;
      package = unstable.neovim-unwrapped;
    };

    programs.git = {
      enable = true;
      settings = {
        user.name = "Duncan Brown";
        user.email = "duncan@duncanjbrown.com";
        credential."https://github.com".helper = [
          ""
          "!${pkgs.gh}/bin/gh auth git-credential"
        ];
      };
    };

    home.activation.dotfiles = lib.hm.dag.entryAfter ["writeBoundary"] ''
      if [ ! -d "$HOME/.dotfiles" ]; then
        ${pkgs.git}/bin/git clone https://github.com/duncanjbrown/dotfiles.git "$HOME/.dotfiles"
      fi
      # rcup reads $RCRC so EXCLUDES/UNDOTTED apply even before ~/.rcrc exists.
      # -f: replace mismatched files without prompting (default -i is interactive).
      # PATH extras are for hooks/post-up (git clone tpm, tic terminfo, tpm install_plugins).
      export RCRC="$HOME/.dotfiles/rcrc"
      export PATH="${pkgs.rcm}/bin:${pkgs.git}/bin:${pkgs.ncurses}/bin:${pkgs.tmux}/bin:$PATH"
      ${pkgs.rcm}/bin/rcup -f -d "$HOME/.dotfiles"
    '';
  };
}
