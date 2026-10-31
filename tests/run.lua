local rootPath = "resources/roleplay_lite/"
local unpackValues = (table and table.unpack) or unpack
local serverFiles = dofile("tests/helpers/server_files.lua")
for _, file in ipairs(serverFiles) do
    local chunk, problem = loadfile(rootPath .. file)
    assert(chunk, problem)
end
for _, file in ipairs({ rootPath .. "client/ui.lua", "resources/chat/server.lua", "resources/chat/client.lua" }) do
    local chunk, problem = loadfile(file)
    assert(chunk, problem)
end
local handlers, commands, sqlQueue, passwordQueue, sent = {}, {}, {}, {}, {}
local executed = {}
local tick, eventClient, connected = 10000, nil, { [1] = true, [2] = true }
local playerIds = { 1, 2 }
local positions = {
    [1] = { x = 993.918, y = -564.841, z = 29.876 },
    [2] = { x = 400, y = 400, z = 0 }
}
local savedOre = 0
local hasCharacter = false
local password = "password123"
root, resourceRoot = {}, {}

function addEvent() return true end
function addEventHandler(name, target, callback)
    handlers[name] = handlers[name] or {}
    handlers[name][#handlers[name] + 1] = callback
    return true
end
function addCommandHandler(name, callback) commands[name] = callback return true end
function executeCommandHandler(name, playerId, ...)
    if not commands[name] then return false end
    executed[#executed + 1] = name
    commands[name](playerId, name, ...)
    return true
end
function triggerEvent(name, source, ...)
    for _, callback in ipairs(handlers[name] or {}) do callback(...) end
    return true
end
function outputChatBox(message, target) sent[#sent + 1] = { message = message, target = target } return true end
function outputDebugString() return true end
function triggerClientEvent(playerId, event, source, ...) sent[#sent + 1] = { playerId = playerId, event = event, args = {...} } return true end
function getEventClient() return eventClient end
function getTickCount() return tick end
function getPlayers() return playerIds end
function isPlayerConnected(playerId) return connected[playerId] == true end
function getPlayerSerial(playerId) return playerId == 1 and "serial-one" or "serial-two" end
function getPlayerPosition(playerId)
    return positions[playerId]
end
function getPlayerLifeState() return { state = "alive" } end
function spawnPlayer() return true end
function setTimer(callback, delay, times, ...)
    return { callback = callback, delay = delay, args = {...}, cancelled = false }
end
function killTimer(timer) timer.cancelled = true return true end
function dbConnect() return {} end
function dbClose() return true end
function dbQuery(callback, args, connection, sql, ...)
    local query = { callback = callback, sql = sql, parameters = {...} }
    sqlQueue[#sqlQueue + 1] = query
    return query
end
function dbPoll(query) return query.rows, query.count, query.insertId end
function passwordHash(value, callback)
    passwordQueue[#passwordQueue + 1] = { kind = "hash", value = value, callback = callback }
    return #passwordQueue
end
function passwordVerify(value, encoded, callback)
    passwordQueue[#passwordQueue + 1] = { kind = "verify", value = value, callback = callback }
    return #passwordQueue
end

local function emit(name, ...)
    for _, callback in ipairs(handlers[name] or {}) do callback(...) end
end
local function remote(name, sender, playerId, ...)
    eventClient = sender
    emit(name, playerId, ...)
    eventClient = nil
end
local function flush(fail)
    local query = table.remove(sqlQueue, 1)
    assert(query, "Expected a database query")
    local sql = query.sql
    if fail then
        query.rows, query.count, query.insertId = false, 90011, "connection_lost"
    elseif sql:find("INSERT IGNORE INTO lite_accounts", 1, true) then
        query.rows, query.count = {}, 1
    elseif sql:find("FROM lite_accounts WHERE username=? AND game_serial=?", 1, true) then
        query.rows = { { id = 7, whitelist_status = "approved", password_hash = "argon-encoded", is_locked = 0 } }
        query.count = 1
    elseif sql:find("FROM lite_characters WHERE account_id=?", 1, true) then
        query.rows = hasCharacter and
            { { id = 11, name = "Miner", description = "", ore = savedOre, has_pickaxe = 1 } } or {}
        query.count = #query.rows
    elseif sql:find("INSERT IGNORE INTO lite_characters", 1, true) then
        hasCharacter = true
        query.rows, query.count = {}, 1
    elseif sql:find("SET ore=ore+?", 1, true) then
        savedOre = savedOre + query.parameters[1]
        query.rows, query.count = {}, 1
    else
        query.rows, query.count = {}, 1
    end
    query.insertId = 0
    query.callback(query)
end
local function flushPassword()
    local request = table.remove(passwordQueue, 1)
    assert(request, "Expected a password request")
    if request.kind == "hash" then request.callback(true, "argon-encoded")
    else request.callback(true, request.value == password) end
end
local function fire(timer)
    assert(timer and not timer.cancelled, "Expected an active timer")
    tick = tick + timer.delay
    timer.callback(unpackValues(timer.args))
end

for _, file in ipairs(serverFiles) do dofile(rootPath .. file) end
emit("onResourceStart")
emit("onPlayerJoin", 1)

for _, command in ipairs({ "inventory", "mine", "hit", "cancelmine", "rphelp", "describe", "approveaccount",
    "players", "look", "whisper", "shout", "roll" }) do
    assert(commands[command], "Missing English command: " .. command)
end
for _, command in ipairs({ "inventar", "abbau", "schlag", "litehilfe", "beschreibung", "litefreigabe" }) do
    assert(not commands[command], "Legacy German command is still registered: " .. command)
end

remote("lite:register", 1, 1, "miner", password)
flush()
assert(#passwordQueue == 1, "Registration must request Argon2id hashing")
flushPassword()
flush()
assert(sent[#sent].args[1] == "pending", "Registration must wait for approval")
tick = tick + 2000
remote("lite:login", 1, 1, "miner", password)
flush()
emit("onPlayerQuit", 1)
emit("onPlayerJoin", 1)
flushPassword()
assert(#sqlQueue == 0 and not LITE.players[1].accountId,
    "A late password result must not authenticate a new session")
tick = tick + 2000
remote("lite:login", 2, 1, "miner", password)
assert(#sqlQueue == 0, "A forged event sender was accepted")
remote("lite:login", 1, 1, "miner", "wrong")
assert(#sqlQueue == 0, "A short password was accepted")
remote("lite:login", 1, 1, "miner", password)
assert(#sqlQueue == 1, "Login must query the database")
flush()
assert(#passwordQueue == 1, "Login must verify the Argon2id hash")
flushPassword()
assert(#sqlQueue == 2, "Login must queue account reset and character load")
flush()
flush()
assert(not LITE.players[1].loaded and sent[#sent].args[1] == "character", "A new account needs a character")
remote("lite:character", 1, 1, "123")
assert(#sqlQueue == 0, "An invalid character name was saved")
remote("lite:character", 1, 1, "Miner")
flush()
flush()
assert(not LITE.players[1].loaded, "An accepted spawn request is not confirmation")
emit("onPlayerSpawn", 1)
assert(LITE.players[1].loaded, "Spawn confirmation activates the character")

do
    local function use(name, ...)
        tick = tick + LITE_CONFIG.socialCooldownMs
        commands[name](1, name, ...)
    end
    local function near(distance)
        positions[2] = { x = positions[1].x + distance, y = positions[1].y, z = positions[1].z }
    end
    LITE.players[2] = { loaded = true, accountId = 8, name = "Traveller", description = "A weathered traveller." }
    connected[3], playerIds = true, { 1, 2, 3 }
    LITE.players[3] = { name = "HiddenLogin", loaded = false }
    local before = #sent
    use("players")
    assert(#sent == before + 3, "Player list must contain only the two loaded characters")
    assert(sent[before + 1].message == "Active characters: 2", "Player count must exclude pending accounts")
    assert(sent[before + 3].message == "[2] Traveller", "Player list must show sorted character IDs")

    near(3)
    use("look", "2")
    assert(sent[#sent].message:find("A weathered traveller.", 1, true), "Nearby look must show the saved description")
    near(6)
    use("look", "2")
    assert(sent[#sent].message == "That character is too far away.", "Look must enforce its distance")
    use("look", "2e0")
    assert(sent[#sent].message:find("Player not found", 1, true), "Target IDs must be decimal integers")
    positions[2] = { x = 0/0, y = 0, z = 0 }
    use("look", "2")
    assert(sent[#sent].message == "That character is too far away.", "Invalid coordinates must fail closed")
    assert(LITE.distanceSquared({}, positions[1]) == math.huge, "Missing coordinates must fail closed")

    near(3)
    before = #sent
    use("whisper", "2", "Keep it quiet.")
    assert(#sent == before + 2 and sent[before + 1].target == 1 and sent[before + 2].target == 2,
        "A whisper must be delivered only to its sender and recipient")
    assert(sent[before + 1].message == sent[before + 2].message, "Both whisper participants must see the same text")
    commands.whisper(1, "whisper", "2", "Another message")
    assert(#sent == before + 2, "The social cooldown must also block different repeated messages")
    before = #sent
    use("whisper", "1", "To myself")
    assert(#sent == before + 1, "Whispering to self must not duplicate delivery")
    near(5)
    before = #sent
    use("whisper", "2", "Out of range")
    assert(#sent == before + 1 and sent[#sent].target == 1, "Out-of-range whispers must not reach the target")
    before = #sent
    use("whisper", "2", string.char(0xC0, 0xAF))
    assert(#sent == before + 1 and sent[#sent].message:find("Usage:", 1, true), "Malformed UTF-8 must not be broadcast")

    near(30)
    before = #sent
    tick = tick + LITE_CONFIG.socialCooldownMs
    emit("onPlayerChat", 1, "Normal speech")
    assert(#sent == before + 1 and sent[#sent].target == 1, "Normal speech must retain its original range")
    before = #sent
    use("shout", "Can you hear me?")
    assert(#sent == before + 2 and sent[#sent].target == 2, "Shouts must use the configured larger range")
    near(41)
    before = #sent
    use("shout", "Too far away")
    assert(#sent == before + 1, "Shouts must still have a distance limit")

    near(3)
    before = #sent
    use("roll", "6")
    local result = tonumber(sent[#sent].message:match("rolls (%d+) / 6"))
    assert(result and result >= 1 and result <= 6 and #sent == before + 2,
        "The server must roll one bounded result for nearby players")
    assert(sent[#sent - 1].message == sent[#sent].message, "Dice recipients must see the same result")
    use("roll")
    assert(sent[#sent].message:find(" / 100.", 1, true), "Dice default must be 100 sides")
    for _, invalid in ipairs({ "1", "1001", "6.5", "2e2", "nan", math.huge, 0/0 }) do
        before = #sent
        use("roll", invalid)
        assert(#sent == before + 1 and sent[#sent].message:find("Usage:", 1, true),
            "Invalid dice input must never produce a result")
    end
    commands.roll(3, "roll", "6")
    assert(sent[#sent].message == "Please log in first.", "Pending accounts must not use RP tools")
    LITE.players[3], connected[3], playerIds = nil, nil, { 1, 2 }
    near(100)
end

commands.mine(1)
local game = LITE.players[1].mine
assert(game and game.delayTimer, "Mining must schedule the strike signal")
remote("lite:mine:hit", 1, 1, game.token)
assert(not LITE.players[1].mine and savedOre == 0, "An early strike must not grant ore")

tick = tick + LITE_CONFIG.mine.cooldownMs
commands.mine(1)
game = LITE.players[1].mine
commands.cancelmine(1)
assert(not LITE.players[1].mine and game.delayTimer.cancelled, "Keyboard cancellation must clear mining and its timer")
remote("lite:mine:hit", 1, 1, game.token)
assert(savedOre == 0 and #sqlQueue == 0, "A cancelled mining token must never credit ore")

tick = tick + LITE_CONFIG.mine.cooldownMs
commands.mine(1)
game = LITE.players[1].mine
fire(game.delayTimer)
remote("lite:mine:hit", 2, 1, game.token)
assert(savedOre == 0 and LITE.players[1].mine == game, "Forged event sender")
remote("lite:mine:hit", 1, 1, game.token)
assert(savedOre == 0 and LITE.players[1].awardPending, "Ore before confirmed database response")
flush()
assert(savedOre == 1 and LITE.players[1].ore == 1, "Confirmed ore must be credited exactly once")
remote("lite:mine:hit", 1, 1, game.token)
assert(savedOre == 1 and #sqlQueue == 0, "A replayed strike must not credit ore")

tick = tick + LITE_CONFIG.mine.cooldownMs
commands.mine(1)
game = LITE.players[1].mine
emit("onPlayerQuit", 1)
assert(game.delayTimer.cancelled, "Disconnect must cancel the mining timer")
emit("onPlayerJoin", 1)
remote("lite:login", 1, 1, "miner", password)
flush()
flushPassword()
flush()
flush()
emit("onPlayerSpawn", 1)

tick = tick + LITE_CONFIG.mine.cooldownMs
commands.mine(1)
game = LITE.players[1].mine
fire(game.delayTimer)
remote("lite:mine:hit", 1, 1, game.token)
flush(true)
assert(LITE_DB.fault and savedOre == 1, "Unknown write outcome must block new credits")

tick = tick + LITE_CONFIG.mine.cooldownMs
commands.mine(1)
assert(not LITE.players[1].mine, "Database failure must block further mining")
emit("onResourceStop")
assert(LITE_DB.stopped, "Resource stop must close the database")
assert(not LITE.validSession(1) and next(LITE.players) == nil, "Stop must clear the shared session table")

-- The custom chat forwards only allowlisted commands.
dofile("resources/chat/server.lua")
local previousMessages = #sent
remote("lite:chat:submit", 2, 1, "/rphelp")
assert(#sent == previousMessages, "A forged chat sender was accepted")
remote("lite:chat:submit", 1, 1, "/notallowed")
assert(sent[#sent].message == "Unknown Roleplay Lite command.", "Unknown commands must be blocked")
for _, name in ipairs({ "players", "look", "whisper", "shout", "roll", "cancelmine" }) do
    remote("lite:chat:submit", 1, 1, "/" .. name)
    assert(executed[#executed] == name, "New command must pass through the chat allowlist: " .. name)
end
print("Roleplay Lite: login, spawn, mining, write failure, replay, disconnect and chat allowlist passed.")
