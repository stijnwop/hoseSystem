--
-- Bootstrap
--
-- Authors: Wopster
-- Description: Bootstraps the mod and support the farmsim tool
--
-- Copyright (c) Wopster, 2018

local srcDirectory = g_currentModDirectory .. "specializations"

-- variables controlled by the farmsim tool
local debugRendering = false --<%=debug %>
local isNoRestart = false --<%=norestart %>

-- Source files
local files = {
    -- main
    ('%s/%s'):format(srcDirectory, 'HoseSystemRegistrationHelper'),
    -- utilities
    ('%s/utils/%s'):format(srcDirectory, 'HoseSystemUtil'),
    ('%s/utils/%s'):format(srcDirectory, 'HoseSystemXMLUtil'),
    -- map objects
    ('%s/objects/%s'):format(srcDirectory, 'AnimatedObjectExtension'),
    ('%s/objects/%s'):format(srcDirectory, 'HoseSystemLiquidManureFillTrigger'),
    -- multiplayer events
    ('%s/events/%s'):format(srcDirectory, 'HoseSystemReferenceIsUsedEvent'),
    ('%s/events/%s'):format(srcDirectory, 'HoseSystemReferenceLockEvent'),
    ('%s/events/%s'):format(srcDirectory, 'HoseSystemReferenceManureFlowEvent'),
}

---
-- Compatibility: Lua-5.1
-- http://lua-users.org/wiki/SplitJoin
-- @param str
-- @param pat
--
local function split(str, pat)
    local t = {} -- NOTE: use {n = 0} in Lua-5.0
    local fpat = "(.-)" .. pat
    local last_end = 1
    local s, e, cap = str:find(fpat, 1)

    while s do
        if s ~= 1 or cap ~= "" then
            table.insert(t, cap)
        end
        last_end = e + 1
        s, e, cap = str:find(fpat, last_end)
    end

    if last_end <= #str then
        cap = str:sub(last_end)
        table.insert(t, cap)
    end

    return t
end

-- Insert class name to preload
local classes = {}

for _, directory in pairs(files) do
    local splittedPath = split(directory, "[\\/]+")
    table.insert(classes, splittedPath[#splittedPath])

    source(directory .. ".lua")
end

---
--
local function loadHoseSystem()
    for i, _ in pairs(files) do
        local class = classes[i]

        if _G[class] ~= nil and _G[class].preLoadHoseSystem ~= nil then
            _G[class]:preLoadHoseSystem()
        end
    end
end

-- Vehicle specializations
local specializations = {
    ["hoseSystemConnector"] = ('%s/vehicles/'):format(srcDirectory),
    ["hoseSystemPumpMotor"] = ('%s/vehicles/'):format(srcDirectory),
    ["hoseSystemFillArm"] = ('%s/vehicles/'):format(srcDirectory)
}

for name, directory in pairs(specializations) do
    if SpecializationUtil.specializations[name] == nil then
        local classname = HoseSystemUtil:firstToUpper(name)
        SpecializationUtil.registerSpecialization(name, classname, directory .. classname .. ".lua")
    end
end

-- Hook on early load
Mission00.load = Utils.prependedFunction(Mission00.load, loadHoseSystem)