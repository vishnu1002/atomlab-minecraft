#!/usr/bin/env bash
# Manual interactive backup for atomlab-minecraft servers.
# Run with no flags: ./backup.sh  (everything is asked via menu)
# Backs up only world + settings (mods/libraries reinstall on `docker compose up`).
# Output: ./backup/<stack>-DD-MM-YYYY.tar.gz (git-ignored)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
REPO_NAME="$(basename "$REPO_ROOT")"
BACKUP_ROOT="$REPO_ROOT/backup"
DATE="$(date +%d-%m-%Y)"

STACKS=("mc1" "mcpak-cave-horror" "mcpak-prominence-2")

container_for() {
  case "$1" in
    mc1) echo "mc1" ;;
    mcpak-cave-horror) echo "mc3" ;;
    mcpak-prominence-2) echo "mc4" ;;
  esac
}

backup_one() {
  local stack="$1"
  local data_dir="$REPO_ROOT/$stack/data"
  local container
  container="$(container_for "$stack")"

  if [ ! -d "$data_dir/world" ]; then
    echo ">> $stack: no data/world found, skipping (server never started?)."
    return 0
  fi

  local backup_file="$BACKUP_ROOT/${stack}-${DATE}.tar.gz"

  if [ -f "$backup_file" ]; then
    local ans
    read -r -p ">> $stack: $backup_file already exists. Overwrite? [y/N] " ans
    case "$ans" in
      y|Y|yes|YES) ;;
      *) echo ">> $stack: skipped."; return 0 ;;
    esac
  fi

  # Flush world to disk if the server is running (crash-consistent backup).
  if docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "$container"; then
    echo ">> $stack: server '$container' is running, flushing world to disk..."
    if ! docker exec "$container" rcon-cli save-all flush >/dev/null 2>&1; then
      echo "!! $stack: 'save-all flush' failed, aborting this backup to avoid a torn world."
      return 1
    fi
  fi

  # Only world + settings. Everything else (mods/libraries/versions/cache/logs)
  # is redownloaded by itzg/minecraft-server on `docker compose up`.
  local candidates=(
    world
    server.properties
    ops.json
    whitelist.json
    banned-ips.json
    banned-players.json
    usercache.json
    usernamecache.json
    config
    defaultconfigs
    kubejs
  )
  local includes=()
  local item
  for item in "${candidates[@]}"; do
    if [ -e "$data_dir/$item" ]; then
      includes+=("$item")
    fi
  done

  if [ "${#includes[@]}" -eq 0 ]; then
    echo ">> $stack: nothing to back up, skipping."
    return 0
  fi

  mkdir -p "$BACKUP_ROOT"
  echo ">> $stack: saving ${includes[*]}"
  echo "   -> $backup_file"
  tar -czf "$backup_file" -C "$data_dir" "${includes[@]}"
  du -h "$backup_file"
  echo ">> $stack: done. File is in ./backup/: $(basename "$backup_file")"
}

echo "=== $REPO_NAME manual backup ==="
echo "Saves world + settings only (mods reinstall via docker compose up)."
echo ""
echo "Which server to back up?"
echo "  1) mc1"
echo "  2) mcpak-cave-horror"
echo "  3) mcpak-prominence-2"
echo "  4) all"
echo ""
choice=""
read -r -p "Enter choice [1-4]: " choice

targets=()
case "$choice" in
  1) targets=("mc1") ;;
  2) targets=("mcpak-cave-horror") ;;
  3) targets=("mcpak-prominence-2") ;;
  4) targets=("${STACKS[@]}") ;;
  *) echo "Invalid choice, aborting."; exit 1 ;;
esac

echo ""
echo "Destination: $BACKUP_ROOT/<stack>-$DATE.tar.gz"
confirm=""
read -r -p "Proceed with [${targets[*]}]? [y/N] " confirm
case "$confirm" in
  y|Y|yes|YES) ;;
  *) echo "Aborted."; exit 0 ;;
esac
echo ""

failed=0
t=""
for t in "${targets[@]}"; do
  if ! backup_one "$t"; then
    failed=1
  fi
  echo ""
done

if [ "$failed" -ne 0 ]; then
  echo "Finished with errors (see above)."
  exit 1
fi
echo "All done."
echo "Restore: docker compose down && tar -xzf <backup>.tar.gz -C <stack>/data/ && docker compose up -d"
