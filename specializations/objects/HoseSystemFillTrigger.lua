--
-- HoseSystemFillTrigger
--
-- Authors: Wopster
-- Description: Base class for the HoseSystemFillTrigger
--
-- Copyright (c) Wopster, 2018

HoseSystemFillTrigger = {}

HoseSystemFillTrigger.TRIGGER_CALLBACK = "triggerCallback"

local HoseSystemFillTrigger_mt = Class(HoseSystemFillTrigger)

function HoseSystemFillTrigger:preLoadHoseSystem()
end

---
-- @param mt
-- @param nodeId
--
function HoseSystemFillTrigger:new(mt, nodeId, strategyType)
    local mt = mt == nil and HoseSystemFillTrigger_mt or mt

    local trigger = {}
    setmetatable(trigger, mt)

    trigger.triggerId = nil
    trigger.nodeId = nodeId

    local strategy = HoseSystemExpensesStrategy:new(trigger, mt)

    trigger.strategy = strategy

    return trigger
end

---
-- @param nodeId
-- @param fillType
--
function HoseSystemFillTrigger:load(nodeId, fillType)
    print("are we called from the watertrigger?")
    if self.nodeId == nil then
        self.nodeId = nodeId
    end

    self.triggerId = Utils.indexToObject(nodeId, getUserAttribute(nodeId, "triggerIndex"))

    if self.triggerId == nil then
        self.triggerId = nodeId
    end

    addTrigger(self.triggerId, HoseSystemFillTrigger.TRIGGER_CALLBACK, self.strategy)

    self.fillType = fillType ~= nil and fillType or HoseSystemFillTrigger.getFillTypeFromUserAttribute(nodeId)

    self.isEnabled = true
end

function HoseSystemFillTrigger:delete()
    print("are we called from the watertrigger?")
    removeTrigger(self.triggerId)
end

function HoseSystemFillTrigger:getIsActivatable(fillable)
    if not self.strategy:getIsActivatable(fillable) then
        return false
    end

    if not fillable:allowFillType(self.fillType, false) then
        return false
    end

    return true
end

function HoseSystemFillTrigger.getFillTypeFromUserAttribute(nodeId)
    local fillTypeStr = getUserAttribute(nodeId, "fillType")

    if fillTypeStr ~= nil then
        local desc = FillUtil.fillTypeNameToDesc[fillTypeStr]

        if desc ~= nil then
            return desc.index
        end
    end

    return FillUtil.FILLTYPE_UNKNOWN
end


