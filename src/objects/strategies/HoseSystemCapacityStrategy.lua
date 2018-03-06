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

function HoseSystemCapacityStrategy:load() end

function HoseSystemCapacityStrategy:getIsActivatable(fillable)
    return true
end

function HoseSystemCapacityStrategy:triggerCallback(triggerId, otherActorId, onEnter, onLeave, onStay, otherShapeId)
end