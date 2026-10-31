local accessDocument = false
local mineDocument = false
local mineToken = false
local mineReady = false
local openDocuments = {}

local function accepted(fn, ...)
    local ok, result = pcall(fn, ...)
    return ok and result == true
end

local function escape(value)
    return tostring(value or ""):gsub("&", "&amp;"):gsub("<", "&lt;")
        :gsub(">", "&gt;"):gsub('"', "&quot;"):gsub("'", "&#39;")
end

local function release(document)
    if document then
        if not accepted(guiSetInputActive, document, false) then
            outputDebugString("[Roleplay Lite] Could not release UI input.", 1)
            return false
        end
        if not accepted(guiHide, document) then
            outputDebugString("[Roleplay Lite] Could not hide UI.", 1)
            return false
        end
        openDocuments[document] = nil
    end
    return true
end

local function show(document)
    if not document then return false end
    if not openDocuments[document] then
        if not accepted(guiShow, document) then return false end
        openDocuments[document] = true
    end
    if not accepted(guiSetInputActive, document, true) then
        pcall(guiHide, document)
        openDocuments[document] = nil
        return false
    end
    return true
end

local function setText(document, id, value)
    if document and not accepted(guiSetInnerRML, document, id, escape(value)) then
        outputDebugString("[Roleplay Lite] Could not set UI text: " .. id, 1)
    end
end

addEventHandler("onClientResourceStart", resourceRoot, function()
    accessDocument = guiLoadDocument("ui/access.rml")
    if not accessDocument then
        outputDebugString("[Roleplay Lite] Access document is missing.", 1)
        return
    end
    guiSetClass(accessDocument, "character-fields", "hidden", true)
    show(accessDocument)
    triggerServerEvent("lite:ready", root)
end)

addEvent("lite:stage", true)
addEventHandler("lite:stage", root, function(state, message)
    if not accessDocument then return end
    setText(accessDocument, "status", message)
    if state == "play" then
        release(accessDocument)
        return
    end
    if not show(accessDocument) then
        outputDebugString("[Roleplay Lite] Access window could not receive input.", 1)
        return
    end
    guiSetClass(accessDocument, "character-fields", "hidden", state ~= "character")
    guiSetClass(accessDocument, "account-fields", "hidden", state == "character" or state == "checking")
end)

addEvent("lite:mine", true)
addEventHandler("lite:mine", root, function(action, token, message)
    if action == "end" then
        mineReady = false
        mineToken = false
        release(mineDocument)
        return
    end
    if action == "start" then
        mineDocument = mineDocument or guiLoadDocument("ui/mine.rml")
        if not mineDocument then
            outputDebugString("[Roleplay Lite] Mining window is missing; /hit remains available.", 1)
            return
        end
        mineToken = token
        mineReady = false
        setText(mineDocument, "mine-status", message)
        guiSetDisabled(mineDocument, "hit", true)
        if not show(mineDocument) then
            outputDebugString("[Roleplay Lite] Mining window could not receive input.", 1)
        end
        return
    end
    if token ~= mineToken or not mineDocument then return end
    setText(mineDocument, "mine-status", message)
    if action == "ready" then
        mineReady = true
        guiSetDisabled(mineDocument, "hit", false)
    elseif action == "saving" then
        mineReady = false
        guiSetDisabled(mineDocument, "hit", true)
    end
end)

addEventHandler("onClientGuiClick", resourceRoot, function(documentId, elementId)
    if documentId == "access" and accessDocument then
        if elementId == "login" then
            local password = guiGetValue(accessDocument, "password")
            guiSetValue(accessDocument, "password", "")
            triggerServerEvent("lite:login", root,
                guiGetValue(accessDocument, "username"), password)
        elseif elementId == "register" then
            local password = guiGetValue(accessDocument, "password")
            guiSetValue(accessDocument, "password", "")
            triggerServerEvent("lite:register", root,
                guiGetValue(accessDocument, "username"), password)
        elseif elementId == "create-character" then
            triggerServerEvent("lite:character", root, guiGetValue(accessDocument, "character-name"))
        end
    elseif documentId == "mine" and mineDocument then
        if elementId == "hit" and mineReady and mineToken then
            mineReady = false
            guiSetDisabled(mineDocument, "hit", true)
            triggerServerEvent("lite:mine:hit", root, mineToken)
        elseif elementId == "cancel" and mineToken then
            triggerServerEvent("lite:mine:cancel", root, mineToken)
        end
    end
end)

addEventHandler("onClientGuiEscape", resourceRoot, function(documentId)
    if documentId == "mine" and mineToken then
        triggerServerEvent("lite:mine:cancel", root, mineToken)
    end
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    release(mineDocument)
    release(accessDocument)
    mineDocument, accessDocument = false, false
end)
