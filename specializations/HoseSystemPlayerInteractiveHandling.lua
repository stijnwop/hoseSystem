--
-- Created by IntelliJ IDEA.
-- User: stijn
-- Date: 14-4-2017
-- Time: 13:29
-- To change this template use File | Settings | File Templates.
--

HoseSystemPlayerInteractiveHandling = {}
local HoseSystemPlayerInteractiveHandling_mt = Class(HoseSystemPlayerInteractiveHandling, HoseSystemPlayerInteractive);

function HoseSystemPlayerInteractiveHandling:new(object, mt)
    local handling = HoseSystemPlayerInteractive:new(object, mt == nil and HoseSystemPlayerInteractiveHandling_mt or mt);

    return handling
end

function HoseSystemPlayerInteractiveHandling:delete()
    HoseSystemPlayerInteractiveHandling:superClass().delete(self)
end

function HoseSystemPlayerInteractiveHandling:update(dt)
    HoseSystemPlayerInteractiveHandling:superClass().update(self, dt)

    if self.object.isClient then
        if g_currentMission.player.hoseSystem ~= nil and g_currentMission.player.hoseSystem.hose ~= nil then
            local index = g_currentMission.player.hoseSystem.index
            local grabPoint = self.object.grabPoints[index]

            if grabPoint ~= nil then
                if HoseSystem:getIsAttached(grabPoint.state) then
                    g_currentMission:addExtraPrintText(g_i18n:getText('input_mouseInteract'):format(string.lower(MouseHelper.getButtonName(Input.MOUSE_BUTTON_RIGHT))) .. ' ' .. g_i18n:getText('action_dropHose'))

                    if InputBinding.hasEvent(InputBinding.DETACH_HOSE) then
                        self:drop(index, g_currentMission.player)
                    end
                end
            end
        else
            local inRange, index = self:getIsPlayerInGrabPointRange()

            if inRange then
                local grabPoint = self.object.grabPoints[index]

                if grabPoint ~= nil then
                    if HoseSystem:getIsDetached(grabPoint.state) then
                        self:renderHelpTextOnNode(grabPoint.node, g_i18n:getText('action_grabHose'), g_i18n:getText('input_mouseInteract'):format(string.lower(MouseHelper.getButtonName(Input.MOUSE_BUTTON_LEFT))))

                        g_currentMission:enableHudIcon('attach', 1)

                        if InputBinding.hasEvent(InputBinding.ATTACH_HOSE) then
                            self:grab(index, g_currentMission.player)
                        end
                    end
                end
            end
        end
    end
end

function HoseSystemPlayerInteractiveHandling:draw()
end

function HoseSystemPlayerInteractive:grab(index, player, noEventSend)
    if self.object.grabPoints ~= nil then
--        HoseSystemGrabEvent.sendEvent(self, index, player, noEventSend)

        local grabPoint = self.object.grabPoints[index]

        if grabPoint == nil then
            return
        end

        if player ~= nil then
            grabPoint.state = HoseSystem.STATE_ATTACHED

            -- Todo: we call the function set owner
            -- But do not event it again since we already getting reloaded by the grab event
             self:setGrabPointOwner(index, true, player)

            -- Todo: update visuals like gloves etc..
            -- But do not event it again since we already getting reloaded by the grab event

            self.object.walkingSpeed = player.walkingSpeed
            self.object.runningFactor = player.runningFactor

            if self.object.isServer then
                -- Todo: calculate mass of hose components.. save it in self on game load.
                -- For now just set 4kg for every meter.
                player.hoseSystem.mass = (0.004 * self.object.data.length) * 100
                player.hoseSystem.kinematicHelper = {
                    node = clone(player.pickUpKinematicHelper.node, true, false, true)
                }

                link(player.toolsRootNode, player.hoseSystem.kinematicHelper.node)
                setTranslation(player.hoseSystem.kinematicHelper.node, -0.4, -0.1, 0.3) -- fixed location

                -- Set kinematicHelper node dependent on player rotation
                local yRot = math.abs(Utils.getYRotationBetweenNodes(grabPoint.node, player.toolsRootNode))
                yRot = yRot >= 1.5 and (index > 1 and math.rad(0) or math.rad(180)) or (index > 1 and math.rad(180) or math.rad(0))

                setRotation(player.hoseSystem.kinematicHelper.node, 0, yRot, 0)

                -- Todo: check if we still have to set the joint orientation?
                HoseSystemPlayerInteractive:constructPlayerJoint({
                    actor1 = player.hoseSystem.kinematicHelper.node,
                    actor2 = self.object.components[grabPoint.componentIndex].node,
                    anchor1 = player.hoseSystem.kinematicHelper.node,
                    anchor2 = grabPoint.node
                }, player.hoseSystem)

                -- Set collision mask on hose components to disable collision with CCT
                if grabPoint.componentIndex ~= nil then
                    setCollisionMask(self.object.components[grabPoint.componentIndex].node, HoseSystem.cctCollisionMask)
                end

                --                for i, component in pairs(self.components) do
                --                    if i ~= grabPoint.componentIndex then
                --                        setPairCollision(player.pickUpKinematicHelper.node, component.node, false)
                --                    end
                --                end

            end
        end
    end
