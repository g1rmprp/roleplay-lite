LITE_DB = { handle = false, fault = false, stopped = false, pendingWrites = 0 }

function LITE_DB.open()
    if LITE_DB.stopped then return false end
    local c = LITE_CONFIG.database
    local handle = dbConnect("mysql", c.connection, c.username, c.password, c.options)
    if not handle then
        outputDebugString("[Roleplay Lite] Database connection failed.", 1)
        return false
    end
    LITE_DB.handle = handle
    return true
end

function LITE_DB.close()
    LITE_DB.stopped = true
    if LITE_DB.pendingWrites > 0 then
        outputDebugString("[Roleplay Lite] Resource stopped with pending writes; verify the database state.", 1)
    end
    local handle = LITE_DB.handle
    LITE_DB.handle = false
    if handle then dbClose(handle) end
end

-- Queries run in order on the same connection. A failed write may have an
-- unknown commit outcome and blocks further changes.
function LITE_DB.query(statement, parameters, callback, writing)
    if LITE_DB.stopped or LITE_DB.fault or not LITE_DB.handle then return false end
    local handle = LITE_DB.handle
    local unpackValues = (table and table.unpack) or unpack
    parameters = parameters or {}
    if writing then LITE_DB.pendingWrites = LITE_DB.pendingWrites + 1 end
    local queued = dbQuery(function(queryHandle)
        local rows, count, insertId = dbPoll(queryHandle, 0)
        if writing then LITE_DB.pendingWrites = LITE_DB.pendingWrites - 1 end
        if LITE_DB.stopped or handle ~= LITE_DB.handle then return end
        if rows == false or rows == nil then
            if writing then
                LITE_DB.fault = true
                outputDebugString("[Roleplay Lite] Write outcome unknown; further database operations blocked.", 1)
            end
            callback(false, count, insertId)
            return
        end
        callback(rows, tonumber(count) or 0, tonumber(insertId) or 0)
    end, {}, handle, statement, unpackValues(parameters))
    if not queued then
        if writing then LITE_DB.pendingWrites = LITE_DB.pendingWrites - 1 end
        if writing then
            LITE_DB.fault = true
            outputDebugString("[Roleplay Lite] Write request rejected; further database operations blocked.", 1)
        end
        return false
    end
    return true
end
