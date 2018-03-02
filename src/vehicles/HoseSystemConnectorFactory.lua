--
-- HoseSystemConnectorFactory
--
-- Authors: Wopster
-- Description: The HoseSystem connector factory for getting strategies based on type
--
-- Copyright (c) Wopster, 2017

HoseSystemConnectorFactory = {
    baseDirectory = g_currentModDirectory
}

HoseSystemConnectorFactory.numTypes = 0
HoseSystemConnectorFactory.typesToInt = {}

-- Enums
HoseSystemConnectorFactory.TYPE_DOCK = 'dock'
HoseSystemConnectorFactory.TYPE_HOSE_COUPLING = 'hoseCoupling'
HoseSystemConnectorFactory.TYPE_TRANSFER = 'transfer'

local srcDirectory = HoseSystemConnectorFactory.baseDirectory .. 'src/vehicles/strategies'

local files = {
    ('%s/%s'):format(srcDirectory, 'HoseSystemHoseCouplingStrategy.lua'),
    ('%s/%s'):format(srcDirectory, 'HoseSystemDockStrategy.lua'),
    ('%s/%s'):format(srcDirectory, 'HoseSystemHoseTransferStrategy.lua'),
}

for _, path in pairs(files) do
    source(path)
end

local HoseSystemConnectorFactory_mt = Class(HoseSystemConnectorFactory)

---
-- @param name
--
function HoseSystemConnectorFactory.formatTypeKey(name)
    return ('connectortype_%s'):format(name:lower())
end

---
-- @param name
--
function HoseSystemConnectorFactory.registerType(name)
    local key = HoseSystemConnectorFactory.formatTypeKey(name)

    if HoseSystemConnectorFactory.typesToInt[key] == nil then
        HoseSystemConnectorFactory.numTypes = HoseSystemConnectorFactory.numTypes + 1
        HoseSystemConnectorFactory.typesToInt[key] = HoseSystemConnectorFactory.numTypes
    end
end

---
-- @param name
--
function HoseSystemConnectorFactory.getInitialType(name)
    local key = HoseSystemConnectorFactory.formatTypeKey(name)

    if HoseSystemConnectorFactory.typesToInt[key] ~= nil then
        return HoseSystemConnectorFactory.typesToInt[key]
    end

    return nil
end

---
--
function HoseSystemConnectorFactory.getInstance()
    if g_currentMission.hoseSystemConnectorFactory == nil then
        g_currentMission.hoseSystemConnectorFactory = HoseSystemConnectorFactory:new()
    end

    return g_currentMission.hoseSystemConnectorFactory
end

HoseSystemConnectorFactory.registerType(HoseSystemConnectorFactory.TYPE_DOCK)
HoseSystemConnectorFactory.registerType(HoseSystemConnectorFactory.TYPE_HOSE_COUPLING)
HoseSystemConnectorFactory.registerType(HoseSystemConnectorFactory.TYPE_TRANSFER)

---
--
function HoseSystemConnectorFactory:new()
    local factory = {}

    setmetatable(factory, HoseSystemConnectorFactory_mt)

    return factory
end

---
-- @param type
-- @param object
--
function HoseSystemConnectorFactory:getConnectorStrategy(type, object)
    local strategy

    if type == HoseSystemConnectorFactory.getInitialType(HoseSystemConnectorFactory.TYPE_HOSE_COUPLING) then
        strategy = HoseSystemHoseCouplingStrategy:new(object)
    elseif type == HoseSystemConnectorFactory.getInitialType(HoseSystemConnectorFactory.TYPE_DOCK) then
        strategy = HoseSystemDockStrategy:new(object)
    elseif type == HoseSystemConnectorFactory.getInitialType(HoseSystemConnectorFactory.TYPE_TRANSFER) then
        strategy = HoseSystemHoseTransferStrategy:new(object)
    end

    return strategy
end
