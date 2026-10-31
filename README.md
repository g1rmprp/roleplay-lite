# Roleplay Lite

Roleplay Lite is a small, standalone, English-language roleplay starter for **G1R:MP 0.1.9**. It includes registration and account approval, one persistent character per account, nearby character inspection, RP chat and dice, and one ore-mining minigame. The source code is available under the [MIT license](LICENSE). Gothic 1 Remake and the G1R:MP runtime must be obtained separately.

**Gamemode version: 0.2.0. Runtime target: G1R:MP 0.1.9.** This is an early prototype. Lua tests use a simulated runtime; the client, server and MySQL flow have not yet been verified on a real 0.1.9 installation. Treat it as a starting point, not a production-ready server. See [what changed](CHANGELOG.md) and [how to upgrade](docs/UPGRADING.md).

## Quick start on an isolated test server

1. Set up matching G1R:MP 0.1.9 server and client packages. Copy `resources/chat` and `resources/roleplay_lite` from this project into the server's `resources` directory. Run only one RP resource on that server.
2. Create a **new, empty** MySQL database named `roleplay_lite` with `utf8mb4`, then run [roleplay_lite.sql](resources/roleplay_lite/database/roleplay_lite.sql). Never run this schema against an existing or production database.
3. Set the database host and user, spawn position and mining position in [server/config/defaults.lua](resources/roleplay_lite/server/config/defaults.lua). Provide the database password through the server environment variable `G1R_LITE_DB_PASSWORD`. The example positions put the mine next to the spawn solely to simplify the first local test.
4. Use [serverconf.example.cfg](deployment/serverconf.example.cfg) as a starting point for a separate test server. Its resource list must read `autostart=chat,roleplay_lite`.
5. Start the server and register with a test client. New accounts wait for approval. To bootstrap the first administrator, display your own game serial with `/serial` in the test client and run this **only in the new test database**: `INSERT INTO lite_admins (game_serial) VALUES ('YOUR_TEST_SERIAL');`. That administrator can approve an account with `/approveaccount USERNAME`. Log in again and create a character.
6. Near the configured ore vein, use `/mine`. When the window signals the opening, press **Strike!** or use `/hit`. After the database confirms the credit, `/inventory` shows the updated ore balance.

The password is entered in the access window. Do not send passwords as chat commands. Keep real server configuration and database credentials out of a public repository.

## Commands

| Command | Purpose |
| --- | --- |
| `/rphelp` | Show the short command list |
| `/inventory` | Show the pickaxe and ore balance |
| `/mine`, `/hit`, `/cancelmine` | Start mining, strike during the opening or cancel |
| `/players` | List active character IDs and names |
| `/look ID` | Read a nearby character's description |
| `/me`, `/do` | Send nearby RP actions |
| `/whisper ID TEXT` | Send a private message to a nearby character |
| `/shout TEXT` | Speak across a larger local range |
| `/roll [SIDES]` | Roll a server-generated die locally; 2-1000 sides, default 100 |
| `/ooc` | Send an OOC message to logged-in players |
| `/describe TEXT` | Save the character description |
| `/serial` | Show your game serial for local admin setup |
| `/approveaccount NAME` | Approve a pending account with admin permission |

Default ranges are 20 metres for speech and actions, 4 for whispers, 40 for
shouts and 5 for character inspection. `/look` checks proximity, not line of
sight. A whisper is sent only to its sender and recipient; `/ooc` is global to
logged-in characters. Social actions share a one-second cooldown. Ranges and
the cooldown are configurable in `server/config/defaults.lua`.

## Development and scope

Run `npm install` and `npm test` from this directory. The test command checks the Lua logic with simulated APIs and validates resource manifests, assets, RML IDs and server load order. It does not need a game client or MySQL. See [the folder and module guide](docs/STRUCTURE.md), [runtime notes](docs/RUNTIME.md) and [roadmap](docs/ROADMAP.md).

Roleplay Lite has its own `lite_*` tables and must not share a production game database. It does not include a full production gamemode, third-party assets, a portal, a Discord bot or a world population. Keep the sample small and adapt it to your own server.
