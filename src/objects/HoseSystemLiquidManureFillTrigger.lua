--
-- HoseSystemLiquidManureFillTrigger
--
-- Authors: Wopster
-- Description: Overwritten liquidManureTrigger to function with the HoseSystem
--
-- Copyright (c) Wopster, 2018

HoseSystemLiquidManureFillTrigger = {}

---
--
function HoseSystemLiquidManureFillTrigger:preLoadHoseSystem()
    LiquidManureFillTrigger.new = Utils.overwrittenFunction(LiquidManureFillTrigger.new, HoseSystemLiquidManureFillTrigger.new)
end

---
-- @param superFunc
-- @param mt
--
function HoseSystemLiquidManureFillTrigger:new(superFunc, mt)
    local trigger = HoseSystemFillTrigger:new(g_server ~= nil, g_client ~= nil, mt, nil, "capacity", true)

    -- set the static fillType to allow the trigger being registered in the base mission
    trigger.fillType = FillUtil.FILLTYPE_LIQUIDMANURE

    return trigger
end