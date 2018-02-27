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
-- @param trailer
--
function HoseSystemWaterTrailerFillTrigger:new(superFunc, nodeId, trailer)
    local strategy = getUserAttribute(nodeId, "strategy")

    if strategy == nil then
        return superFunc(self, nodeId, trailer)
    end

    return HoseSystemFillTrigger:new(nil, nodeId, strategy)
end

WaterTrailerFillTrigger.new = Utils.overwrittenFunction(WaterTrailerFillTrigger.new, HoseSystemWaterTrailerFillTrigger.new)
