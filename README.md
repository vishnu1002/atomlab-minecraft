# minecraft selfhost

Dockerized Minecraft servers using `itzg/minecraft-server` + `playit.gg` tunnel.

## Upstream docs

Full configuration reference for future `docker-compose` work:

- https://github.com/itzg/docker-minecraft-server/tree/master/docs

Most useful sections:
- `docs/configuration/` – server.properties, difficulty, memory, JVM flags
- `docs/mods-and-plugins/` – `TYPE: FABRIC`, `MODRINTH_*`, modpack setup
- `docs/types-and-platforms/` – `FABRIC`, `MODRINTH`, `VANILLA`, etc.
- `docs/versions/` – `VERSION` pinning
- `docs/variables.md` – full env var list
- `docs/data-directory.md` – `/data` volume layout
- `docs/sending-commands/` – RCON / console (`CREATE_CONSOLE_IN_PIPE`)

## Servers

One instance at a time — `docker compose down` before switching. All stacks
share the same playit key, so the public address follows whichever is up.

| Server | Address | Pack | MC/Loader |
|---|---|---|---|
| mc1 Vanilla+ | `hdd-greene.tun.ply.gg` (default port 25565, no port needed) | Fabric + pinned Modrinth mods | 26.1.2 Fabric |
| mc3 Cave Horror | `hdd-greene.tun.ply.gg` (default port 25565, no port needed) | Cave Horror Project v3.6 | 1.20.1 Forge |
| mc4 Prominence 2 | `hdd-greene.tun.ply.gg` (default port 25565, no port needed) | Prominence II v4.1.0 | 1.20.1 Fabric |

Client note: install the matching modpack version (clean Freesm instance per
server works well), then Multiplayer → Add Server → paste address as-is.
World data lives server-side in each stack's `data/` dir, so progress persists.

## Layout

Each server is self-contained (compose + `data/` + own `.env`):

- `mc1/` – Vanilla+ Fabric + `playit-mc1` tunnel, world in `mc1/data/`
- `mcpak-cave-horror/` – Cave Horror modpack stack (`mc3`), world in `data/`
- `mcpak-prominence-2/` – Prominence II modpack stack (`mc4`), world in `data/`
- `*/data/` – runtime `/data` mounts (ignored in git, worlds persist on host)
- `*/.env` – playit `SECRET_KEY` (ignored, see `*/.env.example`)

## Quick start

```bash
cd mc1  # or mcpak-cave-horror / mcpak-prominence-2 (only one at a time)
cp .env.example .env  # fill in playit key (shared across stacks)
docker compose up -d
docker logs -f mc1  # mc3 / mc4 in the modpack stacks
docker attach mc1  # server console
```
