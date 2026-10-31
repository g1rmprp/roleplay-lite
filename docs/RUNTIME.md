# Runtime assumptions and live validation

**Target runtime: G1R:MP 0.1.8.** These notes describe the prototype's API assumptions; they are not evidence of a successful run on a real 0.1.8 server or client. The API references were recorded on 13 October 2026 and have not been re-audited for this English release.

The server uses [remote-event client identity](https://g1r-mp.com/wiki/index.php?title=GetEventClient), [asynchronous SQL queries](https://g1r-mp.com/wiki/index.php?title=DbQuery) and [polling their results](https://g1r-mp.com/wiki/index.php?title=DbPoll). Passwords are created through asynchronous [Argon2id hashing](https://g1r-mp.com/wiki/index.php?title=PasswordHash) and checked with [passwordVerify](https://g1r-mp.com/wiki/index.php?title=PasswordVerify). An accepted [spawn request](https://g1r-mp.com/wiki/index.php?title=SpawnPlayer) is treated as a successful entry only after [onPlayerSpawn](https://g1r-mp.com/wiki/index.php?title=OnPlayerSpawn). The mining window uses [guiLoadDocument](https://g1r-mp.com/wiki/index.php?title=GuiLoadDocument), [onClientGuiClick](https://g1r-mp.com/wiki/index.php?title=OnClientGuiClick) and [guiSetInputActive](https://g1r-mp.com/wiki/index.php?title=GuiSetInputActive). The separate chat resource uses [guiRegisterChat](https://g1r-mp.com/wiki/index.php?title=GuiRegisterChat).

## Checks still required on a real test server

1. Start `chat,roleplay_lite`; verify client UI download and login.
2. Register, approve and create a character against an isolated MySQL database.
3. Verify spawn confirmation, chat input and local range with two clients.
4. Check the mining window, ESC input release, early and late strikes, reconnect and resource restart.
5. Interrupt the database during a pending ore write. Do not retry an operation with an unknown outcome automatically; reconcile its state before resuming.

Documentation of an API contract does not establish availability or behavior in the installed binary. Record the actual client and server versions during live acceptance.
