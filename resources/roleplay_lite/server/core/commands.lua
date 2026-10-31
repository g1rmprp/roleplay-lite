local players, send = LITE.players, LITE.send

addCommandHandler("rphelp", function(playerId)
    send(playerId, "Character: /players, /look <ID>, /describe <text>, /inventory")
    send(playerId, "Roleplay: /me, /do, /ooc, /whisper <ID> <text>, /shout <text>, /roll [sides]")
    send(playerId, "Mining: /mine, /hit, /cancelmine. Setup: /serial. Help: /rphelp")
end)
addCommandHandler("serial", function(playerId)
    local session = players[playerId]
    if session then send(playerId, "Your game serial: " .. session.serial) end
end)
