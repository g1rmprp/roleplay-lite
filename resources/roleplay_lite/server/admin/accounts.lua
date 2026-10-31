local players = LITE.players
local usernameValid, current, query, send = LITE.usernameValid, LITE.current, LITE.query, LITE.send

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
