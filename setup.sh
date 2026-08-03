#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/duncanjbrown/nixos-config.git"
REPO_DIR="$HOME/nixos-config"

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
  git -C "$REPO_DIR" pull --ff-only
fi

info "Rebuilding NixOS from the flake..."
# A fresh VM has no flake support in nix.conf yet; --option covers the first
# build. Afterwards the config's own nix.settings.experimental-features
# applies. --impure: the config reads OrbStack's machine-local
# /etc/nixos/{incus,orbstack}.nix. --sudo: build as user, escalate to
# activate.
nixos-rebuild switch --flake "$REPO_DIR#orb" --impure --sudo \
  --option experimental-features "nix-command flakes"

warn "gh auth login is interactive — run it manually if you haven't already."
warn "Log out and log back in to pick up shell and group changes."

info "Done!"
