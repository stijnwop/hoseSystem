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

local srcDirectory = HoseSystemFillArmFactory.baseDirectory .. 'specializations/vehicles/strategies'

local files = {
    ('%s/%s'):format(srcDirectory, 'HoseSystemDockArmStrategy.lua')
}

for _, path in pairs(files) do
    source(path)
end

local HoseSystemFillArmFactory_mt = Class(HoseSystemFillArmFactory)

---
--
function HoseSystemFillArmFactory.getInstance()
    if g_currentMission.hoseSystemFillArmFactory == nil then
        g_currentMission.hoseSystemFillArmFactory = HoseSystemFillArmFactory:new()
    end

    return g_currentMission.hoseSystemFillArmFactory
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

    if type == HoseSystemFillArm.getInitialType(HoseSystemDockArmStrategy.TYPE) then
        strategy = HoseSystemDockArmStrategy:new(object)
    end

    return strategy
end