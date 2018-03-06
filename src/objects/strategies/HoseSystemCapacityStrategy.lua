--
-- HoseSystemCapacityStrategy
--
-- Authors: Wopster
-- Description: Strategy for capacity based fillTrigger
--
-- Copyright (c) Wopster, 2018

HoseSystemCapacityStrategy = {}

local HoseSystemCapacityStrategy_mt = Class(HoseSystemCapacityStrategy)

---
-- @param trigger
-- @param mt
--
function HoseSystemCapacityStrategy:new(trigger, mt)
    local strategy = {
        trigger = trigger
    }

    setmetatable(strategy, mt == nil and HoseSystemCapacityStrategy_mt or mt)

    return strategy
end
---
--
function HoseSystemCapacityStrategy:load() end

---
-- @param fillType
--
function HoseSystemCapacityStrategy:getCapacity(fillType)
    return 0
end

---
-- @param fillType
--
function HoseSystemCapacityStrategy:getFreeCapacity(fillType)
    return 0
end

---
-- @param fillable
--
function HoseSystemCapacityStrategy:getIsActivatable(fillable)
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