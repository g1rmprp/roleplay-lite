# Folder and module guide

```text
roleplay-lite/
  deployment/                 example server configuration
  docs/                       runtime, upgrade and contributor guides
  resources/
    chat/                     separate RML chat and command allowlist
    roleplay_lite/
      client/ui.lua           access and mining UI lifecycle
      database/               fresh-install schema
      server/
        config/defaults.lua   database, spawn, mining and chat settings
        core/                 shared state, validation, database, help, lifecycle
        accounts/             registration, approval wait and login
        characters/           load/create character, inventory and description
        gameplay/             mining state machine and rewards
        social/               chat delivery, profiles, whispers and dice
        admin/                account approval
      ui/
        screens/              access.rml and mine.rml
        styles/               shared RCSS
      scripts.xml             authoritative load order and client downloads
  scripts/                    development test runner
  tests/
    helpers/server_files.lua  ordered server loader used by tests
    run.lua                   server/API simulations and gameplay regressions
    client.lua                UI input lifecycle regressions
    manifest.test.mjs         manifest, asset and load-order validation
```

## Module boundaries

`core/state.lua` owns the shared `LITE` session namespace and reusable validation.
Other modules use explicit local aliases for the helpers they need. Persistent
queries go through `LITE_DB`; there is no copied database implementation in each feature.

The manifest loads configuration and core helpers first, then character/account
features and gameplay. Lifecycle registration comes last, after the modules it calls.
The client UI and chat resource keep their own runtime contexts.

## Adding a feature

1. Put server logic under the closest existing responsibility. Keep remote input
   validation, permissions and state changes on the server.
2. Add a server file to `scripts.xml` and `tests/helpers/server_files.lua` in the same
   position. The automated load-order check compares these lists.
3. Register player commands in their feature module. Add public chat commands to
   the allowlist in `resources/chat/server.lua` and describe them in `/rphelp` and README.
4. Register downloadable screens and styles in the manifest. RML asset paths are
   relative to the screen, not the resource root.
5. Add a regression for important behavior and failure cases. Run `npm test`.

Keep code, documentation, diagnostics and player-facing text in English.
Use Lua 5.1 syntax. Do not infer native function names; check the documented
side, signature and target-version availability first.
