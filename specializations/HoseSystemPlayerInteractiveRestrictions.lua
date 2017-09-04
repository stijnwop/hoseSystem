--
-- Created by IntelliJ IDEA.
-- User: stijn
-- Date: 15-4-2017
-- Time: 16:00
-- To change this template use File | Settings | File Templates.
--

HoseSystemPlayerInteractiveRestrictions = {}

local HoseSystemPlayerInteractiveRestrictions_mt = Class(HoseSystemPlayerInteractiveRestrictions, HoseSystemPlayerInteractive)

function HoseSystemPlayerInteractiveRestrictions:new(object, mt)
    local playerInteractiveRestrictions = {
        object = object
    }

    setmetatable(playerInteractiveRestrictions, mt == nil and HoseSystemPlayerInteractiveRestrictions_mt or mt)

    playerInteractiveRestrictions.lastInRangePosition = { 0, 0, 0 }
    playerInteractiveRestrictions.rangeRestrictionMessageShown = false
    playerInteractiveRestrictions.currentChainCount = 0

    return playerInteractiveRestrictions
end

function HoseSystemPlayerInteractiveRestrictions:delete()
    HoseSystemPlayerInteractiveRestrictions:superClass().delete(self)
end

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
                    --                    self:restrictReferenceDistance(dt, grabPoint)
                end
            end
        end
    end
end

function HoseSystemPlayerInteractiveRestrictions:draw()
end

function HoseSystemPlayerInteractiveRestrictions:restrictPlayerDistance(dt, grabPoint)
    local player = grabPoint.currentOwner

    if player ~= nil then
        if player.positionIsDirty then
            if player.hoseSystem.interactiveHandling ~= nil then

                if grabPoint.id == player.hoseSystem.index then
                    if HoseSystem:getIsAttached(grabPoint.state) then
                        local dependentGrabpoint

                        --                        self:setChainCount(1) -- We're always 1 behind cause we are counting the jointIndexes!

                        for _, gp in pairs(self.object.grabPoints) do
                            --                            local _, count = self:getLastGrabpointRecursively(gp, self.currentChainCount)
                            --
                            --                            self:setChainCount(count)
                            -- print(count)

                            --self:calculateChainRecursively(gp)

                            if gp.id ~= grabPoint.id then
                                if HoseSystem:getIsConnected(gp.state) or HoseSystem:getIsAttached(gp.state) then
                                    dependentGrabpoint = gp
                                    break
                                end
                            end
                        end

                        if dependentGrabpoint ~= nil then
                            if dependentGrabpoint.connectorRefId ~= nil then
                                local reference = HoseSystemReferences:getReference(dependentGrabpoint.connectorVehicle, dependentGrabpoint.connectorRefId, dependentGrabpoint)

                                if reference == nil then
                                    return
                                end

                                local x, y, z = getWorldTranslation(reference.node)
                                local px, py, pz = getWorldTranslation(player.rootNode)
                                local dx, dz = px - x, pz - z
                                local radius = dx * dx + dz * dz
                                local length = self.object.data.length

                                --local inRange = false
                                -- local actionRadius = (self.hose.length * self.hose.length) * (self.currentChainCount - 1)

                                --                                local actionRadius = self.currentChainCount > 1 and (length * length) * 1.2 or length * length -- give it some space when moving a chain because well..
                                local actionRadius = length * length -- give it some space when moving a chain because well..

                                -- print(" New " .. actionRadius)
                                -- print("Radius " .. radius)

                                -- if radius < actionRadius then
                                -- inRange = true
                                -- end

                                if radius < actionRadius then
                                    self.lastInRangePosition = { getTranslation(player.rootNode) }
                                else
                                    -- local x, y, z = getWorldTranslation(player.rootNode)
                                    -- local gx, gy, gz = getWorldTranslation(dependentGrabpoint.node)
                                    -- local distance = Utils.vector3Length(x - gx, y - gy, z - gz)

                                    -- if distance > self.hose.length then
                                    local kx, _, kz = getWorldTranslation(reference.node)
                                    local px, py, pz = getWorldTranslation(player.rootNode)
                                    local distance = Utils.vector2Length(px - kx, pz - kz)
                                    local x, y, z = unpack(self.lastInRangePosition)

                                    x = kx + ((px - kx) / distance) * (length - 0.00001 * dt)
                                    -- x = kx + ((px - kx) / distance) * (self.hose.length * (self.currentChainCount - 1) - 0.00001 * dt)
                                    z = kz + ((pz - kz) / distance) * (length - 0.00001 * dt)
                                    -- z = kz + ((pz - kz) / distance) * (self.hose.length * (self.currentChainCount - 1) - 0.00001 * dt)

                                    player:moveToAbsoluteInternal(x, py, z)
                                    self.lastInRangePosition = { x, y, z }

                                    if not self.rangeRestrictionMessageShown and player == g_currentMission.player then
                                        self.rangeRestrictionMessageShown = true
                                        g_currentMission:showBlinkingWarning(g_i18n:getText('HOSE_RANGERESTRICTION'), 5000)
                                    end
                                    -- end
                                end
                            end
                        end
                    end
                end
            end
        end

        -- print(self.currentChainCount)

        if self.currentChainCount >= 4 then
            player.walkingIsLocked = true

            if not self.playerRestrictionChainToLongShown and player == g_currentMission.player then
                self.playerRestrictionChainToLongShown = true
                g_currentMission:showBlinkingWarning('You are not a super human!', 5000)
            end
        else
            player.walkingIsLocked = false

            if self.currentChainCount > 1 then
                player.walkingSpeed = self.walkingSpeed / ((self.hose.length / self.hose.length) * self.currentChainCount)
                player.runningFactor = self.runningFactor / ((self.hose.length / self.hose.length) * self.currentChainCount)
            end
        end
    end
end

function HoseSystemPlayerInteractiveRestrictions:restrictReferenceDistance(dt, grabPoint)
end