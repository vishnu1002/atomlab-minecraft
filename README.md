# Atomlab Minecraft Server

Dockerized Minecraft servers on a home host, using
[`itzg/minecraft-server`](https://github.com/itzg/docker-minecraft-server) for
the game servers and the [playit.gg agent](https://github.com/playit-cloud/playit-agent)
for public access (no port forwarding needed).

Only **one server runs at a time** — `docker compose down` before switching.
All stacks share one playit key, so the public address follows whichever
server is up.

Public address (all servers, default port `25565`, no port needed) — find
yours in the [playit dashboard](https://playit.gg/account/tunnels) under Tunnels:

```text
<your-address>.playit.gg
```

## Server specs

| Component | Detail |
|---|---|
| OS | Ubuntu 26.04.1 LTS, kernel 7.0.0-29-generic (x86_64) |
| CPU | AMD Ryzen 5 3550H — 4 cores / 8 threads, 2.1 GHz base |
| RAM | 14 GiB (+ 4 GiB swap) |
| GPU | NVIDIA GTX 1650 Mobile Max-Q + AMD Radeon Vega iGPU (dedicated MC servers don't use a GPU) |
| Docker | 29.8.1, Compose v5.5.1 |

Memory budget: `mc1` takes 5G, modpacks 10G each — but only one runs at a
time, so peak usage stays ~10G for the game + system headroom.

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

## Servers

| Server | Folder | Modpack | MC / Loader | Memory |
|---|---|---|---|---|
| mc1 Vanilla+ | `mc1/` | Custom Fabric set, pinned via `MODRINTH_PROJECTS` (perf: lithium, ferrite-core, c2me; maps: Xaero; utility: veinminer, graves, skinrestorer…), seed `8500081009970950196` | 26.1.2 / Fabric (`itzg/minecraft-server:latest`) | 5G + Aikar flags |
| mc3 Cave Horror | `mcpak-cave-horror/` | [Cave Horror Project 1 v3.6](https://modrinth.com/modpack/cave-horror-project-modpack) ([project page](https://modrinth.com/project/KRCZSt8F)) | 1.20.1 / Forge (`itzg/minecraft-server:java17`) | 10G |
| mc4 Prominence 2 | `mcpak-prominence-2/` | [Prominence II v4.1.0](https://modrinth.com/modpack/prominence-2-fabric) ([project page](https://modrinth.com/project/EGs3lC8D)) | 1.20.1 / Fabric (`itzg/minecraft-server:java17`) | 10G |

All servers run survival, `ONLINE_MODE=FALSE` (any username works). Worlds live
in each stack's `data/` dir (git-ignored, survives restarts and switches).
Cave Horror note: Simple Voice Chat (UDP `24454`) runs locally but isn't
reachable through the TCP playit tunnel.

## Setup

Prerequisites: Docker + Compose plugin, a playit.gg account with a tunnel +
agent key, Freesm launcher for clients.

```bash
# one-time: put the playit agent key in the repo root
cp .env.example .env   # fill in SECRET_KEY

# start one server (mc1, mcpak-cave-horror or mcpak-prominence-2)
cd mc1
docker compose up -d

# follow startup (Forge packs take ~2 min to reach "Done (...)!")
docker logs -f mc1        # mc3 / mc4 in the modpack stacks
docker attach mc1         # live server console (detach: Ctrl-p Ctrl-q)
```

Switching servers:

```bash
docker compose down   # in the current stack
cd ../mcpak-cave-horror && docker compose up -d
```

Client: create a clean Freesm instance per server with the matching pack/
loader + mods, then Multiplayer → Add Server → your tunnel address.
