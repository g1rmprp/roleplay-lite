local players = LITE.players
local startSession, current, stage = LITE.startSession, LITE.current, LITE.stage
local send, clearMine, finishMine = LITE.send, LITE.clearMine, LITE.finishMine

addEventHandler("onResourceStart", resourceRoot, function()
    if not LITE_DB.open() then return end
    for _, playerId in ipairs(getPlayers() or {}) do startSession(playerId) end
end)

addEventHandler("onPlayerJoin", root, startSession)
addEventHandler("onPlayerSpawn", root, function(playerId)
    local session = players[playerId]
    if not session or not session.spawning or not current(playerId, session) then return end
    session.spawning = false
    session.busy = false
    session.loaded = true
    if session.spawnTimer then killTimer(session.spawnTimer) session.spawnTimer = nil end
    stage(playerId, "play", "Welcome to the colony, " .. session.name .. ".")
    send(playerId, "Welcome, " .. session.name .. ". Use /rphelp to see all commands.")
end)
addEventHandler("onPlayerQuit", root, function(playerId)
    local session = players[playerId]
    if session then
        clearMine(session)
        if session.spawnTimer then killTimer(session.spawnTimer) end
    end
    players[playerId] = nil
end)
addEventHandler("onPlayerLifeStateChange", root, function(playerId, previousState, nextState)
    local session = players[playerId]
    if session and session.mine and nextState ~= "alive" then
        finishMine(playerId, session, "Mining cancelled because your condition changed.")
    end
end)
addEventHandler("onResourceStop", resourceRoot, function()
    for playerId, session in pairs(players) do
        clearMine(session)
        if session.spawnTimer then killTimer(session.spawnTimer) end
        players[playerId] = nil
    end
    LITE_DB.close()
    LITE.accessBySerial = {}
end)

addEvent("lite:ready", true)
addEventHandler("lite:ready", root, function(playerId)
    if getEventClient() ~= playerId then return end
    local session = players[playerId]
    if not session then return end
    if session.loaded then stage(playerId, "play", "Welcome, " .. session.name .. ".")
    elseif session.busy or session.spawning then stage(playerId, "checking", "Checking your account...")
    elseif session.accountId then stage(playerId, "character", "Create your character.")
    else stage(playerId, "login", "Log in or register an account.") end
end)
