--
-- HoseSystemWaterTrailerFillTrigger
--
-- Authors: Wopster
-- Description: Overwritten class of the default WaterTrailerFillTrigger to work with the Hose System
--
-- Copyright (c) Wopster, 2018

HoseSystemWaterTrailerFillTrigger = {}

function HoseSystemWaterTrailerFillTrigger:preLoadHoseSystem()
    -- call the preLoad to do clean overwrites with a loader eg.
end

---
-- @param superFunc
-- @param nodeId
--
function HoseSystemWaterTrailerFillTrigger:onCreate(superFunc, nodeId)
    local strategy = getUserAttribute(nodeId, "strategy")

    if strategy == nil then
        return superFunc(self, nodeId)
    end

    return WaterTrailerFillTrigger:new(nodeId)
end

---
-- @param superFunc
-- @param nodeId
-- @param trailer
--
function HoseSystemWaterTrailerFillTrigger:new(superFunc, nodeId, trailer)
    local strategy = getUserAttribute(nodeId, "strategy")

    if strategy == nil then
        return superFunc(self, nodeId, trailer)
    end

    local trigger = HoseSystemFillTrigger:new(g_server ~= nil, g_client ~= nil, nil, nodeId, strategy)
    print("Object id = " .. trigger.id)

    if trigger:load(nodeId, FillUtil.FILLTYPE_WATER) then
        --        g_currentMission:addOnCreateLoadedObject(trigger)
    end

    return trigger
end

WaterTrailerFillTrigger.onCreate = Utils.overwrittenFunction(WaterTrailerFillTrigger.onCreate, HoseSystemWaterTrailerFillTrigger.onCreate)
WaterTrailerFillTrigger.new = Utils.overwrittenFunction(WaterTrailerFillTrigger.new, HoseSystemWaterTrailerFillTrigger.new)
