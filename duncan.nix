{ config, pkgs, modulesPath, ... }:

let
  home-manager = builtins.fetchTarball "https://github.com/nix-community/home-manager/archive/release-25.11.tar.gz";
in
{
  imports = [
    (import "${home-manager}/nixos")
  ];

  users.users.duncanbrown.shell = pkgs.zsh;

  home-manager.users.duncanbrown = { pkgs, lib, config, ... }: {
    home.stateVersion = "25.11";  # match your nixos version

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
    ];

    home.homeDirectory = "/home/duncanbrown";

    # Satisfy fzf.vim
    home.file.".fzf".source = "${pkgs.fzf}/share/vim-plugins/fzf";

    programs.zsh = {
      enable = true;
      dotDir = "${config.home.homeDirectory}/.config/zsh";
      initContent = ''
        export EDITOR=nvim
        source "/home/duncanbrown/.zsh/aliases"
        source "/home/duncanbrown/.zsh/functions"
        source "/home/duncanbrown/.zsh/base16"
        source "/home/duncanbrown/.zsh/fzf"
        source "/home/duncanbrown/.zsh/ssh"
      '';
      oh-my-zsh = {
        enable = true;
        plugins = [ "git" "fzf" ];
        theme = "robbyrussell";
      };
    };

    programs.neovim = {
      enable = true;
      defaultEditor = true;
    };

    programs.git = {
      enable = true;
      settings.user.name = "Duncan Brown";
      settings.user.email = "duncan@duncanjbrown.com";
    };

    home.activation.dotfiles = lib.hm.dag.entryAfter ["writeBoundary"] ''
      if [ ! -d "$HOME/.dotfiles" ]; then
        ${pkgs.git}/bin/git clone https://github.com/duncanjbrown/dotfiles.git "$HOME/.dotfiles"
      fi
      ${pkgs.rcm}/bin/rcup -d "$HOME/.dotfiles"
    '';
  };
}