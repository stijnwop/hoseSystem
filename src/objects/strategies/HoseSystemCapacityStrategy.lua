--
-- HoseSystemCapacityStrategy
--
-- Authors: Wopster
-- Description: Strategy for capacity based fillTrigger
--
-- Copyright (c) Wopster, 2018

HoseSystemCapacityStrategy = {}

local HoseSystemCapacityStrategy_mt = Class(HoseSystemCapacityStrategy)

local defaultCapacity = 800000

---
-- @param trigger
-- @param mt
--
function HoseSystemCapacityStrategy:new(trigger, mt)
    local strategy = {
        trigger = trigger
    }

    setmetatable(strategy, mt == nil and HoseSystemCapacityStrategy_mt or mt)

    strategy.fillLevel = 0
    strategy.capacity = defaultCapacity

    return strategy
end

---
--
function HoseSystemCapacityStrategy:load()
    local capacity = getUserAttribute(self.trigger.nodeId, "capacity")

    if capacity ~= nil then
        self.capacity = Utils.getNoNil(tonumber(capacity), self.capacity)
    end

    -- Todo: only load moving plane on capacity?

    self.trigger:setFillLevel(0, nil, true)
end

---
-- @param dt
--
function HoseSystemCapacityStrategy:update(dt)
    if HoseSystemCapacityStrategy.getShowInfo(self) then
        local fillTypeName = FillUtil.fillTypeIndexToDesc[self.trigger.fillType].nameI18N
        local infoText = ("%s %s %d (%d%%)"):format(fillTypeName, g_i18n:getText("info_fillLevel"), math.floor(self.fillLevel), math.floor(100 * self.fillLevel / self.capacity))
        g_currentMission:addExtraPrintText(infoText)
    end
end

---
-- @param dt
--
function HoseSystemCapacityStrategy:updateTick(dt)
end

---
-- @param self
--
function HoseSystemCapacityStrategy.getShowInfo(self)
    if g_currentMission.controlPlayer then
        return self.trigger.playerInRange
    end

    for vehicle in pairs(self.trigger.vehiclesInRange) do
        if vehicle:getIsActiveForInput(false) then
            return true
        end
    end

    return false
end

---
-- @param fillType
--
function HoseSystemCapacityStrategy:getFillLevel(fillType)
    if fillType == nil then
        return self.fillLevel
    end

    return fillType == self.trigger.fillType and self.fillLevel or 0
end

---
-- @param fillLevel
-- @param delta
-- @param noEventSend
--
function HoseSystemCapacityStrategy:setFillLevel(fillLevel, delta, noEventSend)
    fillLevel = Utils.clamp(fillLevel, 0, self.capacity)

    if self.fillLevel ~= fillLevel then
        self.fillLevel = fillLevel

        if self.trigger.isClient then
            -- Todo: handle plane y trans
        end
    end
end

---
-- @param fillType
--
function HoseSystemCapacityStrategy:getCapacity(fillType)
    if fillType == nil then
        return self.capacity
    end

    return fillType == self.trigger.fillType and self.capacity or 0
end

---
-- @param fillType
--
function HoseSystemCapacityStrategy:getFreeCapacity(fillType)
    return self:getCapacity(fillType) - self:getFillLevel(fillType)
end

---
-- @param fillable
--
function HoseSystemCapacityStrategy:getIsActivatable(fillable)
    if self.fillLevel <= 0 then
        return false
    end

    return true
end

---
-- @param triggerId
-- @param otherActorId
-- @param onEnter
-- @param onLeave
-- @param onStay
-- @param otherShapeId
--
function HoseSystemCapacityStrategy:triggerCallback(triggerId, otherActorId, onEnter, onLeave, onStay, otherShapeId)
end