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
local tick, eventClient, connected = 10000, nil, { [1] = true, [2] = true }
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
function getPlayers() return { 1, 2 } end
function isPlayerConnected(playerId) return connected[playerId] == true end
function getPlayerSerial(playerId) return playerId == 1 and "serial-one" or "serial-two" end
function getPlayerPosition(playerId)
    if playerId == 1 then return { x = 993.918, y = -564.841, z = 29.876 } end
    return { x = 400, y = 400, z = 0 }
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

for _, command in ipairs({ "inventory", "mine", "hit", "rphelp", "describe", "approveaccount" }) do
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

commands.mine(1)
local game = LITE.players[1].mine
assert(game and game.delayTimer, "Mining must schedule the strike signal")
remote("lite:mine:hit", 1, 1, game.token)
assert(not LITE.players[1].mine and savedOre == 0, "An early strike must not grant ore")

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

-- The custom chat forwards only allowlisted commands.
dofile("resources/chat/server.lua")
local previousMessages = #sent
remote("lite:chat:submit", 2, 1, "/rphelp")
assert(#sent == previousMessages, "A forged chat sender was accepted")
remote("lite:chat:submit", 1, 1, "/notallowed")
assert(sent[#sent].message == "Unknown Roleplay Lite command.", "Unknown commands must be blocked")
print("Roleplay Lite: login, spawn, mining, write failure, replay, disconnect and chat allowlist passed.")
