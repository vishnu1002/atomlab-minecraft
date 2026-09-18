# minecraft selfhost

Dockerized Minecraft servers on a home host, using
[`itzg/minecraft-server`](https://github.com/itzg/docker-minecraft-server) for
the game servers and the [playit.gg agent](https://github.com/playit-cloud/playit-agent)
for public access (no port forwarding needed).

Only **one server runs at a time** — `docker compose down` before switching.
All stacks share one playit key, so the public address follows whichever
server is up.

Public address (all servers, default port `25565`, no port needed):

```text
hdd-greene.tun.ply.gg
```

## Host specs (`tron`)

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

### mc1 — Vanilla+ Fabric (first server)

- Folder: `mc1/` · services: `mc1` + `playit-mc1` (`172.30.0.5`)
- Type: custom Fabric server, **not** a Modrinth pack — mods pinned individually
  via `MODRINTH_PROJECTS` in `mc1/docker-compose.yml`
- MC `26.1.2` / Fabric · image `itzg/minecraft-server:latest` · Java auto (latest)
- Memory: `5G` + Aikar flags · mode survival / difficulty normal
- Seed: `8500081009970950196` · MOTD `MC1` · `ONLINE_MODE=FALSE`
- Perf mods: lithium, ferrite-core, c2me-fabric · maps: Xaero world+minimap ·
  utility: veinminer, universal-graves, skinrestorer, polymer, moogs structures…
- World: `mc1/data/` (4G, persists on host, git-ignored)
- Client: clean Freesm instance with the same Fabric loader + mod versions

### mc3 — Cave Horror Project (Forge modpack)

- Folder: `mcpak-cave-horror/` · services: `mc3` + `playit-mc3` (`172.30.0.7`)
- Modpack: [Cave Horror Project 1](https://modrinth.com/modpack/cave-horror-project-modpack)
  (permanent link: https://modrinth.com/project/KRCZSt8F), pinned **v3.6**
- MC `1.20.1` / Forge · image `itzg/minecraft-server:java17`
- Memory: `10G` · MOTD `Cave Horror` · `ONLINE_MODE=FALSE`
- World: `mcpak-cave-horror/data/` (persists on host, git-ignored)
- Client: install pack **v3.6** in Freesm, join `hdd-greene.tun.ply.gg`
- Known limit: Simple Voice Chat (UDP `24454`) is up locally but not reachable
  through the TCP playit tunnel — walkie-talkies stay silent remotely

### mc4 — Prominence II (Fabric modpack)

- Folder: `mcpak-prominence-2/` · services: `mc4` + `playit-mc4` (`172.30.0.8`)
- Modpack: [Prominence II – Hasturian Era](https://modrinth.com/modpack/prominence-2-fabric)
  (permanent link: https://modrinth.com/project/EGs3lC8D), pinned **v4.1.0**
- MC `1.20.1` / Fabric · image `itzg/minecraft-server:java17`
- Memory: `10G` · MOTD `Prominence 2` · `ONLINE_MODE=FALSE`
- World: `mcpak-prominence-2/data/` (created on first start, git-ignored)
- Client: install pack **v4.1.0** in Freesm, join `hdd-greene.tun.ply.gg`

## How it works

- **Shared key:** repo-root `.env` holds the single playit `SECRET_KEY`.
  Each stack's playit service reads it via `env_file: ../.env`
  (see `.env.example` for the template). No per-folder `.env` files.
- **Networking:** each stack has its own bridge (`172.30.0.0/24`, fixed IPs
  `.5/.7/.8`); the playit sidecar uses `network_mode: service:<game>` and
  starts only once the game is `healthy` (`mc-monitor` healthcheck).
- **Persistence:** `*/data/` bind-mounts hold worlds, configs, `server.properties`,
  RCON password. Ignored in git, never deleted on `down` — progress survives
  restarts and server switches.

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
loader + mods, then Multiplayer → Add Server → `hdd-greene.tun.ply.gg`.
(`ONLINE_MODE=FALSE`, so any username works.)

## Troubleshooting

- `Server is still starting! Please wait` — joined during boot; wait for
  `Done (...)!` in the logs and reconnect.
- `Can't keep up! ...` once after startup is normal for big packs; only
  investigate if it repeats constantly (check RAM via `free -h`, `docker stats`).
- `LanServerPinger: Network is unreachable` — harmless in Docker.
- Playit `failed ... Network unreachable` on an IPv6 address then success on
  IPv4 — normal fallback. Occasional `SessionNotSetup` during handshake is
  transient; steady state is `tunnel running, 1 tunnels registered`.
- The public address lives in the [playit dashboard](https://playit.gg), not in
  container logs — the agent only logs `1 tunnels registered`.
- Live log viewer: Dozzle on `:8888` (if running).
