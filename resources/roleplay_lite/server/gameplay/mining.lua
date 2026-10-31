local validSession, current, send = LITE.validSession, LITE.current, LITE.send
local distanceSquared, alive = LITE.distanceSquared, LITE.alive
local players = LITE.players

local function nearMine(playerId)
    return distanceSquared(getPlayerPosition(playerId), LITE_CONFIG.mine) <= LITE_CONFIG.mine.radius^2
end

local function clearMine(session)
    local game = session.mine
    if not game then return nil end
    if game.delayTimer then killTimer(game.delayTimer) end
    if game.timeoutTimer then killTimer(game.timeoutTimer) end
    session.mine = nil
    return game
end

local function finishMine(playerId, session, message)
    if not clearMine(session) then return end
    if current(playerId, session) then
        triggerClientEvent(playerId, "lite:mine", root, "end", 0, message)
        send(playerId, message)
    end
end

local function startMine(playerId)
    local session = validSession(playerId)
    if not session or session.mine or session.awardPending then return end
    if LITE_DB.fault or not LITE_DB.handle then
        send(playerId, "Mining is disabled because of a database error. Contact the server staff.")
        return
    end
    local now = getTickCount()
    if now < (session.mineCooldown or 0) then
        send(playerId, "The ore vein needs a moment before you can mine again.")
        return
    end
    if not session.pickaxe then send(playerId, "You need a pickaxe.") return end
    if not alive(playerId) then send(playerId, "You cannot mine in your current condition.") return end
    if not nearMine(playerId) then send(playerId, "There is no reachable ore vein here.") return end
    LITE.mineSerial = LITE.mineSerial + 1
    local token = LITE.mineSerial
    local game = { token = token, startedAt = now }
    session.mine = game
    session.mineCooldown = now + LITE_CONFIG.mine.cooldownMs
    triggerClientEvent(playerId, "lite:mine", root, "start", token, "Watch the ore vein...")
    game.delayTimer = setTimer(function()
        if not current(playerId, session) or session.mine ~= game then return end
        if not nearMine(playerId) or not alive(playerId) then
            finishMine(playerId, session, "Mining cancelled: your position or condition changed.")
            return
        end
        game.readyAt = getTickCount()
        triggerClientEvent(playerId, "lite:mine", root, "ready", token, "STRIKE NOW!")
        game.timeoutTimer = setTimer(function()
            if current(playerId, session) and session.mine == game then
                finishMine(playerId, session, "Too late! You missed the opening.")
            end
        end, LITE_CONFIG.mine.hitWindowMs, 1)
        if not game.timeoutTimer or game.timeoutTimer == 0 then
            finishMine(playerId, session, "Mining is currently unavailable.")
        end
    end, LITE_CONFIG.mine.minimumWaitMs + math.random(0, LITE_CONFIG.mine.randomWaitMs), 1)
    if not game.delayTimer or game.delayTimer == 0 then
        finishMine(playerId, session, "Mining is currently unavailable.")
    end
end

local function hitMine(playerId, token)
    local session = validSession(playerId)
    local game = session and session.mine
    if not game or game.token ~= token then return end
    if not game.readyAt then finishMine(playerId, session, "Too early! Wait for the signal.") return end
    local elapsed = getTickCount() - game.readyAt
    if elapsed < 0 or elapsed > LITE_CONFIG.mine.hitWindowMs then
        finishMine(playerId, session, "Too late! You missed the opening.")
        return
    end
    if not session.pickaxe or not nearMine(playerId) or not alive(playerId) then
        finishMine(playerId, session, "Mining cancelled: position, tool or condition is invalid.")
        return
    end
    clearMine(session)
    session.awardPending = true
    triggerClientEvent(playerId, "lite:mine", root, "saving", token, "Collecting ore...")
    local characterId = session.characterId
    local amount = LITE_CONFIG.mine.ore
    local queued = LITE_DB.query("UPDATE lite_characters SET ore=ore+? WHERE id=? AND ore<=2147483647-?",
        { amount, characterId, amount }, function(rows, count)
            session.awardPending = false
            if rows == false or count ~= 1 then
                if current(playerId, session) then
                    triggerClientEvent(playerId, "lite:mine", root, "end", token, "Ore credit was not confirmed. Contact the server staff.")
                end
                return
            end
            session.ore = session.ore + amount
            if current(playerId, session) then
                triggerClientEvent(playerId, "lite:mine", root, "end", token, "Success! +" .. amount .. " ore.")
                send(playerId, "You mined " .. amount .. " ore. Total: " .. session.ore .. ".")
            end
        end, true)
    if not queued and current(playerId, session) then
        session.awardPending = false
        triggerClientEvent(playerId, "lite:mine", root, "end", token, "Database unavailable. Contact the server staff.")
    end
end

LITE.clearMine = clearMine
LITE.finishMine = finishMine

addEvent("lite:mine:hit", true)
addEventHandler("lite:mine:hit", root, function(playerId, token)
    if getEventClient() ~= playerId or type(token) ~= "number" or token ~= math.floor(token) then return end
    hitMine(playerId, token)
end)
addEvent("lite:mine:cancel", true)
addEventHandler("lite:mine:cancel", root, function(playerId, token)
    if getEventClient() ~= playerId then return end
    local session = players[playerId]
    if session and session.mine and session.mine.token == token then
        finishMine(playerId, session, "Mining cancelled.")
    end
end)

addCommandHandler("mine", function(playerId) startMine(playerId) end)
addCommandHandler("hit", function(playerId)
    local session = validSession(playerId)
    if session and session.mine then hitMine(playerId, session.mine.token) end
end)
