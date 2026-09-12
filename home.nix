# home-manager configuration for duncanbrown: packages, shell, editor, git
# and the opencode web UI user service.
# unstable and base16-shell come from the flake via extraSpecialArgs.

{ config, lib, pkgs, unstable, base16-shell, ... }:

{
  home.stateVersion = "25.11";  # match your nixos version

  home.packages = with pkgs; [
    ripgrep
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
    silver-searcher
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
    unstable.claude-code
  ];

  # opencode web UI daemon: runs as a user service so it shares the
  # interactive CLI's auth/config/sessions under ~. Started at boot via
  # linger (set in configuration.nix).
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

  # Keybindings and completion; ~/.zsh/fzf (dotfiles) adds colours and ^P.
  programs.fzf.enable = true;

  programs.zsh = {
    enable = true;
    dotDir = "${config.home.homeDirectory}/.config/zsh";
    syntaxHighlighting.enable = true;
    initContent = ''
      export PAGER=less

      for rc in aliases functions base16 fzf ssh; do
        [ -f "$HOME/.zsh/$rc" ] && source "$HOME/.zsh/$rc"
      done

      eval "$(${pkgs.fnm}/bin/fnm env --use-on-cd --shell zsh)"

      function precmd () {
        echo -ne "\033]0;''${PWD}\007"
      }
    '';
    oh-my-zsh = {
      enable = true;
      plugins = [ "git" ];
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
    };
  };

  programs.gh = {
    enable = true;
    gitCredentialHelper.enable = true;
    settings.aliases.co = "pr checkout";
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
}
