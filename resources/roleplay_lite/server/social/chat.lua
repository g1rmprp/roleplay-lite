local validSession, trim, safeText = LITE.validSession, LITE.trim, LITE.safeText
local send, distanceSquared = LITE.send, LITE.distanceSquared

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

LITE.localChat = localChat

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
