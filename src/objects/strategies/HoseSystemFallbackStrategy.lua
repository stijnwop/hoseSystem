--
-- HoseSystemFallbackStrategy
--
-- Authors: Wopster
-- Description: Strategy for fallbacks on vanilla triggers. This enables non hose system vehicles to interact.
--
-- Copyright (c) Wopster, 2018

HoseSystemFallbackStrategy = {}

local HoseSystemFallbackStrategy_mt = Class(HoseSystemFallbackStrategy)

---
-- @param trigger
-- @param mt
--
function HoseSystemFallbackStrategy:new(trigger, mt)
    local strategy = {
        trigger = trigger
    }

    setmetatable(strategy, mt == nil and HoseSystemFallbackStrategy_mt or mt)

    -- Since giants uses different naming/logic on the water triggers we support a fallback

    -- fill fallback functions WaterTrailerFillTrigger
    trigger.triggeredTrailers = {}
    trigger.onVehicleDeleted = WaterTrailerFillTrigger.onVehicleDeleted
    trigger.fillWater = WaterTrailerFillTrigger.fillWater

    -- fill fallback functions LiquidManureFillTrigger
    trigger.fillableObjects = {}
    trigger.fill = LiquidManureFillTrigger.fill

    g_currentMission:addNonUpdateable(strategy)

    return strategy
end

function HoseSystemFallbackStrategy:delete()
    for fillable, _ in pairs(self.trigger.triggeredTrailers) do
        if fillable ~= nil and fillable.removeWaterTrailerFillTrigger ~= nil then
            fillable:removeWaterTrailerFillTrigger(self.trigger)
        end
    end

    for _, fillable in pairs(self.trigger.fillableObjects) do
        if fillable ~= nil and fillable.removeFillTrigger ~= nil then
            fillable:removeFillTrigger(self.trigger)
        end
    end

    g_currentMission:removeNonUpdateable(self)
end

function HoseSystemFallbackStrategy:getIsActivatable(fillable)
    return self.trigger:getIsActivatable(fillable)
end

function HoseSystemFallbackStrategy:triggerCallback(triggerId, otherActorId, onEnter, onLeave, onStay, otherShapeId)
    if self.trigger.isEnabled and (onEnter or onLeave) then
        local fillable = Utils.getNoNil(g_currentMission.objectToTrailer[otherShapeId], g_currentMission.objectToTrailer[otherActorId])

        if fillable ~= nil and fillable.hasHoseSystem == nil then
            if fillable.addFillTrigger ~= nil and fillable.removeFillTrigger ~= nil then
                if onEnter then
                    if self.trigger.fillableObjects[fillable] == nil and fillable:allowFillType(self.trigger.fillType, false) then
                        fillable:addFillTrigger(self.trigger)
                        self.trigger.fillableObjects[fillable] = fillable
                    end
                else -- onLeave
                    fillable:removeFillTrigger(self.trigger)

                    if self.trigger.financeCategory ~= nil then
                        g_currentMission:showMoneyChange(self.moneyChangeId, g_i18n:getText("finance_" .. self.trigger.financeCategory))
                    end

                    self.trigger.fillableObjects[fillable] = nil
                end
            end

            if fillable.addWaterTrailerFillTrigger ~= nil and fillable.removeWaterTrailerFillTrigger ~= nil then
                if onEnter then
                    self.trigger.triggeredTrailers[fillable] = fillable
                    fillable:addWaterTrailerFillTrigger(self.trigger)
                else -- onLeave
                    self.trigger.triggeredTrailers[fillable] = nil
                    fillable:removeWaterTrailerFillTrigger(self.trigger)
                end
            end
        end
    end
end

