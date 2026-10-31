local players, send = LITE.players, LITE.send

addCommandHandler("rphelp", function(playerId)
    send(playerId, "/inventory, /mine, /hit, /me, /do, /ooc, /describe <text>, /serial")
end)
addCommandHandler("serial", function(playerId)
    local session = players[playerId]
    if session then send(playerId, "Your game serial: " .. session.serial) end
end)
