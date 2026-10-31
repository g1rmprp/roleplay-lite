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

local function distanceSquared(a, b)
    if not a or not b then return math.huge end
    local ax, ay, az = tonumber(a.x), tonumber(a.y), tonumber(a.z)
    local bx, by, bz = tonumber(b.x), tonumber(b.y), tonumber(b.z)
    if not ax or not ay or not az or not bx or not by or not bz then return math.huge end
    for _, value in ipairs({ ax, ay, az, bx, by, bz }) do
        if value ~= value or value == math.huge or value == -math.huge then return math.huge end
    end
    return (ax-bx)^2 + (ay-by)^2 + (az-bz)^2
end

-- Chat commands accept decimal integers, never expressions, NaN or infinity.
local function integer(value, minimum, maximum)
    if type(value) == "string" then
        if #value > 10 or not value:match("^%d+$") then return nil end
        value = tonumber(value)
    end
    if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge or
        value ~= math.floor(value) or value < minimum or value > maximum then return nil end
    return value
end

local function socialReady(session)
    local now = getTickCount()
    if session.nextSocialAt and now < session.nextSocialAt then return false end
    session.nextSocialAt = now + LITE_CONFIG.socialCooldownMs
    return true
end

local function alive(playerId)
    local life = getPlayerLifeState(playerId)
    return type(life) == "table" and life.state == "alive"
end

LITE.send = send
LITE.stage = stage
LITE.current = current
LITE.trim = trim
LITE.safeText = safeText
LITE.usernameValid = usernameValid
LITE.passwordValid = passwordValid
LITE.query = query
LITE.validSession = validSession
LITE.distanceSquared = distanceSquared
LITE.alive = alive
LITE.integer = integer
LITE.socialReady = socialReady
