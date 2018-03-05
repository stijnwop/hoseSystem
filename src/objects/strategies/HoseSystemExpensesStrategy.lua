--
-- HoseSystemExpensesStrategy
--
-- Authors: Wopster
-- Description: Strategy for mimicking an expenses based fillTrigger
--
-- Copyright (c) Wopster, 2018

HoseSystemExpensesStrategy = {}

local unlimitedCapacity = math.huge

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

    return strategy
end

function HoseSystemExpensesStrategy:getFillLevel(fillType)
    local objectLevel = self.object:getFillLevel(fillType)
    print(objectLevel)

    return objectLevel
end

function HoseSystemExpensesStrategy:getCapacity(fillType)
    return unlimitedCapacity
end

function HoseSystemExpensesStrategy:getFreeCapacity(fillType)
    return 1000
end

function HoseSystemExpensesStrategy:getIsActivatable(fillable)
    return true
end

function HoseSystemExpensesStrategy:triggerCallback(triggerId, otherActorId, onEnter, onLeave, onStay, otherShapeId)
    if (onEnter or onLeave) then
        if otherActorId ~= 0 then
            local object = g_currentMission.nodeToVehicle[otherActorId]

            if object ~= nil and object.hasHoseSystem then
                self.object = object
            end
        end
    end
end