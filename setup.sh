#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/duncanjbrown/nixos-config.git"
REPO_DIR="$HOME/nixos-config"
NIXOS_DIR="/etc/nixos"
SYMLINK_NAME="duncan"

info() { echo -e "\033[1;34m==>\033[0m $*"; }
warn() { echo -e "\033[1;33m==>\033[0m $*"; }
error() { echo -e "\033[1;31m==>\033[0m $*" >&2; exit 1; }

if [ "$(whoami)" = "root" ]; then
  error "Run this script as your user (duncanbrown), not as root."
fi

if ! command -v git &>/dev/null; then
  info "git not found, entering nix-shell to get it..."
  exec nix-shell -p git --run "bash $0"
fi

if [ ! -d "$REPO_DIR" ]; then
  info "Cloning nixos-config repo..."
  git clone "$REPO_URL" "$REPO_DIR"
else
  info "Repo already exists at $REPO_DIR, pulling latest..."
  git -C "$REPO_DIR" pull
fi

if [ ! -L "$NIXOS_DIR/$SYMLINK_NAME" ] && [ ! -d "$NIXOS_DIR/$SYMLINK_NAME" ]; then
  info "Symlinking $REPO_DIR -> $NIXOS_DIR/$SYMLINK_NAME..."
  sudo ln -s "$REPO_DIR" "$NIXOS_DIR/$SYMLINK_NAME"
else
  info "Symlink $NIXOS_DIR/$SYMLINK_NAME already exists, skipping."
fi

CONFIG_FILE="$NIXOS_DIR/configuration.nix"
INCLUDE_LINE="./duncan/duncan.nix"

if ! grep -qF "$INCLUDE_LINE" "$CONFIG_FILE" 2>/dev/null; then
  info "Adding $INCLUDE_LINE to $CONFIG_FILE..."
  sudo sed -i "/imports = \[/a\\      $INCLUDE_LINE" "$CONFIG_FILE"
  warn "Please verify $CONFIG_FILE looks correct (the import was added automatically)."
else
  info "$INCLUDE_LINE already present in $CONFIG_FILE, skipping."
fi

info "Adding nixos-unstable channel..."
if ! sudo nix-channel --list | grep -q "^nixos-unstable"; then
  sudo nix-channel --add https://nixos.org/channels/nixos-unstable nixos-unstable
else
  info "nixos-unstable channel already added, skipping."
fi

info "Updating nix channels..."
sudo nix-channel --update

info "Rebuilding NixOS..."
sudo nixos-rebuild switch

warn "gh auth login is interactive — run it manually if you haven't already."
warn "Log out and log back in to pick up shell and group changes."

info "Done!"
