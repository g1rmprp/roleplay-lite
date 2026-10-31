local validSession, send = LITE.validSession, LITE.send
local integer, safeText, trim = LITE.integer, LITE.safeText, LITE.trim
local distanceSquared, socialReady = LITE.distanceSquared, LITE.socialReady

local function nearbyTarget(playerId, value, range)
    local targetId = integer(value, 0, 2147483647)
    local target = targetId and validSession(targetId)
    if not target then
        send(playerId, "Player not found. Use /players to see active character IDs.")
        return nil
    end
    if distanceSquared(getPlayerPosition(playerId), getPlayerPosition(targetId)) > range * range then
        send(playerId, "That character is too far away.")
        return nil
    end
    return targetId, target
end

addCommandHandler("players", function(playerId)
    local session = validSession(playerId)
    if not session then send(playerId, "Please log in first.") return end
    if not socialReady(session) then return end
    local entries = {}
    for _, targetId in ipairs(getPlayers() or {}) do
        local target = validSession(targetId)
        if target then entries[#entries + 1] = { id = targetId, name = target.name } end
    end
    table.sort(entries, function(a, b) return a.id < b.id end)
    send(playerId, "Active characters: " .. #entries)
    for index = 1, math.min(#entries, 50) do
        local entry = entries[index]
        send(playerId, "[" .. entry.id .. "] " .. entry.name)
    end
    if #entries > 50 then send(playerId, "Showing the first 50 characters.") end
end)

addCommandHandler("look", function(playerId, commandName, value)
    local session = validSession(playerId)
    if not session then send(playerId, "Please log in first.") return end
    if not socialReady(session) then return end
    local targetId, target = nearbyTarget(playerId, value, LITE_CONFIG.lookRange)
    if not targetId then return end
    local description = tostring(target.description or "")
    if description == "" then description = "No description set." end
    send(playerId, "[" .. targetId .. "] " .. target.name .. ": " .. description)
end)

addCommandHandler("whisper", function(playerId, commandName, value, ...)
    local session = validSession(playerId)
    if not session then send(playerId, "Please log in first.") return end
    local message = trim(table.concat({...}, " "))
    if not safeText(message, 1, LITE_CONFIG.maxChatBytes) then
        send(playerId, "Usage: /whisper <player ID> <message>")
        return
    end
    if not socialReady(session) then return end
    local targetId, target = nearbyTarget(playerId, value, LITE_CONFIG.whisperRange)
    if not targetId then return end
    local text = session.name .. " whispers to " .. target.name .. ": " .. message
    send(playerId, text)
    if targetId ~= playerId then send(targetId, text) end
end)

addCommandHandler("shout", function(playerId, commandName, ...)
    LITE.localChat(playerId, function(name, text) return name .. " shouts: " .. text end,
        table.concat({...}, " "), LITE_CONFIG.shoutRange)
end)

addCommandHandler("roll", function(playerId, commandName, value, ...)
    local session = validSession(playerId)
    if not session then send(playerId, "Please log in first.") return end
    local sides = value == nil and 100 or integer(value, 2, 1000)
    if not sides or select("#", ...) > 0 then
        send(playerId, "Usage: /roll [sides: 2-1000]. Default: 100.")
        return
    end
    -- The server chooses the result and broadcasts it through the normal RP range.
    if not socialReady(session) then return end
    local position = getPlayerPosition(playerId)
    if not position then return end
    local text = "* " .. session.name .. " rolls " .. math.random(1, sides) .. " / " .. sides .. "."
    for _, targetId in ipairs(getPlayers() or {}) do
        if validSession(targetId) and
            distanceSquared(position, getPlayerPosition(targetId)) <= LITE_CONFIG.actionRange^2 then
            send(targetId, text)
        end
    end
end)
