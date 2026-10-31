local handlers, requests, calls = {}, {}, {}
local inputFails = false
root, resourceRoot = {}, {}

function addEvent() return true end
function addEventHandler(name, target, callback)
    handlers[name] = handlers[name] or {}
    handlers[name][#handlers[name] + 1] = callback
    return true
end
local function emit(name, ...)
    for _, callback in ipairs(handlers[name] or {}) do callback(...) end
end
function guiLoadDocument(path)
    if path == "ui/access.rml" then return "access" end
    if path == "ui/mine.rml" then return "mine" end
    return false
end
function guiSetClass() return true end
function guiSetInnerRML(document, id, value)
    calls[#calls + 1] = { kind = "text", document = document, id = id, value = value }
    return true
end
function guiSetDisabled() return true end
function guiShow(document)
    calls[#calls + 1] = { kind = "show", document = document }
    return true
end
function guiHide(document)
    calls[#calls + 1] = { kind = "hide", document = document }
    return true
end
function guiSetInputActive(document, active)
    calls[#calls + 1] = { kind = "input", document = document, active = active }
    if active and inputFails then return false end
    return true
end
function guiGetValue(document, id)
    if id == "username" then return "miner" end
    if id == "password" then return "password123" end
    if id == "character-name" then return "Miner" end
end
function guiSetValue() return true end
function triggerServerEvent(name, source, ...)
    requests[#requests + 1] = { name = name, args = {...} }
    return true
end
function outputDebugString() return true end

dofile("resources/roleplay_lite/client/ui.lua")
emit("onClientResourceStart")
assert(requests[#requests].name == "lite:ready", "Client must request its status")
emit("lite:stage", "login", "Log in")
emit("onClientGuiClick", "access", "login")
assert(requests[#requests].name == "lite:login", "Login click must send the request")
emit("lite:stage", "character", "Create character")
emit("onClientGuiClick", "access", "create-character")
assert(requests[#requests].name == "lite:character", "Create click must send the character name")
emit("lite:stage", "play", "Welcome")
assert(calls[#calls].kind == "hide" and calls[#calls].document == "access", "Access window must release input")
assert(calls[#calls - 1].kind == "input" and calls[#calls - 1].active == false, "Release input before hiding the window")

emit("lite:mine", "start", 3, "Watch")
emit("lite:mine", "ready", 3, "NOW")
emit("onClientGuiClick", "mine", "hit")
assert(requests[#requests].name == "lite:mine:hit" and requests[#requests].args[1] == 3,
    "Mining game must send only the current token")
emit("lite:mine", "end", 3, "Success")
assert(calls[#calls].kind == "hide" and calls[#calls].document == "mine", "Mining game must close")
assert(calls[#calls - 1].kind == "input" and calls[#calls - 1].active == false, "Mining game must release input")

inputFails = true
emit("lite:stage", "login", "Again")
assert(calls[#calls].kind == "hide", "Failed input must not cache a visible window")
inputFails = false
emit("lite:stage", "login", "Again")
assert(calls[#calls - 1].kind == "show", "GUI must reappear after an input failure")
emit("onClientResourceStop")
print("Roleplay Lite: access UI, mining game and input lifecycle passed.")
