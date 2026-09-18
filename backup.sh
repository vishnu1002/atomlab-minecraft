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
    echo "[INFO] $stack: no data/world found, skipping (server never started?)."
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
    echo "[INFO] $stack: server '$container' is running, flushing world to disk..."
    if ! docker exec "$container" rcon-cli save-all flush >/dev/null 2>&1; then
      echo "[ERROR] $stack: 'save-all flush' failed, aborting this backup to avoid a torn world."
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
    echo "[INFO] $stack: nothing to back up, skipping."
    return 0
  fi

  mkdir -p "$BACKUP_ROOT"
  echo "[INFO] $stack: ${includes[*]}"

  # Progress + speed: stream tar through a byte counter (progress %) into
  # pigz (parallel gzip, same .tar.gz format) with gzip fallback.
  local total=0
  total=$(du -scb "${includes[@]/#/$data_dir/}" 2>/dev/null | tail -n 1 | cut -f1)
  local compressor="gzip"
  if command -v pigz >/dev/null 2>&1; then
    compressor="pigz"
  fi

  if command -v python3 >/dev/null 2>&1 && [ "${total:-0}" -gt 0 ]; then
    tar -cf - -C "$data_dir" "${includes[@]}" \
      | python3 -c '
import os, sys, time
total = int(sys.argv[1])
label = sys.argv[2]
start = time.time()
counted = 0
last = 0.0
def fmt(b):
    f = float(b)
    for u in ["B", "K", "M", "G", "T"]:
        if f < 1024 or u == "T":
            return f"{f:.1f}{u}"
        f /= 1024
inp = sys.stdin.buffer
out = sys.stdout.buffer
try:
    while True:
        chunk = inp.read(1024 * 1024)
        if not chunk:
            break
        out.write(chunk)
        counted += len(chunk)
        now = time.time()
        if now - last >= 0.5:
            last = now
            pct = min(100.0, counted * 100.0 / total) if total > 0 else 0.0
            sys.stderr.write(f"\r[PROGRESS] {label}: {fmt(counted)} / ~{fmt(total)} ({pct:.0f}%)")
            sys.stderr.flush()
except BrokenPipeError:
    pass
sys.stderr.write(f"\r[PROGRESS] {label}: {fmt(counted)} / ~{fmt(total)} (100%)\n")
sys.stderr.flush()
' "$total" "$(basename "$backup_file")" \
      | "$compressor" -c > "$backup_file"
  else
    tar -czf "$backup_file" -C "$data_dir" "${includes[@]}"
  fi
  size=$(du -h "$backup_file" | cut -f1)
  echo "[DONE] $backup_file [$size]"
}

echo "=== $REPO_NAME manual backup ==="
echo "Saves world + settings only"
echo ""
echo "Which world to back up?"
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
if [ "${#targets[@]}" -eq 1 ]; then
  echo "Destination: $BACKUP_ROOT/${targets[0]}-$DATE.tar.gz"
else
  echo "Destination:"
  for t in "${targets[@]}"; do
    echo "  $BACKUP_ROOT/${t}-$DATE.tar.gz"
  done
fi
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
echo "All backup done."
if [ "${#targets[@]}" -eq 1 ]; then
  echo "Restore: cd ${targets[0]} && docker compose down && tar -xzf ../backup/${targets[0]}-${DATE}.tar.gz -C data/ && docker compose up -d"
else
  echo "Restore: cd <stack> && docker compose down && tar -xzf ../backup/<stack>-DD-MM-YYYY.tar.gz -C data/ && docker compose up -d"
fi
