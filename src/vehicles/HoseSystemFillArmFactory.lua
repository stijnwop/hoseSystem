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

HoseSystemFillArmFactory.numTypes = 0
HoseSystemFillArmFactory.typesToInt = {}

-- Enums
HoseSystemFillArmFactory.TYPE_DOCK = 'dock'
HoseSystemFillArmFactory.TYPE_ARM = 'arm'


local HoseSystemFillArmFactory_mt = Class(HoseSystemFillArmFactory)

---
--
function HoseSystemFillArmFactory:preLoadHoseSystem()
    local srcDirectory = g_hoseSystem.baseDirectory .. 'src/vehicles/strategies'

    local files = {
        ('%s/%s'):format(srcDirectory, 'HoseSystemDockArmStrategy.lua'),
        ('%s/%s'):format(srcDirectory, 'HoseSystemArmStrategy.lua')
    }

    for _, path in pairs(files) do
        source(path)
    end

    HoseSystemFillArmFactory.registerType(HoseSystemFillArmFactory.TYPE_DOCK)
    HoseSystemFillArmFactory.registerType(HoseSystemFillArmFactory.TYPE_ARM)
end

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
        HoseSystemFillArmFactory.numTypes = HoseSystemFillArmFactory.numTypes + 1
        HoseSystemFillArmFactory.typesToInt[key] = HoseSystemFillArmFactory.numTypes
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
    if g_hoseSystem.hoseSystemFillArmFactory == nil then
        g_hoseSystem.hoseSystemFillArmFactory = HoseSystemFillArmFactory:new()
    end

    return g_hoseSystem.hoseSystemFillArmFactory
end

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
    elseif type == HoseSystemFillArmFactory.getInitialType(HoseSystemFillArmFactory.TYPE_ARM) then
        strategy = HoseSystemArmStrategy:new(object)
    end

    return strategy
end
