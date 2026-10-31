LITE = { players = {}, mineSerial = 0, accessBySerial = {} }
local players = LITE.players

local function send(playerId, message)
    outputChatBox(tostring(message), playerId, 217, 190, 139, false)
end

local function stage(playerId, state, message)
    if isPlayerConnected(playerId) then
        triggerClientEvent(playerId, "lite:stage", root, state, tostring(message or ""))
    end
end

local function current(playerId, expected)
    return players[playerId] == expected and isPlayerConnected(playerId)
end

local function trim(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function safeText(value, minBytes, maxBytes)
    if type(value) ~= "string" or #value < minBytes or #value > maxBytes or
        value:find("[%c<>]") then return false end
    local index = 1
    while index <= #value do
        local first = value:byte(index)
        local width, point, minimum
        if first < 0x80 then width, point, minimum = 1, first, 0
        elseif first >= 0xC2 and first <= 0xDF then width, point, minimum = 2, first - 0xC0, 0x80
        elseif first >= 0xE0 and first <= 0xEF then width, point, minimum = 3, first - 0xE0, 0x800
        elseif first >= 0xF0 and first <= 0xF4 then width, point, minimum = 4, first - 0xF0, 0x10000
        else return false end
        for offset = 1, width - 1 do
            local nextByte = value:byte(index + offset)
            if not nextByte or nextByte < 0x80 or nextByte > 0xBF then return false end
            point = point * 0x40 + nextByte - 0x80
        end
        if point < minimum or point > 0x10FFFF or (point >= 0xD800 and point <= 0xDFFF) then return false end
        index = index + width
    end
    return true
end

local function usernameValid(value)
    return type(value) == "string" and #value >= 3 and #value <= 24 and
        value:match("^[A-Za-z0-9_]+$") ~= nil
end

local function passwordValid(value)
    return safeText(value, 8, 72)
end

local function query(playerId, session, sql, params, callback, writing)
    if not LITE_DB.query(sql, params, function(rows, count, insertId)
        if current(playerId, session) then callback(rows, count, insertId) end
    end, writing) then
        if current(playerId, session) then
            session.busy = false
            stage(playerId, "error", "Database unavailable. Please contact the server staff.")
        end
        return false
    end
    return true
end

local function validSession(playerId)
    local session = players[playerId]
    if not session or not session.loaded or not current(playerId, session) then return nil end
    return session
end

local function loadCharacter(playerId, session)
    session.busy = true
    stage(playerId, "checking", "Loading character...")
    query(playerId, session,
        "SELECT id, name, description, ore, has_pickaxe FROM lite_characters WHERE account_id=? LIMIT 1",
        { session.accountId }, function(rows)
            session.busy = false
            if rows == false then
                stage(playerId, "error", "Could not load character data.")
                return
            end
            local character = rows[1]
            if not character then
                stage(playerId, "character", "Create your first character.")
                return
            end
            local spawn = LITE_CONFIG.spawn
            session.characterId = tonumber(character.id)
            session.name = tostring(character.name)
            session.description = tostring(character.description or "")
            session.ore = tonumber(character.ore) or 0
            session.pickaxe = tonumber(character.has_pickaxe) == 1 or character.has_pickaxe == true
            session.spawning = true
            session.busy = true
            if spawnPlayer(playerId, spawn.x, spawn.y, spawn.z, spawn.yaw) ~= true then
                session.spawning = false
                session.busy = false
                stage(playerId, "error", "Could not spawn in the world.")
                return
            end
            if session.spawning then
                session.spawnTimer = setTimer(function()
                    if current(playerId, session) and session.spawning then
                        session.spawning = false
                        session.busy = false
                        stage(playerId, "error", "Spawn was not confirmed. Please log in again.")
                    end
                end, 15000, 1)
            end
        end)
end

local function register(playerId, username, password)
    local session = players[playerId]
    if not session or session.loaded or session.busy or not current(playerId, session) then return end
    if not usernameValid(username) or not passwordValid(password) then
        stage(playerId, "login", "Username: 3-24 characters (A-Z, 0-9, _). Password: 8-72 characters.")
        return
    end
    if getTickCount() < (LITE.accessBySerial[session.serial] or 0) then return end
    LITE.accessBySerial[session.serial] = getTickCount() + 2000
    session.busy = true
    query(playerId, session, "SELECT id FROM lite_accounts WHERE username=? OR game_serial=? LIMIT 1",
        { string.lower(username), session.serial }, function(rows)
            if rows == false then
                session.busy = false
                stage(playerId, "login", "Registration is currently unavailable.")
                return
            end
            if rows[1] then
                session.busy = false
                stage(playerId, "login", "An account already exists for this name or game identity.")
                return
            end
            local requested = passwordHash(password, function(success, encodedHash)
                if not current(playerId, session) then return end
                if success ~= true or type(encodedHash) ~= "string" or #encodedHash == 0 or #encodedHash > 512 then
                    session.busy = false
                    stage(playerId, "login", "Registration is currently unavailable.")
                    return
                end
                query(playerId, session, [[
                    INSERT IGNORE INTO lite_accounts (username, password_hash, game_serial)
                    VALUES (?, ?, ?)
                ]], { string.lower(username), encodedHash, session.serial }, function(inserted, count)
                    session.busy = false
                    if inserted == false then
                        stage(playerId, "error", "Registration was not confirmed. Please contact the server staff.")
                        return
                    end
                    if count ~= 1 then
                        stage(playerId, "login", "An account already exists for this name or game identity.")
                        return
                    end
                    stage(playerId, "pending", "Account created. Waiting for staff approval.")
                end, true)
            end)
            if not requested then
                session.busy = false
                stage(playerId, "login", "Password service is currently unavailable.")
            end
        end)
end

local function login(playerId, username, password)
    local session = players[playerId]
    if not session or session.loaded or session.busy or not current(playerId, session) then return end
    if not usernameValid(username) or not passwordValid(password) then
        stage(playerId, "login", "Invalid username or password.")
        return
    end
    if getTickCount() < (LITE.accessBySerial[session.serial] or 0) then return end
    LITE.accessBySerial[session.serial] = getTickCount() + 1500
    session.busy = true
    stage(playerId, "checking", "Checking login...")
    query(playerId, session, [[
        SELECT id, whitelist_status, password_hash,
            IF(locked_until IS NOT NULL AND locked_until>UTC_TIMESTAMP(), 1, 0) AS is_locked
        FROM lite_accounts WHERE username=? AND game_serial=? LIMIT 1
    ]], { string.lower(username), session.serial }, function(rows)
        if rows == false then
            session.busy = false
            stage(playerId, "login", "Login is currently unavailable.")
            return
        end
        local account = rows[1]
        if account and tonumber(account.is_locked) == 1 then
            session.busy = false
            stage(playerId, "login", "Too many failed attempts. Please try again later.")
            return
        end
        if not account then
            session.busy = false
            stage(playerId, "login", "Invalid username or password.")
            return
        end
        local requested = passwordVerify(password, tostring(account.password_hash or ""), function(success, matches)
            if not current(playerId, session) then return end
            session.busy = false
            if success ~= true then
                stage(playerId, "login", "Password verification is currently unavailable.")
                return
            end
            if matches ~= true then
                LITE_DB.query([[UPDATE lite_accounts SET failed_attempts=failed_attempts+1,
                    locked_until=IF(failed_attempts+1>=5, DATE_ADD(UTC_TIMESTAMP(), INTERVAL 5 MINUTE), locked_until)
                    WHERE id=?]], { account.id }, function() end, true)
                stage(playerId, "login", "Invalid username or password.")
                return
            end
            if account.whitelist_status ~= "approved" then
                stage(playerId, "pending", "Your account is waiting for approval.")
                return
            end
            for otherId, other in pairs(players) do
                if otherId ~= playerId and other.accountId == tonumber(account.id) and current(otherId, other) then
                    stage(playerId, "login", "This account is already logged in.")
                    return
                end
            end
            session.accountId = tonumber(account.id)
            LITE_DB.query("UPDATE lite_accounts SET failed_attempts=0, locked_until=NULL WHERE id=?",
                { session.accountId }, function() end, true)
            loadCharacter(playerId, session)
        end)
        if not requested then
            session.busy = false
            stage(playerId, "login", "Password service is currently unavailable.")
        end
    end)
end

local function createCharacter(playerId, name)
    local session = players[playerId]
    if not session or not session.accountId or session.loaded or session.busy or not current(playerId, session) then return end
    name = trim(name)
    if not safeText(name, 3, 48) or name:find("[%d_]") then
        stage(playerId, "character", "Enter a name with 3-48 characters and no digits.")
        return
    end
    session.busy = true
    query(playerId, session, "INSERT IGNORE INTO lite_characters (account_id, name) VALUES (?, ?)",
        { session.accountId, name }, function(rows, count)
            session.busy = false
            if rows == false or count ~= 1 then
                stage(playerId, "error", "Could not create the character. Please log in again.")
                return
            end
            loadCharacter(playerId, session)
        end, true)
end

local function distanceSquared(a, b)
    if not a or not b then return math.huge end
    local ax, ay, az = tonumber(a.x), tonumber(a.y), tonumber(a.z)
    local bx, by, bz = tonumber(b.x), tonumber(b.y), tonumber(b.z)
    if not ax or not ay or not az or not bx or not by or not bz then return math.huge end
    return (ax-bx)^2 + (ay-by)^2 + (az-bz)^2
end

local function nearMine(playerId)
    return distanceSquared(getPlayerPosition(playerId), LITE_CONFIG.mine) <= LITE_CONFIG.mine.radius^2
end

local function alive(playerId)
    local life = getPlayerLifeState(playerId)
    return type(life) == "table" and life.state == "alive"
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

local function startSession(playerId)
    local serial = getPlayerSerial(playerId)
    if type(serial) ~= "string" or serial == "" then
        stage(playerId, "error", "Game identity is unavailable.")
        return
    end
    players[playerId] = { serial = serial }
    stage(playerId, "login", "Log in or register an account.")
end

local function localChat(playerId, prefix, message, range)
    local sender = validSession(playerId)
    message = trim(message)
    if not sender then send(playerId, "Please log in first.") return end
    if not safeText(message, 1, LITE_CONFIG.maxChatBytes) then return end
    local position = getPlayerPosition(playerId)
    if not position then return end
    for _, targetId in ipairs(getPlayers() or {}) do
        if validSession(targetId) and distanceSquared(position, getPlayerPosition(targetId)) <= range^2 then
            send(targetId, prefix(sender.name, message))
        end
    end
end

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
    for _, session in pairs(players) do
        clearMine(session)
        if session.spawnTimer then killTimer(session.spawnTimer) end
    end
    LITE_DB.close()
    LITE.players = {}
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

addEvent("lite:register", true)
addEventHandler("lite:register", root, function(playerId, username, password)
    if getEventClient() ~= playerId then return end
    register(playerId, username, password)
end)
addEvent("lite:login", true)
addEventHandler("lite:login", root, function(playerId, username, password)
    if getEventClient() ~= playerId then return end
    login(playerId, username, password)
end)
addEvent("lite:character", true)
addEventHandler("lite:character", root, function(playerId, name)
    if getEventClient() ~= playerId then return end
    createCharacter(playerId, name)
end)
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

addEventHandler("onPlayerChat", root, function(playerId, message)
    localChat(playerId, function(name, text) return name .. " says: " .. text end,
        message, LITE_CONFIG.chatRange)
end)

addCommandHandler("me", function(playerId, commandName, ...)
    localChat(playerId, function(name, text) return "* " .. name .. " " .. text end,
        table.concat({...}, " "), LITE_CONFIG.actionRange)
end)
addCommandHandler("do", function(playerId, commandName, ...)
    localChat(playerId, function(name, text) return "* " .. text .. " (" .. name .. ")" end,
        table.concat({...}, " "), LITE_CONFIG.actionRange)
end)
addCommandHandler("ooc", function(playerId, commandName, ...)
    local session = validSession(playerId)
    local message = trim(table.concat({...}, " "))
    if not session or not safeText(message, 1, LITE_CONFIG.maxChatBytes) then return end
    for _, targetId in ipairs(getPlayers() or {}) do
        if validSession(targetId) then send(targetId, "(( " .. session.name .. ": " .. message .. " ))") end
    end
end)
addCommandHandler("inventory", function(playerId)
    local session = validSession(playerId)
    if session then
        send(playerId, "Inventory: " .. (session.pickaxe and "Pickaxe, " or "") .. session.ore .. " ore.")
    end
end)
addCommandHandler("mine", function(playerId) startMine(playerId) end)
addCommandHandler("hit", function(playerId)
    local session = validSession(playerId)
    if session and session.mine then hitMine(playerId, session.mine.token) end
end)
addCommandHandler("rphelp", function(playerId)
    send(playerId, "/inventory, /mine, /hit, /me, /do, /ooc, /describe <text>, /serial")
end)
addCommandHandler("serial", function(playerId)
    local session = players[playerId]
    if session then send(playerId, "Your game serial: " .. session.serial) end
end)
addCommandHandler("describe", function(playerId, commandName, ...)
    local session = validSession(playerId)
    if not session or session.busy then return end
    local description = trim(table.concat({...}, " "))
    if not safeText(description, 1, 180) then send(playerId, "Description: 1-180 characters.") return end
    session.busy = true
    local queued = LITE_DB.query("UPDATE lite_characters SET description=? WHERE id=?",
        { description, session.characterId }, function(rows, count)
            session.busy = false
            if rows ~= false and count == 1 then
                session.description = description
                if current(playerId, session) then send(playerId, "Description saved.") end
            elseif current(playerId, session) then send(playerId, "Save was not confirmed.") end
        end, true)
    if not queued then session.busy = false send(playerId, "Database unavailable.") end
end)

addCommandHandler("approveaccount", function(playerId, commandName, username)
    local session = players[playerId]
    if not session or not usernameValid(username) or not current(playerId, session) then return end
    query(playerId, session, "SELECT game_serial FROM lite_admins WHERE game_serial=? LIMIT 1",
        { session.serial }, function(rows)
            if rows == false or not rows[1] then send(playerId, "Permission denied.") return end
            query(playerId, session,
                "UPDATE lite_accounts SET whitelist_status='approved' WHERE username=? AND whitelist_status='pending'",
                { string.lower(username) }, function(updated, count)
                    if updated ~= false and count == 1 then send(playerId, "Account approved: " .. username)
                    else send(playerId, "No pending account found with that name.") end
                end, true)
        end)
end)
