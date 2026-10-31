# Roleplay Lite — scope and next steps

Target runtime: **G1R:MP 0.1.8**. This prototype has not yet been accepted on a real 0.1.8 server.

## Included baseline

| Area | Current behavior |
| --- | --- |
| Access | Registration and login in an RML window, password hash, game identity and database approval |
| Character | One persistent character per account with a name, description, ore balance and configurable starting position |
| Chat | Separate chat resource with local IC chat, `/me`, `/do` and global OOC chat |
| Inventory | A saved pickaxe flag and ore balance shown by `/inventory` |
| Minigame | Exactly one mining game: start with `/mine` near a configured ore vein, wait for the random signal, then click or use `/hit` in time; ore is granted only after a confirmed database write |
| Administration | Admin serials in the isolated database and `/approveaccount NAME` |
| Operations | Separate SQL schema, two resources, sample server configuration, MIT license and simulated tests |

The sample spawn and ore vein share a position to make the first local check easy. Operators must deliberately set suitable coordinates for their world. Ore remains the game currency. The `lite_*` tables belong in an isolated database, never in an existing production database.

## Live acceptance still required

1. Prepare an isolated G1R:MP 0.1.8 server and a fresh MySQL database.
2. Check client join, registration, approval, login and one-time character creation.
3. With two clients, check chat range and OOC; verify `/describe` and `/inventory` after a restart.
4. Check mining on early strike, correct strike, late strike, ESC, movement, death, disconnect and resource restart.
5. Review client and server logs for GUI and SQL errors. Reconcile pending writes manually after an interruption; never retry an unknown transaction outcome blindly.

`npm test` checks Lua logic against a simulated runtime and verifies manifests, files, assets and RML IDs. It cannot prove native client behavior or real MySQL persistence. See [Runtime notes](docs/RUNTIME.md) for the API assumptions.

## Possible later additions

Once the baseline works reliably, further activities, a few recipes, camp membership, NPCs or player trading can be planned separately. Player trading requires atomic transactions, confirmed commits and reconnect protection. Housing, camp politics, a large NPC population, editors, a portal and a Discord bot are outside this starter's scope.

## Open source

The standalone Lua, RML, RCSS, SQL and documentation files were created for this sample. Full-gamemode modules, images, sounds, fonts, game binaries and data extracted from the Remake are not included. The code has an MIT license with the attribution in [LICENSE](LICENSE). Review any files or assets you add for private data and redistribution rights.
