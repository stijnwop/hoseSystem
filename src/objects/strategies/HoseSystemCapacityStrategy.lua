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

    trigger.fillLevel = 0
    trigger.capacity = defaultCapacity

    return strategy
end

---
--
function HoseSystemCapacityStrategy:load()
    local capacity = getUserAttribute(self.trigger.nodeId, "capacity")

    if capacity ~= nil then
        self.trigger.capacity = Utils.getNoNil(tonumber(capacity), self.capacity)
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
        local infoText = ("%s %s %d (%d%%)"):format(fillTypeName, g_i18n:getText("info_fillLevel"), math.floor(self.trigger.fillLevel), math.floor(100 * self.trigger.fillLevel / self.trigger.capacity))
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
        return self.trigger.fillLevel
    end

    return fillType == self.trigger.fillType and self.trigger.fillLevel or 0
end

---
-- @param fillLevel
-- @param delta
-- @param noEventSend
--
function HoseSystemCapacityStrategy:setFillLevel(fillLevel, delta, noEventSend)
    fillLevel = Utils.clamp(fillLevel, 0, self.trigger.capacity)

    if self.trigger.fillLevel ~= fillLevel then
        self.trigger.fillLevel = fillLevel

        if self.trigger.isClient then
            if self.trigger.movingId ~= nil then
                local x, _, z = getTranslation(self.trigger.movingId)
                local y = self.trigger.moveMinY + (self.trigger.moveMaxY - self.trigger.moveMinY) * self.fillLevel / self.capacity
                setTranslation(self.trigger.movingId, x, y, z)
            end
        end
    end
end

---
-- @param fillType
--
function HoseSystemCapacityStrategy:getCapacity(fillType)
    if fillType == nil then
        return self.trigger.capacity
    end

    return fillType == self.trigger.fillType and self.trigger.capacity or 0
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
    if self.trigger.fillLevel <= 0 then
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