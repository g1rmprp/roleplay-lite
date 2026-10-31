# Runtime assumptions and live validation

**Target runtime: G1R:MP 0.1.9. Gamemode: Roleplay Lite 0.2.0.** Use matching
client and server packages. This document records documentation checks, not
a successful run on an installed server, client or MySQL database.

## Documentation check — 31 October 2026

The official [wiki entry point](https://g1r-mp.com/wiki/index.php?title=Main_Page)
and [0.1.9 release notes](https://g1r-mp.com/wiki/index.php?title=Update_0.1.9)
list BUILD264 / Protocol 42. The installed binaries were not verified during this update.

The new RP tools reuse existing server APIs. The checked contracts are:

| API | Contract used by this starter |
| --- | --- |
| [getPlayers](https://g1r-mp.com/wiki/index.php?title=GetPlayers) | Server-side, returns an array of numeric connected-player IDs; the starter filters this to loaded characters |
| [getPlayerPosition](https://g1r-mp.com/wiki/index.php?title=GetPlayerPosition) | Server-side authoritative position in metres, or false when unavailable |
| [outputChatBox](https://g1r-mp.com/wiki/index.php?title=OutputChatBox) | Server-side delivery to one explicit player ID; acceptance is not proof that the client displayed it |
| [addCommandHandler](https://g1r-mp.com/wiki/index.php?title=AddCommandHandler) | Server-side callback receives player ID, command name and string arguments |
| [getEventClient](https://g1r-mp.com/wiki/index.php?title=GetEventClient) | Authenticated sender identity survives synchronous nested and cross-resource command forwarding |

The separate `ExecuteCommandHandler` page could not be retrieved in this check.
Its existing use is retained; actual cross-resource chat forwarding still needs
the two-client check below. No new native function is introduced by this update.

## Existing access, database and GUI assumptions

The following references were retained from the earlier prototype audit; they
were not all re-audited as part of the targeted 0.1.9 check above.

The server uses [remote-event client identity](https://g1r-mp.com/wiki/index.php?title=GetEventClient), [asynchronous SQL queries](https://g1r-mp.com/wiki/index.php?title=DbQuery) and [polling their results](https://g1r-mp.com/wiki/index.php?title=DbPoll). Passwords are created through asynchronous [Argon2id hashing](https://g1r-mp.com/wiki/index.php?title=PasswordHash) and checked with [passwordVerify](https://g1r-mp.com/wiki/index.php?title=PasswordVerify). An accepted [spawn request](https://g1r-mp.com/wiki/index.php?title=SpawnPlayer) is treated as a successful entry only after [onPlayerSpawn](https://g1r-mp.com/wiki/index.php?title=OnPlayerSpawn). The mining window uses [guiLoadDocument](https://g1r-mp.com/wiki/index.php?title=GuiLoadDocument), [onClientGuiClick](https://g1r-mp.com/wiki/index.php?title=OnClientGuiClick) and [guiSetInputActive](https://g1r-mp.com/wiki/index.php?title=GuiSetInputActive). The separate chat resource uses [guiRegisterChat](https://g1r-mp.com/wiki/index.php?title=GuiRegisterChat).

## Checks still required on a real test server

1. Start `chat,roleplay_lite`; verify client UI download and login.
2. Register, approve and create a character against an isolated MySQL database.
3. Verify spawn confirmation, chat input and local range with two clients.
4. Check the mining window, ESC input release, early and late strikes, reconnect and resource restart.
5. Interrupt the database during a pending ore write. Do not retry an operation with an unknown outcome automatically; reconcile its state before resuming.
6. With two clients, verify whisper privacy, normal/action/shout/inspection ranges,
   dice delivery and the social cooldown. Confirm that `/players` excludes pending
   accounts, `/cancelmine` cancels the GUI game, and no input is retained after ESC.

Documentation of an API contract does not establish availability or behavior in the installed binary. Record the actual client and server versions during live acceptance.
