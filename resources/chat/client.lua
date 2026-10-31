local document = false
local registered = false

addEvent("g1r:chatOutput", true)
addEventHandler("g1r:chatOutput", root, function(message, red, green, blue)
    if not document or not registered then return end
    local color = ("#%02x%02x%02x"):format(tonumber(red) or 231, tonumber(green) or 217, tonumber(blue) or 176)
    guiAppendText(document, "messages", tostring(message), "line", color)
end)

addEventHandler("onClientResourceStart", resourceRoot, function()
    document = guiLoadDocument("ui/chat.rml")
    if not document then outputDebugString("[Roleplay Lite] Chat document is missing.", 1) return end
    if guiRegisterChat(document, "composer", "message") ~= true then
        outputDebugString("[Roleplay Lite] Could not register chat.", 1)
        guiClose(document)
        document = false
        return
    end
    registered = true
    if guiShow(document) ~= true then
        outputDebugString("[Roleplay Lite] Could not show chat.", 1)
    end
    guiSetChatActive(false)
end)

addEventHandler("onClientGuiSubmit", resourceRoot, function(documentId, elementId, value)
    if documentId ~= "chat" or elementId ~= "message" or not registered then return end
    if type(value) == "string" and value ~= "" then
        triggerServerEvent("lite:chat:submit", root, value)
    end
    guiSetValue(document, "message", "")
    guiSetChatActive(false)
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    if document then
        if registered then guiSetChatActive(false) end
        guiSetInputActive(document, false)
        guiClose(document)
    end
    registered, document = false, false
end)
