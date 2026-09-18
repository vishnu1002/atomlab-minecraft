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

## Layout

- `docker-compose.yml` – active `mc1` (Fabric) + `playit-mc1` tunnel
- `docker-compose.yml.old` – multi-server template (`mc1/mc2/mc3` via profiles)
- `mcpak-alaskan-wilderness/` – standalone `MODRINTH` modpack stack
- `mcpak-cave-horror/` – standalone `MODRINTH` modpack stack
- `mc1/`, `mcpak-*/data/` – runtime `/data` mounts (ignored in git)
- `.env` – playit `SECRET_KEY`s (ignored, see `.env.example`)

## Quick start

```bash
cp .env.example .env  # fill in playit keys
docker compose up -d
docker logs -f mc1
docker attach mc1  # server console
```
