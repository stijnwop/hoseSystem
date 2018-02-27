--
-- HoseSystemExpensesStrategy
--
-- Authors: Wopster
-- Description: Strategy for mimicking an expenses based fillTrigger
--
-- Copyright (c) Wopster, 2018

HoseSystemExpensesStrategy = {}

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

function HoseSystemExpensesStrategy:getIsActivatable(fillable)
    return true
end

function HoseSystemExpensesStrategy:triggerCallback(triggerId, otherActorId, onEnter, onLeave, onStay, otherShapeId)
end