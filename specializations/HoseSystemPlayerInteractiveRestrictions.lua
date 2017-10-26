--
-- HoseSystemPlayerInteractiveRestrictions
--
-- Authors: Wopster
-- Description: Class to handle the hose system restrictions
--
-- Copyright (c) Wopster, 2017

HoseSystemPlayerInteractiveRestrictions = {}

HoseSystemPlayerInteractiveRestrictions.RESPAWN_OFFSET = 0.00001
HoseSystemPlayerInteractiveRestrictions.STRETCH_PERCENTAGE = 1.15 -- %
HoseSystemPlayerInteractiveRestrictions.MAX_HOSECHAIN_COUNT = 4

HoseSystemPlayerInteractiveRestrictions.BLINKING_WARNING_TIME = 5000 -- ms
HoseSystemPlayerInteractiveRestrictions.CHECK_TRESHOLD_TIME = 750 -- ms

local HoseSystemPlayerInteractiveRestrictions_mt = Class(HoseSystemPlayerInteractiveRestrictions, HoseSystemPlayerInteractive)

---
-- @param object
-- @param mt
--
function HoseSystemPlayerInteractiveRestrictions:new(object, mt)
    local playerInteractiveRestrictions = {
        object = object
    }

    setmetatable(playerInteractiveRestrictions, mt == nil and HoseSystemPlayerInteractiveRestrictions_mt or mt)

    playerInteractiveRestrictions.lastInRangePosition = { 0, 0, 0 }
    playerInteractiveRestrictions.rangeRestrictionMessageShown = false
    playerInteractiveRestrictions.currentChainCount = 0
    playerInteractiveRestrictions.lastRestrictCheckTime = 0

    return playerInteractiveRestrictions
end

---
--
function HoseSystemPlayerInteractiveRestrictions:delete()
    HoseSystemPlayerInteractiveRestrictions:superClass().delete(self)
end

---
-- @param dt
--
function HoseSystemPlayerInteractiveRestrictions:update(dt)
    HoseSystemPlayerInteractiveRestrictions:superClass().update(self, dt)

    if not self.object.isServer then
        return
    end

    if self.object.grabPoints ~= nil then
        for _, grabPoint in pairs(self.object.grabPoints) do
            if grabPoint ~= nil then
                if grabPoint.isOwned then
                    self:restrictPlayerDistance(dt, grabPoint)
                else
                    self:restrictReferenceDistance(dt, grabPoint)
                end
            end
        end
    end
end

---
--
function HoseSystemPlayerInteractiveRestrictions:draw()
end

