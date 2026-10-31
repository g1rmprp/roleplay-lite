# Changelog

## 0.2.0

Target runtime: G1R:MP 0.1.9. The gamemode and runtime have separate version numbers.

- Split the server entry point into core, accounts, characters, gameplay, social and admin modules.
- Separate UI documents under `ui/screens/` from RCSS under `ui/styles/`.
- Add `/players`, nearby `/look`, private `/whisper`, `/shout` and local server-generated `/roll`.
- Add configurable social ranges and a shared one-second social cooldown.
- Add `/cancelmine` and reject hits submitted after cancellation.
- Reject non-finite coordinates and invalid numeric command arguments.
- Clear the shared session table on resource stop.
- Verify module load order and add regressions for the new RP tools.
- Add structure and upgrade guides; move the roadmap under `docs/`.

The database schema, existing ore yield, resource names and remote-event names are unchanged.
Follow [the upgrade guide](docs/UPGRADING.md); do not reimport the installation schema into an existing database.

## 0.1.0

Initial standalone English starter with account registration and approval,
one character per account, local RP chat and the ore-mining minigame.
