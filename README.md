# Atomlab Minecraft Server

Dockerized Minecraft servers on a home host, using
[`itzg/minecraft-server`](https://github.com/itzg/docker-minecraft-server) for
the game servers and the [playit.gg agent](https://github.com/playit-cloud/playit-agent)
for public access (no port forwarding needed).

Each Minecraft stack is independent and runs its own compose project.
`mc3` (live) and `mcpak-biohazard` use separate playit agent keys + tunnels
(repo-root `.env` vs `mcpak-biohazard/.env`), so the public addresses differ
per server. Keep in mind the host has 14 GiB RAM: `mc3` 4G + `mcpak1` 4G fit
side by side, but `mc2` (5G) / `mc6` (5G) / `mcpak2` (10G) are meant to
replace, not join, what's already running.

## Server specs

| Component | Detail |
|---|---|
| OS | Ubuntu 26.04.1 LTS, kernel 7.0.0-29-generic (x86_64) |
| CPU | AMD Ryzen 5 3550H — 4 cores / 8 threads, 2.1 GHz base |
| RAM | 14 GiB (+ 4 GiB swap) |
| GPU | NVIDIA GTX 1650 Mobile Max-Q + AMD Radeon Vega iGPU (dedicated MC servers don't use a GPU) |
| Docker | 29.8.1, Compose v5.5.1 |

Memory budget: `mc1` 5G, `mc2` 10G Fabric, `mc3` 4G, `mcpak2` 10G, `mcpak1` 4G —
`mc3` is the running one right now; starting more than one big stack at once
can OOM/swap-stall the 14 GiB host.

## Docs

Configure future servers from these references:

**itzg/minecraft-server** — https://github.com/itzg/docker-minecraft-server/tree/master/docs
(rendered mirror: https://docker-minecraft-server.readthedocs.io/en/latest/)

- `docs/configuration/` – server.properties, difficulty, memory, JVM/Aikar flags
- `docs/mods-and-plugins/` – `TYPE: FABRIC`, `MODRINTH_*`, modpack setup
- `docs/types-and-platforms/` – `FABRIC`, `FORGE`, `MODRINTH`, etc.
- `docs/versions/` – `VERSION` pinning
- `docs/variables.md` – full env var list
- `docs/data-directory.md` – `/data` volume layout
- `docs/sending-commands/` – RCON / console (`CREATE_CONSOLE_IN_PIPE`)

**playit.gg agent (tunnel)** — https://github.com/playit-cloud/playit-agent

- Docker usage: `docker run --net=host -e SECRET_KEY=<key> ghcr.io/playit-cloud/playit-agent`
- Generate a key: https://playit.gg/account/setup/wizard/new-account/docker/docker-name
- Dashboard (tunnels, addresses): https://playit.gg
- Here the agent runs as a sidecar (`network_mode: service:<game>`) sharing the
  game container's network, so the tunnel reaches `25565` with no published ports.
- Healthcheck: the official image ships **no** `HEALTHCHECK`, so each compose
  defines `test: ["CMD", "pgrep", "playitd"]` (30s/5s/3) — this is why
  `docker compose ps` takes ~30 s before a playit sidecar shows `healthy`.
- `network_mode: service:<game>` means the playit sidecar can only start once
  the game container exists; it must NOT be removed when running the stack.
- No static container IPs: each stack uses its default Compose network and the
  sidecar talks to the game over localhost; Docker DNS resolves services
  (`mc1`, `mcpak2`, `mcpak1`) by name if ever needed. Tested working (player join +
  tunnel traffic verified after dropping the old `172.30.0.0/24` assignments).

## Servers

| Server | Folder | Modpack | MC / Loader | Memory |
|---|---|---|---|---|
| mc1 Vanilla+ | `mc1/` | Custom Fabric set, pinned via `MODRINTH_PROJECTS` (perf: lithium, ferrite-core, c2me; maps: Xaero; utility: veinminer, graves, skinrestorer…), seed `8500081009970950196` | 26.1.2 / Fabric (`itzg/minecraft-server:latest`) | 5G + Aikar flags |
| mc2 Vanilla+ | `mc2/` | Fabric with Chunky + Distant Horizons | 26.3 / Fabric (`itzg/minecraft-server:latest`) | 10G |
| mc3 Vanilla | `mc3/` | None (pure vanilla, `TYPE: VANILLA`, seed `-1718501946501227358`) — **currently live** | 26.3 / Vanilla (`itzg/minecraft-server:latest`) | 4G + JVM_OPTS |
| mcpak2 Prominence 2 | `mcpak-prominence2/` | [Prominence II v4.1.0](https://modrinth.com/modpack/prominence-2-fabric) | 1.20.1 / Fabric (`itzg/minecraft-server:java17`) | 10G |
| mcpak1 Biohazard | `mcpak-biohazard/` | [Biohazard: Project Genesis V0.4.6.1](https://www.curseforge.com/minecraft/modpacks/biohazard-project-genesis) (official server pack, File ID `8869015`, ServerStarterJar via `start.sh`) | 1.20.1 / Forge (`itzg/minecraft-server:java17`) | 4G (`data/variables.txt` JAVA_ARGS) |

All servers run survival, `ONLINE_MODE=FALSE` (any username works). Worlds live
in each stack's `data/` dir (git-ignored, survives restarts and switches).
reachable through the TCP playit tunnel.

## Setup

Prerequisites: Docker + Compose plugin, a playit.gg account with a tunnel +
agent key, Freesm launcher for clients.

```bash
# one-time: playit keys — repo-root .env for mc3 (and legacy stacks),
# mcpak-biohazard/.env for the Biohazard stack (its own agent/tunnel)
cp .env.example .env   # fill in SECRET_KEY

# start one server (mc1, mc2, mcpak-prominence-2 or mcpak-biohazard)
cd mc2
docker compose up -d

# follow startup (Forge packs take ~2 min to reach "Done (...)!")
docker logs -f mc2        
docker attach mc2         # live server console (detach: Ctrl-p Ctrl-q)
```

Switching servers:

```bash
docker compose down   # in the current stack
cd ../mcpak-prominence-2 && docker compose up -d
```

## Backup & restore

Manual backup, no flags — everything is asked via menu:

```bash
./backup.sh
# 1) mc1  2) mc2  3) mcpak-prominence-2  4) mcpak-biohazard  5) all
```

Saves only `world/` + settings (`server.properties`, `ops.json`,
`whitelist.json`, `banned-*.json`, `usercache.json`, `config/`,
plus `defaultconfigs/` / `kubejs/` where present). `mods/`, `libraries/`,
`versions/`, `cache/`, `logs/` are skipped — they reinstall on
`docker compose up`. Output: `backup/<stack>-DD-MM-YYYY.tar.gz`
(git-ignored). Safe to run while the server is up (does
`save-all flush` first; aborts that stack if the flush fails).
Compression uses `pigz` (parallel gzip, same `.tar.gz` format) when
available with `gzip` fallback, and a live progress line is shown:

```text
[PROGRESS] mc1-18-09-2026.tar.gz: 1.2G / ~3.9G (31%)
```

Restore (compose files come from git, only data comes from the backup):

```bash
cd mc2   # or mc1 / mcpak-prominence-2 / mcpak-biohazard
docker compose down
tar -xzf ../backup/mc2-18-09-2026.tar.gz -C data/
docker compose up -d
```

Client: create a clean Freesm instance per server with the matching pack/
loader + mods (plain vanilla 26.3 for mc2), then Multiplayer → Add Server → your tunnel address.
