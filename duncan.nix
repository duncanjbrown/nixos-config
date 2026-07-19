{ config, pkgs, modulesPath, ... }:

let
  home-manager = builtins.fetchTarball "https://github.com/nix-community/home-manager/archive/release-25.11.tar.gz";
  unstable = import <nixos-unstable> { config.allowUnfree = true; };
  base16-shell = builtins.fetchTarball {
    url = "https://github.com/chriskempson/base16-shell/archive/588691ba71b47e75793ed9edfcfaa058326a6f41.tar.gz";
    sha256 = "0w8g0gyvahkm6zqlwy6lw9ac3hragwh3hvrnvvq2082hdyq4bksz";
  };
in
{
  imports = [
    (import "${home-manager}/nixos")
  ];
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  
  systemd.units."sys-kernel-debug.mount".enable = false;

  programs.neovim.package = unstable.neovim-unwrapped;

  programs.zsh.enable = true;
  users.users.duncanbrown.shell = pkgs.zsh;
  nixpkgs.config.permittedInsecurePackages = [
    "docker-28.5.2"
  ];

  services.postgresql = {
    enable = true;
    authentication = pkgs.lib.mkOverride 10 ''
      #type database  DBuser  auth-method
      local all       all     trust
      host  all       all     127.0.0.1/32   trust
      host  all       all     ::1/128        trust
      '';
    settings.port = 5434;
  };

  virtualisation.docker.enable = true;

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
      fzf
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
      tmux
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
    ];

    home.homeDirectory = "/home/duncanbrown";

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
        export EDITOR=nvim
        export PAGER=less
        export XDG_CONFIG_HOME="$HOME/.config"

        source "$HOME/.zsh/aliases"
        source "$HOME/.zsh/functions"
        source "$HOME/.zsh/base16"
        source "$HOME/.zsh/fzf"
        source "$HOME/.zsh/ssh"

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
