# Upgrading from 0.1.0 to 0.2.0

Use matching **G1R:MP 0.1.9** client and server packages. The example listing
version `0.2.0` is the gamemode version, not the multiplayer runtime version.

1. Stop the test server after pending writes complete. Back up its database,
   resource directories and private settings.
2. Replace both `resources/roleplay_lite` and `resources/chat` with the complete
   new versions. Keep only one RP resource enabled; do not autostart an archived copy.
3. Transfer your database, spawn and mining settings from the old
   `server/config.lua` to `server/config/defaults.lua`. Preserve the environment
   variable `G1R_LITE_DB_PASSWORD`; do not copy a password into public files.
4. Review the new `whisperRange`, `shoutRange`, `lookRange` and
   `socialCooldownMs` settings. Ranges are in metres.
5. Keep the existing `lite_*` tables. **There is no schema migration for this update.**
   Do not reimport the fresh-install SQL file or reset character data.
6. Keep `autostart=chat,roleplay_lite`. Start the server, then check login,
   existing descriptions and ore, mining, `/cancelmine`, and the new RP commands
   with two clients. Include reconnect and resource restart.

The former `server/main.lua`, `server/config.lua`, `server/database.lua` and
flat UI file locations have been replaced by modules and `ui/screens` /
`ui/styles`. Install the manifest and files together. Internal `lite:*` events,
table names, existing English commands and mining rewards are preserved.
