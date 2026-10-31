local players = LITE.players
local current, stage, query = LITE.current, LITE.stage, LITE.query
local usernameValid, passwordValid, loadCharacter = LITE.usernameValid, LITE.passwordValid, LITE.loadCharacter

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

local function startSession(playerId)
    local serial = getPlayerSerial(playerId)
    if type(serial) ~= "string" or serial == "" then
        stage(playerId, "error", "Game identity is unavailable.")
        return
    end
    players[playerId] = { serial = serial }
    stage(playerId, "login", "Log in or register an account.")
end

LITE.startSession = startSession

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