---
-- @param dt
-- @param grabPoint
--
function HoseSystemPlayerInteractiveRestrictions:restrictPlayerDistance(dt, grabPoint)
    local player = grabPoint.currentOwner

    if player ~= nil and player.positionIsDirty then
        if player.hoseSystem.interactiveHandling ~= nil and grabPoint.id == player.hoseSystem.index then
            if HoseSystem:getIsAttached(grabPoint.state) then
                local dependentGrabpoint = HoseSystemUtil:getDependentGrabPoint(self.object.grabPoints, grabPoint.id, true, false)

                if dependentGrabpoint ~= nil then
                    -- If we have a player use the grabpoint as reference
                    local reference = HoseSystem:getIsConnected(dependentGrabpoint.state) and HoseSystemReferences:getReference(dependentGrabpoint.connectorVehicle, dependentGrabpoint.connectorRefId, dependentGrabpoint) or dependentGrabpoint

                    if reference == nil then
                        return
                    end

                    if HoseSystem:getIsConnected(dependentGrabpoint.state) and HoseSystemPlayerInteractiveRestrictions:getIsVehicleAboveSpeedLimit(dependentGrabpoint.connectorVehicle, 1) then
                        return
                    end

                    local x, y, z = getWorldTranslation(reference.node)
                    local px, py, pz = getWorldTranslation(player.rootNode)
                    local dx, dz = px - x, pz - z
                    local radius = dx * dx + dz * dz
                    local length = self.object.data.length
                    --                                local actionRadius = self.currentChainCount > 1 and (length * length) * 1.2 or length * length -- give it some space when moving a chain because well..
                    local actionRadius = length * length
                    local playerHeight = math.abs(py - y)

                    -- Player height difference is not the full hose lenght since there's always a curve on the hose that will give some lenght loss
                    if radius < actionRadius and playerHeight < length / 2 then
                        self.lastInRangePosition = { getTranslation(player.rootNode) }
                    else
                        local kx, ky, kz = getWorldTranslation(reference.node)
                        local px, py, pz = getWorldTranslation(player.rootNode)
                        local distance = Utils.vector2Length(px - kx, pz - kz)

                        x = kx + ((px - kx) / distance) * (length - HoseSystemPlayerInteractiveRestrictions.RESPAWN_OFFSET * dt)
                        -- x = kx + ((px - kx) / distance) * (self.hose.length * (self.currentChainCount - 1) - HoseSystemPlayerInteractiveRestrictions.RESPAWN_OFFSET * dt)
                        y = ky + ((py - ky) / Utils.vector2Length(px - kx, py - ky)) * (length / 2 - HoseSystemPlayerInteractiveRestrictions.RESPAWN_OFFSET * dt)

                        -- Prevent from spawning into the ground
                        if y < ky and py > y then
                            y = py
                        end

                        -- y =
                        z = kz + ((pz - kz) / distance) * (length - HoseSystemPlayerInteractiveRestrictions.RESPAWN_OFFSET * dt)
                        -- z = kz + ((pz - kz) / distance) * (self.hose.length * (self.currentChainCount - 1) - HoseSystemPlayerInteractiveRestrictions.RESPAWN_OFFSET * dt)

                        player:moveToAbsoluteInternal(x, y, z)
                        self.lastInRangePosition = { x, y, z }

                        if not self.rangeRestrictionMessageShown and player == g_currentMission.player then
                            self.rangeRestrictionMessageShown = true
                            g_currentMission:showBlinkingWarning(g_i18n:getText('info_hoseRangeRestriction'), HoseSystemPlayerInteractiveRestrictions.BLINKING_WARNING_TIME)
                        end
                    end
                end
            end
        end

        if self.currentChainCount >= HoseSystemPlayerInteractiveRestrictions.MAX_HOSECHAIN_COUNT then
            player.walkingIsLocked = true

            if not self.playerRestrictionChainToLongShown and player == g_currentMission.player then
                self.playerRestrictionChainToLongShown = true
                g_currentMission:showBlinkingWarning(g_i18n:getText('info_hoseRangeRestrictionChainToLong'), HoseSystemPlayerInteractiveRestrictions.BLINKING_WARNING_TIME)
            end
        else
            player.walkingIsLocked = false

            if self.currentChainCount > 1 then
                player.walkingSpeed = self.walkingSpeed / ((self.object.data.length / self.object.data.length) * self.currentChainCount)
                player.runningFactor = self.runningFactor / ((self.object.data.length / self.object.data.length) * self.currentChainCount)
            end
        end
    end
end

---
-- @param dt
-- @param grabPoint
--
function HoseSystemPlayerInteractiveRestrictions:restrictReferenceDistance(dt, grabPoint)
    if self.lastRestrictCheckTime < g_currentMission.time and HoseSystem:getIsConnected(grabPoint.state) then
        local dependentGrabpoint = HoseSystemUtil:getDependentGrabPoint(self.object.grabPoints, grabPoint.id, true, true)

        if dependentGrabpoint ~= nil then
            if HoseSystemPlayerInteractiveRestrictions:getIsVehicleAboveSpeedLimit(grabPoint.connectorVehicle, 1) then -- only detach from the speeding side
                local reference = HoseSystemReferences:getReference(grabPoint.connectorVehicle, grabPoint.connectorRefId, grabPoint)

                if reference ~= nil and not reference.connectable and not reference.parkable then
                    local ax, ay, az = getWorldTranslation(self.object.components[grabPoint.componentIndex].node)
                    local bx, by, bz = getWorldTranslation(self.object.components[dependentGrabpoint.componentIndex].node)
                    local distance = Utils.vector3Length(bx - ax, by - ay, bz - az)
                    local allowedDistance = self.object.data.length * HoseSystemPlayerInteractiveRestrictions.STRETCH_PERCENTAGE -- give it a bit more space to move

                    if distance > allowedDistance or distance < (allowedDistance - 1) then
                        if HoseSystem.debugRendering then
                            HoseSystemUtil:log(HoseSystemUtil.DEBUG, 'Restriction detach distance: ' .. distance)
                        end

                        if HoseSystem:getIsAttached(dependentGrabpoint.state) then
                            self.object.poly.interactiveHandling:drop(dependentGrabpoint.id, dependentGrabpoint.currentOwner)
                        else
                            self.object.poly.interactiveHandling:detach(grabPoint.id, grabPoint.connectorVehicle, grabPoint.connectorRefId, reference.connectable ~= nil and reference.connectable)
                        end

                        self.lastRestrictCheckTime = g_currentMission.time + HoseSystemPlayerInteractiveRestrictions.CHECK_TRESHOLD_TIME
                    end
                end
            end
        end
    end
end

---
-- @param vehicle
-- @param limit
--
function HoseSystemPlayerInteractiveRestrictions:getIsVehicleAboveSpeedLimit(vehicle, limit)
    return vehicle ~= nil and vehicle.getLastSpeed ~= nil and vehicle:getLastSpeed() > limit
end