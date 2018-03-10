--
-- HoseSystemExpensesStrategy
--
-- Authors: Wopster
-- Description: Strategy for mimicking an expenses based fillTrigger
--
-- Copyright (c) Wopster, 2018

HoseSystemExpensesStrategy = {}

HoseSystemExpensesStrategy.fillTypeToFinanceCategories = {
    [FillUtil.FILLTYPE_WATER] = "purchaseWater",
    [FillUtil.FILLTYPE_FERTILIZER] = "purchaseFertilizer"
}

local unlimitedCapacity = math.huge -- inf
local freeCapacity = 1000 ^ 2

local HoseSystemExpensesStrategy_mt = Class(HoseSystemExpensesStrategy)

---
-- @param trigger
-- @param mt
--
function HoseSystemExpensesStrategy:new(trigger, mt)
    local strategy = {
        trigger = trigger
    }

    setmetatable(strategy, mt == nil and HoseSystemExpensesStrategy_mt or mt)

    strategy.delta = 0

    return strategy
end

---
--
function HoseSystemExpensesStrategy:load()
    self.priceScale = Utils.getNoNil(getUserAttribute(self.trigger.nodeId, "priceScale"), 1)

    local financeCategory = HoseSystemExpensesStrategy.fillTypeToFinanceCategories[self.trigger.fillType]
    self.financeCategory = financeCategory ~= nil and financeCategory or "other"
end

---
--
function HoseSystemExpensesStrategy:postLoad()
end

---
--
function HoseSystemExpensesStrategy:delete()
end

---
-- @param fillType
--
function HoseSystemExpensesStrategy:getFillLevel(fillType)
    local objectLevel = self.object:getFillLevel(fillType)

    if objectLevel == 0 then
        -- when empty we mimic a fillLevel to set delta
        objectLevel = self.object.pumpFillEfficiency.litersPerSecond
    end

    return objectLevel
end

---
-- @param fillLevel
-- @param noEventSend
-- @param delta
--
function HoseSystemExpensesStrategy:setFillLevel(fillLevel, noEventSend, delta)
    if delta ~= 0 and self.priceScale > 0 then
        local isAllowedExpense = true

        -- restrict to get profit from water
        if delta < 0 then
            isAllowedExpense = self.trigger.fillType ~= FillUtil.FILLTYPE_WATER
        end

        if isAllowedExpense then
            local price = delta * g_currentMission.economyManager:getPricePerLiter(self.trigger.fillType) * self.priceScale
            g_currentMission.missionStats:updateStats("expenses", price)
            g_currentMission:addSharedMoney(-price, self.financeCategory)
        end
    end
end

---
-- @param fillType
--
function HoseSystemExpensesStrategy:getCapacity(fillType)
    return unlimitedCapacity
end

---
-- @param fillType
--
function HoseSystemExpensesStrategy:getFreeCapacity(fillType)
    return freeCapacity
end

---
-- @param fillable
--
function HoseSystemExpensesStrategy:getIsActivatable(fillable)
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
function HoseSystemExpensesStrategy:triggerCallback(triggerId, otherActorId, onEnter, onLeave, onStay, otherShapeId)
    -- Todo: merge this with the super class trigger callback.
    if self.trigger.isEnabled and (onEnter or onLeave) then
        if otherActorId ~= 0 then
            local object = g_currentMission.nodeToVehicle[otherActorId]

            if object ~= nil and object ~= self.object and object.hasHoseSystem then
                self.object = onEnter and object or nil
            end
        end
    end
end