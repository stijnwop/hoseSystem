--
-- HoseSystemFillTriggerInteractive
--
-- Authors: Wopster
-- Description: Class to handle all interactions with fill triggers
--
-- Copyright (c) Wopster, 2017

HoseSystemFillTriggerInteractive = {}

local HoseSystemFillTriggerInteractive_mt = Class(HoseSystemFillTriggerInteractive)

---
-- @param object
-- @param mt
--
function HoseSystemFillTriggerInteractive:new(object, mt)
    local fillTriggerInteractive = {
        object = object
    }

    setmetatable(fillTriggerInteractive, mt == nil and HoseSystemFillTriggerInteractive_mt or mt)

    object.lastRaycastDistance = 0
    object.lastRaycastObject = nil

    return fillTriggerInteractive
end

---
--
function HoseSystemFillTriggerInteractive:delete()
end

---
-- @param dt
--
function HoseSystemFillTriggerInteractive:update(dt)
    if self.object.isServer then
        if self.object.grabPoints ~= nil then
            for _, gp in pairs(self.object.grabPoints) do
                if HoseSystem:getIsDetached(gp.state) then
                    local x, y, z = getWorldTranslation(gp.raycastNode)
                    local dx, dy, dz = localDirectionToWorld(gp.raycastNode, 0, 0, -1)

                    self.object.lastRaycastDistance = 0
                    self.object.lastRaycastObject = nil

                    raycastClosest(x, y, z, dx, dy, dz, 'fillableObjectRaycastCallback', 2, self)

                    if self.object.lastRaycastDistance ~= 0 then
                        local isUnderFillplane, planeY = self.object.lastRaycastObject:checkPlaneY(y)

                        if isUnderFillplane and HoseSystemFillTriggerInteractive:allowFillTypeAffectDirtMask(self.object.lastRaycastObject.fillType) then
                            -- Todo: make this direction based!
                            --                            local difference = HoseSystemUtil:mathRound(math.abs(planeY - y), 3)

                            if self.object:getDirtAmount() < 1 then
                                self.object:setDirtAmount(1)
                            end

                            -- Todo: Moved feature to version 1.1
                            --                            local param = gp.id > 1 and difference or -1 * difference
                            --
                            --                            for _, node in pairs(self.object.washableNodes) do
                            --                                local x, y, z, w = getShaderParameter(node, 'RDT')
                            --                                -- Round value to have better check on the param
                            --                                x = HoseSystemUtil:mathRound(x, 3)
                            --
                            --                                local update = false
                            --
                            --                                if gp.id > 1 then
                            --                                    update = x < param
                            --                                else
                            --                                    update = param < x
                            --                                end
                            --
                            --                                if update and math.abs(x - param) > 0.01 then
                            --                                    setShaderParameter(node, 'RDT', param, y, z, w, false)
                            --                                end
                            --                            end
                        end
                    end

                    if HoseSystem.debugRendering then
                        local xyz = { worldToLocal(gp.raycastNode, x, y, z) }
                        xyz[3] = xyz[3] - 2
                        xyz = { localToWorld(gp.raycastNode, xyz[1], xyz[2], xyz[3]) }
                        local color = { 1, 0 }

                        if self.object.lastRaycastDistance ~= 0 then
                            color = { 0, 1 }
                        end

                        drawDebugLine(x, y, z, color[1], color[2], 0, xyz[1], xyz[2], xyz[3], color[1], color[2], 0)
                    end
                end
            end
        end
    end
end

---
--
function HoseSystemFillTriggerInteractive:draw()
end

---
-- @param transformId
-- @param x
-- @param y
-- @param z
-- @param distance
--
function HoseSystemFillTriggerInteractive:fillableObjectRaycastCallback(transformId, x, y, z, distance)
    if transformId ~= 0 then
        if transformId == g_currentMission.terrainRootNode then
            return false
        end

        local object = g_currentMission:getNodeObject(transformId)

        if object ~= nil and object.checkNode ~= nil then
            if object:checkNode(transformId) then
                for fillType, _ in pairs(self.object.supportedFillTypes) do
                    if object:allowFillType(fillType) then
                        self.object.lastRaycastObject = object
                        self.object.lastRaycastDistance = distance

                        return false
                    end
                end
            end
        end
    end

    return true
end

---
-- @param fillType
--
function HoseSystemFillTriggerInteractive:allowFillTypeAffectDirtMask(fillType)
    return fillType == FillUtil.FILLTYPE_LIQUIDMANURE or fillType == FillUtil.FILLTYPE_DIGESTATE
end