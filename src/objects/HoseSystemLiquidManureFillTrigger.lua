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
    LiquidManureFillTrigger.load = Utils.overwrittenFunction(LiquidManureFillTrigger.load, HoseSystemLiquidManureFillTrigger.load)
end

---
-- @param superFunc
-- @param nodeId
-- @param fillLevelObject
-- @param fillType
--
function HoseSystemLiquidManureFillTrigger:load(superFunc, nodeId, fillLevelObject, fillType)
    if not HoseSystemObjectsUtil.getHasXMLAttribute(nodeId) then
        return superFunc(self, nodeId, fillLevelObject, fillType)
    end

    self = HoseSystemFillTrigger:new(g_server ~= nil, g_client ~= nil, mt, nil, "capacity", true)

    -- set the static fillType to allow the trigger being registered in the base mission
    self.fillType = FillUtil.FILLTYPE_LIQUIDMANURE

    -- Register correct metatable on the fillLevelObject
    if fillLevelObject.digestateSiloTrigger ~= nil then
        fillLevelObject.digestateSiloTrigger = self
    end

    if fillLevelObject.liquidManureTrigger ~= nil then
        fillLevelObject.liquidManureTrigger = self
    end

    return self:load(nodeId, fillLevelObject, fillType)
end
