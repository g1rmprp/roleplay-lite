local players = LITE.players
local current, stage, query = LITE.current, LITE.stage, LITE.query
local trim, safeText, validSession, send = LITE.trim, LITE.safeText, LITE.validSession, LITE.send

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

LITE.loadCharacter = loadCharacter

addEvent("lite:character", true)
addEventHandler("lite:character", root, function(playerId, name)
    if getEventClient() ~= playerId then return end
    createCharacter(playerId, name)
end)

addCommandHandler("inventory", function(playerId)
    local session = validSession(playerId)
    if session then
        send(playerId, "Inventory: " .. (session.pickaxe and "Pickaxe, " or "") .. session.ore .. " ore.")
    end
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
