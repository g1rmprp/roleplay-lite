local recent = {}
local allowed = {
    me = true, ["do"] = true, ooc = true, inventory = true, mine = true,
    hit = true, rphelp = true, serial = true, describe = true,
    approveaccount = true, players = true, look = true, whisper = true,
    shout = true, roll = true, cancelmine = true
}

addEvent("lite:chat:submit", true)
addEventHandler("lite:chat:submit", root, function(playerId, raw)
    if getEventClient() ~= playerId or not isPlayerConnected(playerId) or
        type(raw) ~= "string" or #raw > 180 then return end
    local message = raw:gsub("^%s+", ""):gsub("%s+$", "")
    if message == "" or message:find("[%c<>]") then return end
    local now = getTickCount()
    local previous = recent[playerId]
    if previous and previous.message == message and now >= previous.tick and now - previous.tick < 500 then return end
    recent[playerId] = { message = message, tick = now }
    if message:sub(1, 1) ~= "/" then
        triggerEvent("onPlayerChat", root, playerId, message, "local")
        return
    end
    local name, arguments = message:match("^/([A-Za-z0-9_]+)%s*(.*)$")
    name = name and name:lower()
    if not name or not allowed[name] then
        outputChatBox("Unknown Roleplay Lite command.", playerId)
        return
    end
    local tokens = {}
    for token in (arguments or ""):gmatch("%S+") do
        if #tokens >= 32 then return end
        tokens[#tokens + 1] = token
    end
    local unpackValues = (table and table.unpack) or unpack
    executeCommandHandler(name, playerId, unpackValues(tokens))
end)

addEventHandler("onPlayerQuit", root, function(playerId) recent[playerId] = nil end)