end

function HoseSystemPlayerInteractive:drop(index, player, noEventSend)
    if self.object.grabPoints ~= nil then
        local grabPoint = self.object.grabPoints[index]

        if grabPoint == nil then
            return
        end

        local player = grabPoint.currentOwner

        if player ~= nil then
            grabPoint.state = HoseSystem.STATE_DETACHED

            self:setGrabPointOwner(index, false)

            player.walkingSpeed = self.object.walkingSpeed
            player.runningFactor = self.object.runningFactor

            if self.isServer then
                if player.hoseSystem ~= nil then
                    setTranslation(grabPoint.node, unpack(grabPoint.nodeOrgTrans))
                    setRotation(grabPoint.node, unpack(grabPoint.nodeOrgRot))

                    -- Player
                    if player.hoseSystem.kinematicHelper.node ~= nil then
                        unlink(player.hoseSystem.kinematicHelper.node)
                        delete(player.hoseSystem.kinematicHelper.node)
                    end

                    if player.hoseSystem.jointIndex ~= 0 then
                        removeJoint(player.hoseSystem.jointIndex)
                    end

                    player.hoseSystem.jointIndex = 0
                    player.hoseSystem.kinematicHelper.node = nil

                    -- Todo: fix this cause we only have to set 1
                    for i, component in pairs(self.object.components) do
                        -- transformId, decimal mask
                        if i == grabPoint.componentIndex then -- or 2
                            setCollisionMask(component.node, HoseSytem.hoseCollisionMask)
                        end
                    end
                end
            end
        end
    end
end

function HoseSystemPlayerInteractive:setGrabPointOwner(index, isOwned, player)
    local grabPoint = self.object.grabPoints[index]

    grabPoint.isOwned = isOwned
    grabPoint.currentOwner = (isOwned and player ~= nil) and player or nil

    player.hoseSystem = {
        hose = isOwned and self.object or nil,
        index = isOwned and index or nil
    }
end

---
-- @param jointDesc
-- @param playerHoseDesc
--
function HoseSystemPlayerInteractive:constructPlayerJoint(jointDesc, playerHoseDesc)
    local constructor = JointConstructor:new()

    constructor:setActors(jointDesc.actor1, jointDesc.actor2)
    constructor:setJointTransforms(jointDesc.anchor1, jointDesc.anchor2)
    constructor:setEnableCollision(false)

    local rotLimitSpring = {}
    local rotLimitDamping = {}
    local transLimitSpring = {}
    local translimitDamping = {}
    local springMass = playerHoseDesc.mass * 60

    for i = 1, 3 do
        rotLimitSpring[i] = springMass
        rotLimitDamping[i] = math.sqrt(playerHoseDesc.mass * rotLimitSpring[i]) * 2
        transLimitSpring[i] = springMass
        translimitDamping[i] = math.sqrt(playerHoseDesc.mass * transLimitSpring[i]) * 2
    end

    constructor:setRotationLimitSpring(rotLimitSpring[1], rotLimitDamping[1], rotLimitSpring[2], rotLimitDamping[2], rotLimitSpring[3], rotLimitDamping[3])
    constructor:setTranslationLimitSpring(transLimitSpring[1], translimitDamping[1], transLimitSpring[2], translimitDamping[1], transLimitSpring[3], translimitDamping[3])

    for i = 0, 2 do
        constructor:setRotationLimit(i, 0, 0)
        constructor:setTranslationLimit(i, true, 0, 0)
    end

    local forceLimit = playerHoseDesc.mass * 25 -- only when stucked behind object
    constructor:setBreakable(forceLimit, forceLimit)

    playerHoseDesc.jointIndex = constructor:finalize()

    addJointBreakReport(playerHoseDesc.jointIndex, 'onGrabJointBreak', self)
end

---
-- @param jointIndex
-- @param breakingImpulse
--
function HoseSystemPlayerInteractive:onGrabJointBreak(jointIndex, breakingImpulse)
    --if self.isServer then
    -- Todo: fix this
--    if jointIndex == g_currentMission.player.hose.jointIndex then
--        g_currentMission.player.activeTool:drop(g_currentMission.player.activeToolLocationId, g_currentMission.player)
--    end
    --end

    return false
end
