--
-- HoseSystemFillArmFactory
--
-- Authors: Wopster
-- Description: The HoseSystem fillArm factory for getting strategies based on type
--
-- Copyright (c) Wopster, 2017

HoseSystemFillArmFactory = {
    baseDirectory = g_currentModDirectory
}

HoseSystemFillArmFactory.typesToInt = {}

-- Enums
HoseSystemFillArmFactory.TYPE_DOCK = 'dock'

local srcDirectory = HoseSystemFillArmFactory.baseDirectory .. 'specializations/vehicles/strategies'

local files = {
    ('%s/%s'):format(srcDirectory, 'HoseSystemDockArmStrategy.lua')
}

for _, path in pairs(files) do
    source(path)
end

local HoseSystemFillArmFactory_mt = Class(HoseSystemFillArmFactory)

---
-- @param name
--
function HoseSystemFillArmFactory.formatTypeKey(name)
    return ('fillarmtype_%s'):format(name:lower())
end

---
-- @param name
--
function HoseSystemFillArmFactory.registerType(name)
    local key = HoseSystemFillArmFactory.formatTypeKey(name)

    if HoseSystemFillArmFactory.typesToInt[key] == nil then
        HoseSystemFillArmFactory.typesToInt[key] = #HoseSystemFillArmFactory.typesToInt + 1
    end
end

---
-- @param name
--
function HoseSystemFillArmFactory.getInitialType(name)
    local key = HoseSystemFillArmFactory.formatTypeKey(name)

    if HoseSystemFillArmFactory.typesToInt[key] ~= nil then
        return HoseSystemFillArmFactory.typesToInt[key]
    end

    return nil
end

---
--
function HoseSystemFillArmFactory.getInstance()
    if g_currentMission.hoseSystemFillArmFactory == nil then
        g_currentMission.hoseSystemFillArmFactory = HoseSystemFillArmFactory:new()
    end

    return g_currentMission.hoseSystemFillArmFactory
end

HoseSystemFillArmFactory.registerType(HoseSystemFillArmFactory.TYPE_DOCK)

---
--
function HoseSystemFillArmFactory:new()
    local factory = {}

    setmetatable(factory, HoseSystemFillArmFactory_mt)

    return factory
end

---
-- @param type
-- @param object
--
function HoseSystemFillArmFactory:getFillArmStrategy(type, object)
    local strategy

    if type == HoseSystemFillArmFactory.getInitialType(HoseSystemFillArmFactory.TYPE_DOCK) then
        strategy = HoseSystemDockArmStrategy:new(object)
    end

    return strategy
end