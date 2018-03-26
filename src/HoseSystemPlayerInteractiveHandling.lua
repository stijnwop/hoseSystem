--
-- HoseSystemPlayerInteractiveHandling
--
-- Authors: Wopster
-- Description: Class to handle all the attach and detach interaction with the hose to player and vehicles
--
-- Copyright (c) Wopster, 2017

HoseSystemPlayerInteractiveHandling = {}

HoseSystemPlayerInteractiveHandling.KINEMATIC_HELPER_TRANS_OFFSET = { -0.4, -0.1, 0.35 }
HoseSystemPlayerInteractiveHandling.JOINT_XZ_ROT_LIMIT = 8 -- deg
HoseSystemPlayerInteractiveHandling.BLINKING_WARNING_TIME = 5000 -- ms

local HoseSystemPlayerInteractiveHandling_mt = Class(HoseSystemPlayerInteractiveHandling, HoseSystemPlayerInteractive)

---
-- @param object
-- @param mt
--
function HoseSystemPlayerInteractiveHandling:new(object, mt)
    local interactiveHandling = HoseSystemPlayerInteractive:new(object, mt == nil and HoseSystemPlayerInteractiveHandling_mt or mt)

    return interactiveHandling
end

---
--
function HoseSystemPlayerInteractiveHandling:delete()
    HoseSystemPlayerInteractiveHandling:superClass().delete(self)
end

---
-- @param dt
--
function HoseSystemPlayerInteractiveHandling:update(dt)
    HoseSystemPlayerInteractiveHandling:superClass().update(self, dt)

    -- only client sided
    if not self.object.isClient then
        return
    end

    if g_currentMission.player ~= nil and g_currentMission.player.hoseSystem ~= nil and g_currentMission.player.hoseSystem.interactiveHandling ~= nil then
        local index = g_currentMission.player.hoseSystem.index
        local grabPoint = self.object.grabPoints[index]

        if grabPoint ~= nil then
            if HoseSystem:getIsAttached(grabPoint.state) and grabPoint.isOwned then
                g_currentMission:addExtraPrintText(g_i18n:getText('input_mouseInteract'):format(g_i18n:getText('input_mouseInteractMouseRight')) .. ' ' .. g_i18n:getText('action_dropHose'):format(self.object.typeDesc))

                if InputBinding.hasEvent(InputBinding.detachHose) then
                    self:drop(index, grabPoint.currentOwner)
                end

                if HoseSystemReferences:getHasReferenceInRange(self.object) then
                    local object = networkGetObject(self.object.vehicleToMountHoseSystem)

                    if object ~= nil then
                        local reference = HoseSystemReferences:getReference(object, self.object.referenceIdToMountHoseSystem, grabPoint)

                        local node = reference ~= nil and reference.node or grabPoint.node

                        HoseSystemUtil:renderHelpTextOnNode(node, g_i18n:getText('action_attachHose'):format(self.object.typeDesc), g_i18n:getText('input_mouseInteract'):format(g_i18n:getText('input_mouseInteractMouseLeft')))

                        g_currentMission:enableHudIcon('attach', 1)

                        if InputBinding.hasEvent(InputBinding.attachHose) then
                            self:attach(index, object, self.object.referenceIdToMountHoseSystem, self.object.referenceIsExtendable)
                        end
                    end
                end
            end
        end
    else
        --        local index = self:getIsPlayerInGrabPointRange()

        if g_currentMission.player ~= nil and g_currentMission.player.hoseSystem ~= nil and g_currentMission.player.hoseSystem.closestIndex ~= nil and g_currentMission.player.hoseSystem.closestHoseSystem == self.object then
            local index = g_currentMission.player.hoseSystem.closestIndex
            local grabPoint = self.object.grabPoints[index]

            if grabPoint ~= nil then
                if HoseSystem:getIsDetached(grabPoint.state) then
                    HoseSystemUtil:renderHelpTextOnNode(grabPoint.node, g_i18n:getText('action_grabHose'):format(self.object.typeDesc), g_i18n:getText('input_mouseInteract'):format(g_i18n:getText('input_mouseInteractMouseLeft')))

                    g_currentMission:enableHudIcon('attach', 1)

                    if InputBinding.hasEvent(InputBinding.attachHose) then
                        self:grab(index, g_currentMission.player)
                    end
                elseif HoseSystem:getIsConnected(grabPoint.state) or HoseSystem:getIsParked(grabPoint.state) then
                    --
                    if HoseSystemReferences:getAllowsDetach(self.object, index) then
                        if grabPoint.hasJointIndex then
                            HoseSystemUtil:renderHelpTextOnNode(grabPoint.node, g_i18n:getText('action_detachHose'):format(self.object.typeDesc), g_i18n:getText('input_mouseInteract'):format(g_i18n:getText('input_mouseInteractMouseRight')))

                            if InputBinding.hasEvent(InputBinding.detachHose) then
                                local vehicle = grabPoint.connectorVehicle
                                local reference = HoseSystemReferences:getReference(vehicle, grabPoint.connectorRefId, grabPoint)

                                if reference ~= nil then
                                    local extenable = not reference.parkable and ((reference.connectable ~= nil and reference.connectable) or (grabPoint.connectable ~= nil and grabPoint.connectable))

                                    if reference.hasJointIndex then
                                        vehicle.poly.interactiveHandling:detach(reference.id, self.object, index, extenable)
                                    else
                                        self:detach(index, vehicle, reference.id, extenable)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

---
--
function HoseSystemPlayerInteractiveHandling:draw()
end

---
-- @param index
-- @param player
-- @param syncState
-- @param noEventSend
--
function HoseSystemPlayerInteractiveHandling:grab(index, player, syncState, noEventSend)
    if self.object.grabPoints ~= nil then
        if not noEventSend and syncState == nil then
            HoseSystemGrabEvent.sendEvent(self.object, index, player, HoseSystemUtil.eventHelper.STATE_CLIENT, noEventSend)
        end

        local grabPoint = self.object.grabPoints[index]

        if grabPoint == nil or player == nil then
            return
        end

        grabPoint.state = HoseSystem.STATE_ATTACHED

        if self.object.isServer then
            -- But do not event it again since we already getting reloaded by the grab event
            self:setGrabPointOwner(index, true, player)
        end

        if syncState == nil then
            player:setWoodWorkVisibility(true, false)

            self.object.walkingSpeed = player.walkingSpeed
            self.object.runningFactor = player.runningFactor

            if self.object.isServer then
                self:grab(index, player, HoseSystemUtil.eventHelper.STATE_SERVER, noEventSend)
            else
                HoseSystemGrabEvent.sendEvent(self.object, index, player, HoseSystemUtil.eventHelper.STATE_SERVER, self.object.isServer)
            end
        elseif syncState == HoseSystemUtil.eventHelper.STATE_CLIENT then
            if player ~= g_currentMission.player then
                player:setWoodWorkVisibility(true, false)
            end
        elseif syncState == HoseSystemUtil.eventHelper.STATE_SERVER then
            if self.object.isServer then
                player.hoseSystem.mass = self.object.data.generatedMass
                player.hoseSystem.kinematicHelper = {
                    node = clone(player.pickUpKinematicHelper.node, true, false, true)
                }

                link(player.toolsRootNode, player.hoseSystem.kinematicHelper.node)
                setTranslation(player.hoseSystem.kinematicHelper.node, unpack(HoseSystemPlayerInteractiveHandling.KINEMATIC_HELPER_TRANS_OFFSET)) -- fixed location

                -- Set kinematicHelper node dependent on player rotation
                local angle = HoseSystemUtil:calculateCosAngle(grabPoint.node, player.toolsRootNode, 3)
                local y = angle > 0 and math.rad(0) or math.rad(180)

                setRotation(player.hoseSystem.kinematicHelper.node, 0, y, 0)

                player.hoseSystem.jointIndex = HoseSystemPlayerInteractiveHandling:constructPlayerJoint({
                    actor1 = player.hoseSystem.kinematicHelper.node,
                    actor2 = self.object.components[grabPoint.componentIndex].node,
                    anchor1 = player.hoseSystem.kinematicHelper.node,
                    anchor2 = grabPoint.node
                }, player.hoseSystem)

                for i, component in pairs(self.object.components) do
                    if i ~= grabPoint.componentIndex then
                        setPairCollision(component.node, player.hoseSystem.kinematicHelper.node, false)
                    end
                end

                -- When there is a connected grabPoint we set the limit of the joint so we can move freely without pushing the connector vehicle
                for index, gp in pairs(self.object.grabPoints) do
                    if index ~= grabPoint.id and HoseSystem:getIsConnected(gp.state) then
                        self:setJointRotAndTransLimit(gp.playerJointRotLimit, gp.playerJointTransLimit)
                    end
                end
            end

            -- Set collision mask on hose components to disable collision with CCT
            -- Since we cannot set non collidable objects for the CCT we just set the collision mask of the object
            if grabPoint.componentIndex ~= nil then
                setCollisionMask(self.object.components[grabPoint.componentIndex].node, HoseSystem.CCT_COLLISION_MASK)
                setCollisionMask(self.object.components[(#self.object.components + 1) / 2].node, HoseSystem.CCT_COLLISION_MASK)
            end
        end
    end
end

---
-- @param index
-- @param player
-- @param syncState
-- @param noEventSend
--
function HoseSystemPlayerInteractiveHandling:drop(index, player, syncState, noEventSend)
    if self.object.grabPoints ~= nil then
        if not noEventSend and syncState == nil then
            HoseSystemDropEvent.sendEvent(self.object, index, player, HoseSystemUtil.eventHelper.STATE_CLIENT, noEventSend)
        end

        --        if noEventSend == nil or noEventSend == false then
        --            if g_server ~= nil then
        --                g_server:broadcastEvent(HoseSystemDropEvent:new(self.object, index, connectionEventState, player), nil, nil, self.object)
        --            else
        --                -- Send drop request to server and return
        --                g_client:getServerConnection():sendEvent(HoseSystemDropEvent:new(self.object, index, connectionEventState, player))
        --
        --                return
        --            end
        --        end

        --        HoseSystemDropEvent.sendEvent(self.object, index, player, HoseSystemUtil.eventHelper.STATE_CLIENT, noEventSend)

        local grabPoint = self.object.grabPoints[index]

        if grabPoint == nil or player == nil then
            return
        end

        grabPoint.state = HoseSystem.STATE_DETACHED

        if self.object.isServer then
            self:setGrabPointOwner(index, false, player)
        end

        if syncState == nil then
            player:setWoodWorkVisibility(false, false)
            player.walkingSpeed = self.object.walkingSpeed
            player.runningFactor = self.object.runningFactor

            if self.object.isServer then
                self:drop(index, player, HoseSystemUtil.eventHelper.STATE_SERVER, noEventSend)
            else
                HoseSystemDropEvent.sendEvent(self.object, index, player, HoseSystemUtil.eventHelper.STATE_SERVER, self.object.isServer)
            end
        elseif syncState == HoseSystemUtil.eventHelper.STATE_CLIENT then
            if player ~= g_currentMission.player then
                player:setWoodWorkVisibility(false, false)
            end
        elseif syncState == HoseSystemUtil.eventHelper.STATE_SERVER then
            if self.object.isServer then
                if player.hoseSystem ~= nil then
                    if player.hoseSystem.jointIndex ~= 0 then
                        removeJoint(player.hoseSystem.jointIndex)
                    end

                    setTranslation(grabPoint.node, unpack(grabPoint.nodeOrgTrans))
                    setRotation(grabPoint.node, unpack(grabPoint.nodeOrgRot))

                    -- Player
                    if player.hoseSystem.kinematicHelper.node ~= nil then
                        unlink(player.hoseSystem.kinematicHelper.node)
                        delete(player.hoseSystem.kinematicHelper.node)
                    end

                    player.hoseSystem.jointIndex = 0
                    player.hoseSystem.kinematicHelper.node = nil

                    -- set the joint limits back to the state that it only rotates on the connector
                    for index, gp in pairs(self.object.grabPoints) do
                        if index ~= grabPoint.id and HoseSystem:getIsConnected(gp.state) then
                            self:setJointRotAndTransLimit({ HoseSystemPlayerInteractiveHandling.JOINT_XZ_ROT_LIMIT, HoseSystemPlayerInteractiveHandling.JOINT_XZ_ROT_LIMIT, 0 }, { 0, 0, 0 })
                        end
                    end
                end
            end

            if grabPoint.componentIndex ~= nil then
                setCollisionMask(self.object.components[grabPoint.componentIndex].node, HoseSystem.HOSESYSTEM_COLLISION_MASK)
                setCollisionMask(self.object.components[(#self.object.components + 1) / 2].node, HoseSystem.HOSESYSTEM_COLLISION_MASK)
            end
        end
    end
end

---
-- @param index
-- @param vehicle
-- @param referenceId
-- @param isExtendable
-- @param noEventSend
--
function HoseSystemPlayerInteractiveHandling:attach(index, vehicle, referenceId, isExtendable, noEventSend)
    if self.object.grabPoints ~= nil then
        HoseSystemAttachEvent.sendEvent(self.object, index, vehicle, referenceId, isExtendable, noEventSend)

        local grabPoint = self.object.grabPoints[index]

        if grabPoint == nil or vehicle == nil then
            return
        end

        local object = HoseSystemReferences:getReferenceVehicle(vehicle)
        local reference = HoseSystemReferences:getReference(vehicle, referenceId, grabPoint)

        if reference ~= nil then
            local grabPoints = { grabPoint }

            if self.object.isServer then
                local attachedGrabPoint = HoseSystemUtil:getAttachedGrabPoint(self.object.grabPoints, index)
                -- get the other grabPoint if it's attached and drop it
                if attachedGrabPoint ~= nil and attachedGrabPoint.isOwned then
                    self:drop(attachedGrabPoint.id, attachedGrabPoint.currentOwner)
                end
            end

            if reference.parkable then
                -- handle parked hose
                if self.object.data.length <= reference.parkLength then
                    table.insert(grabPoints, index > 1 and self.object.grabPoints[1] or self.object.grabPoints[#self.object.grabPoints])

                    if self.object.isServer then
                        local lastIndex = #grabPoints

                        if HoseSystem:getIsConnected(grabPoints[lastIndex].state) then
                            local lastReference = HoseSystemReferences:getReference(grabPoints[lastIndex].connectorVehicle, grabPoints[lastIndex].connectorRefId, grabPoints[lastIndex])
                            if lastReference ~= nil then
                                self:detach(grabPoints[lastIndex].id, grabPoints[lastIndex].connectorVehicle, grabPoints[lastIndex].connectorRefId, (lastReference.connectable ~= nil and lastReference.connectable) or (grabPoints[lastIndex].connectable ~= nil and grabPoints[lastIndex].connectable), true)
                            end
                        end

                        if HoseSystem:getIsAttached(grabPoint.state) and grabPoint.isOwned then -- we can't call it on start since we don't want to drop when the parking place is to small.
                            -- Do this after above else it will fuckup the data..
                            self:drop(index, grabPoint.currentOwner)
                        end
                    end

                    self:hardParkHose(grabPoints, object, reference)
                else
                    if g_currentMission.player == grabPoint.currentOwner then
                        g_currentMission:showBlinkingWarning(string.format(g_i18n:getText('info_hoseParkingPlaceToShort'), reference.parkLength, self.object.data.length), HoseSystemPlayerInteractiveHandling.BLINKING_WARNING_TIME)
                    end

                    return
                end
            else
                -- handle connected hose
                if self.object.isServer then
                    if HoseSystem:getIsAttached(grabPoint.state) and grabPoint.isOwned then -- we can't call it on start since we don't want to drop when the parking place is to small.
                        self:drop(index, grabPoint.currentOwner)
                    end
                end

                if (isExtendable or grabPoint.connectable) then
                    -- Set 2 way recognition
                    reference.connectorRefId = grabPoint.id -- current grabPoint
                    reference.connectorVehicle = self.object

                    if grabPoint.connectable then
                        self.object:toggleLock(index, true) -- close lock
                    else
                        object:toggleLock(reference.id, true) -- close lock
                    end
                end

                self:hardConnect(grabPoint, object, reference)
            end

            for _, grabPoint in pairs(grabPoints) do
                grabPoint.connectorRefId = referenceId
                grabPoint.connectorVehicle = vehicle

                if self.object.isServer then
                    self:setGrabPointIsUsed(grabPoint.id, true, isExtendable, false)
                end
            end

            object:onConnectorAttach(referenceId, self.object)

            -- force the mesh updates again
            if self.object.isClient then
                self.object:updateSpline(true)
                self.object.jointSpline.firstRunUpdates = 0
            end
        end
    end
end

---
-- @param index
-- @param vehicle
-- @param referenceId
-- @param isExtendable
-- @param noEventSend
--
function HoseSystemPlayerInteractiveHandling:detach(index, vehicle, referenceId, isExtendable, noEventSend)
    if self.object.grabPoints ~= nil then
        HoseSystemDetachEvent.sendEvent(self.object, index, vehicle, referenceId, isExtendable, noEventSend)

        local grabPoint = self.object.grabPoints[index]

        if grabPoint == nil or vehicle == nil then
            return
        end

        local object = HoseSystemReferences:getReferenceVehicle(vehicle)
        local reference = HoseSystemReferences:getReference(vehicle, referenceId, grabPoint)

        if reference ~= nil then
            local grabPoints = { grabPoint }

            if self.object.isServer then
                local attachedGrabPoint = HoseSystemUtil:getAttachedGrabPoint(self.object.grabPoints, index)
                -- get the other grabPoint if it's attached and drop it
                if attachedGrabPoint ~= nil and attachedGrabPoint.isOwned then
                    self:drop(attachedGrabPoint.id, attachedGrabPoint.currentOwner)
                end
            end

            if reference.parkable then
                -- handle parked hose
                table.insert(grabPoints, index > 1 and self.object.grabPoints[1] or self.object.grabPoints[#self.object.grabPoints])

                self:hardUnparkHose(grabPoints, object, reference)
            else
                -- handle connected hose
                if grabPoint.connectable then
                    self.object:toggleLock(index, false) -- open lock
                end

                if reference.connectable then
                    object:toggleLock(reference.id, false) -- open lock
                end

                self:hardDisconnect(grabPoint, object, reference)
            end

            for _, grabPoint in pairs(grabPoints) do
                if self.object.isServer then
                    setTranslation(grabPoint.node, unpack(grabPoint.nodeOrgTrans))
                    setRotation(grabPoint.node, unpack(grabPoint.nodeOrgRot))

                    self:setGrabPointIsUsed(grabPoint.id, false, isExtendable, false)
                end

                grabPoint.connectorRefId = 0
                grabPoint.connectorVehicle = nil
            end

            object:onConnectorDetach(referenceId)
        end
    end
end

---
-- @param index
-- @param state
-- @param player
-- @param noEventSend
--
function HoseSystemPlayerInteractiveHandling:setGrabPointOwner(index, state, player, noEventSend)
    HoseSystemSetOwnerEvent.sendEvent(self.object, index, state, player, noEventSend)

    local grabPoint = self.object.grabPoints[index]

    grabPoint.isOwned = state
    grabPoint.currentOwner = (state and player ~= nil) and player or nil

    if player == nil then
        return
    end

    if player.hoseSystem == nil then
        player.hoseSystem = {}
    end

    player.hoseSystem.interactiveHandling = state and self or nil
    player.hoseSystem.index = state and index or nil
end

---
-- @param index
-- @param isConnected
-- @param isExtendable
-- @param isCalledFromReference
-- @param noEventSend
--
function HoseSystemPlayerInteractiveHandling:setGrabPointIsUsed(index, isConnected, isExtendable, isCalledFromReference, noEventSend)
    if isCalledFromReference == nil then
        isCalledFromReference = false
    end

    -- Todo: i want to get rid of this crap.

    -- event
    HoseSystemIsUsedEvent.sendEvent(self.object, index, isConnected, isExtendable, isCalledFromReference, noEventSend)

    local grabPoint = self.object.grabPoints[index]

    if grabPoint ~= nil then
        --        local vehicle = HoseSystemReferences:getReferenceVehicle(grabPoint.connectorVehicle)

        grabPoint.state = isConnected and HoseSystem.STATE_CONNECTED or HoseSystem.STATE_DETACHED
        grabPoint.hasJointIndex = not isCalledFromReference and isConnected -- tell clients on which grabPoint to call the detach function on

        --        if vehicle ~= nil and not isCalledFromReference then
        --            local reference = HoseSystemReferences:getReference(grabPoint.connectorVehicle, grabPoint.connectorRefId, grabPoint)

        -- we have to call on depending objects to tell that we are connecting
        --            if self.object.isServer then
        -- call reference functions
        --                if reference.connectable or isExtendable then
        --                    vehicle.poly.interactiveHandling:setGrabPointIsUsed(reference.id, isConnected, grabPoint.connectable, true)
        --                else
        --                    vehicle:setIsUsed(reference.id, isConnected, isConnected and self.object or nil)
        --                end
        --            end
        --        end
    end
end

---
-- @param jointDesc
-- @param playerHoseDesc
--
function HoseSystemPlayerInteractiveHandling:constructPlayerJoint(jointDesc, playerHoseDesc)
    local constructor = JointConstructor:new()

    constructor:setActors(jointDesc.actor1, jointDesc.actor2)
    constructor:setJointTransforms(jointDesc.anchor1, jointDesc.actor2)

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

    for axis = 0, 2 do
        constructor:setRotationLimit(axis, 0, 0)
        constructor:setTranslationLimit(axis, true, 0, 0)
    end

    if not g_hoseSystem.debugRendering then
        local forceLimit = playerHoseDesc.mass * 25 -- only when stucked behind object
        constructor:setBreakable(forceLimit, forceLimit)
    end

    local jointIndex = constructor:finalize()

    if not g_hoseSystem.debugRendering then
        addJointBreakReport(jointIndex, "onGrabJointBreak", self)
    end

    return jointIndex
end

---
-- @param jointDesc
--
function HoseSystemPlayerInteractiveHandling:constructReferenceJoints(jointDesc)
    local constructor = JointConstructor:new()

    local springForce = 7500
    local springDamping = 1500
    local x, y, z = getWorldTranslation(jointDesc.anchor1)

    constructor:setActors(jointDesc.actor1, jointDesc.actor2)
    constructor:setJointTransforms(jointDesc.anchor1, jointDesc.anchor2)
    constructor:setJointWorldPositions(x, y, z, x, y, z)
    constructor:setEnableCollision(false)
    constructor:setRotationLimitSpring(springForce, springDamping, springForce, springDamping, springForce, springDamping)
    constructor:setTranslationLimitSpring(springForce, springDamping, springForce, springDamping, springForce, springDamping)

    for axis = 1, 3 do
        constructor:setRotationLimit(axis - 1, -jointDesc.rotLimit[axis], jointDesc.rotLimit[axis])
        constructor:setTranslationLimit(axis - 1, true, -jointDesc.transLimit[axis], jointDesc.transLimit[axis])
    end

    return constructor:finalize()
end

---
-- @param rotLimit
-- @param transLimit
--
function HoseSystemPlayerInteractiveHandling:setJointRotAndTransLimit(rotLimit, transLimit)
    if not self.object.isServer then
        return
    end

    for i, jointDesc in pairs(self.object.componentJoints) do
        if jointDesc.hoseJointIndex ~= nil then
            for axis = 1, 3 do
                setJointRotationLimit(jointDesc.hoseJointIndex, axis - 1, true, -rotLimit[axis], rotLimit[axis])
                setJointTranslationLimit(jointDesc.hoseJointIndex, axis - 1, true, -transLimit[axis], transLimit[axis])
            end
        end
    end
end

---
-- @param jointIndex
-- @param breakingImpulse
--
function HoseSystemPlayerInteractiveHandling:onGrabJointBreak(jointIndex, breakingImpulse)
    if jointIndex == g_currentMission.player.hoseSystem.jointIndex then
        g_currentMission.player.hoseSystem.interactiveHandling:drop(g_currentMission.player.hoseSystem.index, g_currentMission.player)
    end

    return false
end

---
-- @param grabPoint
-- @param vehicle
-- @param reference
--
function HoseSystemPlayerInteractiveHandling:hardConnect(grabPoint, vehicle, reference)
    -- Note: cause we delete the connector vehicle from physics we have to attach it back later on
    local grabPoints = {}
    -- Get all the hoses that are connected to a references from the Vehicle
    local connectedReferences = HoseSystemUtil:getReferencesWithSingleConnection(vehicle, reference.id)
    local connectedHoseSystems = HoseSystemUtil:getConnectedHoseSystems(vehicle)

    --    print('connected hoses = ' .. #connectedHoseSystems)
    --    print('connected references = ' .. #connectedReferences)

    for index, gp in pairs(self.object.grabPoints) do
        if gp.id ~= grabPoint.id and HoseSystem:getIsConnected(gp.state) then
            table.insert(grabPoints, gp)
        end
    end

    --    print('connected grabPoints = ' .. #grabPoints)

    for i, r in pairs(connectedReferences) do
        HoseSystemUtil:removeHoseSystemJoint(r.reference)
    end

    -- we always completely delete the current handled hose
    self.object:removeFromPhysics()

    if not reference.isObject then
        HoseSystemUtil:removeFromPhysicsRecursively(vehicle)
    else
        removeFromPhysics(vehicle.nodeId)
    end

    for i, h in pairs(connectedHoseSystems) do
        --        h.hoseSystem:removeFromPhysics()
        h.hoseSystem.poly.interactiveHandling:hardDisconnect(h.grabPoint, h.vehicle, h.vehicle.grabPoints[h.grabPoint.connectorRefId])
    end

    setIsCompoundChild(self.object.components[grabPoint.componentIndex].node, true)

    local linkComponent = function(vehicle, grabPoint, reference)
        local moveDir = grabPoint.id > 1 and -1 or 1
        moveDir = (grabPoint.connectable or reference.connectable) and (moveDir > 0 and (reference.id > 1 and 1 or -1) or -1) or moveDir
        local direction = { localDirectionToLocal(vehicle.components[grabPoint.componentIndex].node, grabPoint.node, 0, 0, moveDir) }
        local upVector = { localDirectionToLocal(vehicle.components[grabPoint.componentIndex].node, grabPoint.node, 0, grabPoint.id > 1 and -1 or 1, 0) }

        setDirection(vehicle.components[grabPoint.componentIndex].node, direction[1], direction[2], direction[3], upVector[1], upVector[2], upVector[3])

        -- Todo: make offset value dynamic
        local translation = { localToLocal(vehicle.components[grabPoint.componentIndex].node, grabPoint.node, 0, 0, (grabPoint.connectable or reference.connectable) and -0.025 or 0) }
        setTranslation(vehicle.components[grabPoint.componentIndex].node, unpack(translation))

        link(reference.node, vehicle.components[grabPoint.componentIndex].node)
    end

    linkComponent(self.object, grabPoint, reference)

    for i, r in pairs(connectedReferences) do
        HoseSystemUtil:createHoseSystemJoint(r.reference)
    end

    -- Only add the hose to physics partly when not dealing with an extenable hose
    if not grabPoint.connectable and not reference.connectable then
        self:addToPhysicsParts(grabPoint, grabPoints, vehicle, reference, true)
    else
        self.object:addToPhysics()
    end

    -- Add the vehicles back to physics but sync wheels after the joint creation.
    if not reference.isObject then
        HoseSystemUtil:addToPhysicsRecursively(vehicle)
    else
        addToPhysics(vehicle.nodeId)
    end

    for i, h in pairs(connectedHoseSystems) do
        h.hoseSystem.poly.interactiveHandling:hardConnect(h.grabPoint, h.vehicle, h.vehicle.grabPoints[h.grabPoint.connectorRefId])
    end

    if self.object.isServer then
        self.object:raiseDirtyFlags(self.object.vehicleDirtyFlag) -- set bit.. we update the server
        self.object.forceCompontentUpdate = true

        if not reference.isObject then
            vehicle:raiseDirtyFlags(vehicle.vehicleDirtyFlag)
        end
    end
end

---
-- @param grabPoint
-- @param vehicle
-- @param reference
--
function HoseSystemPlayerInteractiveHandling:hardDisconnect(grabPoint, vehicle, reference)
    local grabPoints = {}
    -- Get all the hoses that are connected to a references from the Vehicle
    local connectedReferences = HoseSystemUtil:getReferencesWithSingleConnection(vehicle, reference.id)

    for index, gp in pairs(self.object.grabPoints) do
        if gp.id ~= grabPoint.id and HoseSystem:getIsConnected(gp.state) then
            table.insert(grabPoints, gp)
        end
    end

    self:deleteCustomComponentJoint()

    if self.object.isServer then
        local removeJoint = function(grabPoint)
            if grabPoint.jointIndex ~= nil then
                removeJoint(grabPoint.jointIndex)
                grabPoint.jointIndex = nil
            end
        end

        removeJoint(grabPoint)
    end

    for i, r in pairs(connectedReferences) do
        HoseSystemUtil:removeHoseSystemJoint(r.reference)
    end

    self.object:removeFromPhysics()

    if not reference.isObject then
        HoseSystemUtil:removeFromPhysicsRecursively(vehicle)
    else
        removeFromPhysics(vehicle.nodeId)
    end

    setIsCompound(self.object.components[grabPoint.componentIndex].node, true)

    -- setIsCompoundChild(self.components[grabPoint.componentIndex].node, true)

    -- local translation = {getWorldTranslation(self.components[grabPoint.componentIndex].node)}
    -- setTranslation(self.components[grabPoint.componentIndex].node, unpack(translation))

    -- local moveDir = grabPoint.id > 1 and -1 or 1
    -- moveDir = (grabPoint.connectable or reference.connectable) and (moveDir > 0 and (reference.id > 1 and 1 or -1) or -1) or moveDir
    -- local direction = {localDirectionToWorld(grabPoint.node, 0, 0, 1)}
    -- local upVector = {localDirectionToWorld(grabPoint.node, 0, 1, 0)}

    -- setDirection(self.components[grabPoint.componentIndex].node, direction[1], direction[2], direction[3], upVector[1], upVector[2], upVector[3])

    -- link(getRootNode(), self.components[grabPoint.componentIndex].node)

    local translation = { getWorldTranslation(self.object.components[grabPoint.componentIndex].node) }
    setTranslation(self.object.components[grabPoint.componentIndex].node, unpack(translation))

    local direction = { localDirectionToWorld(self.object.rootNode, 0, 0, 1) }
    local upVector = { localDirectionToWorld(self.object.rootNode, 0, 1, 0) }

    setDirection(self.object.components[grabPoint.componentIndex].node, direction[1], direction[2], direction[3], upVector[1], upVector[2], upVector[3])
    link(getRootNode(), self.object.components[grabPoint.componentIndex].node)

    if not reference.isObject then
        HoseSystemUtil:addToPhysicsRecursively(vehicle)
    else
        addToPhysics(vehicle.nodeId)
    end

    for i, r in pairs(connectedReferences) do
        HoseSystemUtil:createHoseSystemJoint(r.reference)
    end

    -- only add the hose partly to physics when there are attached grabPoints
    if #grabPoints > 0 and not grabPoint.connectable and not reference.connectable then
        self:addToPhysicsParts(grabPoint, grabPoints, vehicle, reference, false)
    else
        self.object:addToPhysics() -- add it back
    end

    if self.object.isServer then
        self.object:raiseDirtyFlags(self.object.vehicleDirtyFlag)
    end
end

---
-- @param grabPoints
-- @param vehicle
-- @param reference
--
function HoseSystemPlayerInteractiveHandling:hardParkHose(grabPoints, vehicle, reference)
    if #grabPoints < 2 then
        return
    end

    local connectedReferences = HoseSystemUtil:getReferencesWithSingleConnection(vehicle, reference.id)

    for i, r in pairs(connectedReferences) do
        HoseSystemUtil:removeHoseSystemJoint(r.reference)
    end

    if not reference.isObject then
        HoseSystemUtil:removeFromPhysicsRecursively(vehicle)
    end

    -- set the controlling index
    local index = grabPoints[1].id

    local startTargetNode = createTransformGroup('hoseSystem_startTargetNode')
    local centerTargetNode = createTransformGroup('hoseSystem_centerTargetNode')
    local endTargetNode = createTransformGroup('hoseSystem_endTargetNode')

    link(reference.node, startTargetNode)
    link(reference.node, centerTargetNode)
    link(reference.node, endTargetNode)

    self.object:removeFromPhysics()

    -- Move all components to compound childs
    setIsCompoundChild(self.object.components[grabPoints[1].componentIndex].node, true)
    setIsCompoundChild(self.object.components[(#self.object.components + 1) / 2].node, true)
    setIsCompoundChild(self.object.components[grabPoints[2].componentIndex].node, true)

    -- Center node needs some dummy data
    local parkData = {
        leadingIndex = index,
        reference = reference,
        hoseLength = self.object.data.length
    }

    HoseSystemPlayerInteractiveHandling:hardParkHoseComponent(parkData, grabPoints[1], startTargetNode, self.object.components[grabPoints[1].componentIndex].node, reference.startTransOffset, reference.startRotOffset)
    HoseSystemPlayerInteractiveHandling:hardParkHoseComponent(parkData, { node = self.object.data.centerNode, id = 2 }, centerTargetNode, self.object.components[(#self.object.components + 1) / 2].node, { 0, 0, 0 }, { 0, 0, 0 }, self.object.data.length / 2)
    HoseSystemPlayerInteractiveHandling:hardParkHoseComponent(parkData, grabPoints[2], endTargetNode, self.object.components[grabPoints[2].componentIndex].node, reference.endTransOffset, reference.endRotOffset, self.object.data.length)

    self.object.data.parkStartTargetNode = startTargetNode
    self.object.data.parkCenterTargetNode = centerTargetNode
    self.object.data.parkEndTargetNode = endTargetNode

    for i, r in pairs(connectedReferences) do
        HoseSystemUtil:createHoseSystemJoint(r.reference)
    end

    if not reference.isObject then
        HoseSystemUtil:addToPhysicsRecursively(vehicle)
    end

    if self.object.isServer then
        -- this should force and update on the components
        self.object:raiseDirtyFlags(self.object.vehicleDirtyFlag)
        self.object.forceCompontentUpdate = true

        if not reference.isObject then
            vehicle:raiseDirtyFlags(vehicle.vehicleDirtyFlag)
        end
    end
end

---
-- @param parkData
-- @param grabPoint
-- @param linkNode
-- @param componentNode
-- @param transOffset
-- @param rotOffset
-- @param offset
--
function HoseSystemPlayerInteractiveHandling:hardParkHoseComponent(parkData, grabPoint, linkNode, componentNode, transOffset, rotOffset, offset)
    local reference = parkData.reference
    local referenceTranslation = HoseSystemUtil:getOffsetTargetTranslation(reference.node, reference.offsetDirection, offset)
    local xRotOffset, yRotOffset, zRotOffset = 0, 0, 0
    local xOffset, yOffset, zOffset = 0, 0, 0

    -- make offset depending the hoseLength
    if parkData.hoseLength >= reference.offsetThreshold then
        xRotOffset, yRotOffset, zRotOffset = HoseSystemUtil:getOffsetTargetRotation(parkData.leadingIndex, unpack(rotOffset))
        xOffset, yOffset, zOffset = unpack(transOffset)
    end

    local referenceRotation = { localRotationToLocal(componentNode, grabPoint.node, xRotOffset, yRotOffset, zRotOffset) }
    referenceRotation[2] = HoseSystemUtil:processTargetYRotation(parkData.leadingIndex, reference.offsetDirection, referenceRotation[2])

    local direction = { localDirectionToLocal(componentNode, grabPoint.node, 0, 0, grabPoint.id > 1 and 1 or -1) } -- grabPoints.id > 1 and 1 or -1 grabPoints.id > 1 and 1 or -1
    local upVector = { localDirectionToLocal(componentNode, grabPoint.node, 0, 1, 0) } -- grabPoints.id > 1 and -1 or 1

    setDirection(componentNode, direction[1], direction[2], direction[3], upVector[1], upVector[2], upVector[3])

    local translation = { localToLocal(componentNode, grabPoint.node, xOffset, yOffset, zOffset) }
    setTranslation(componentNode, unpack(translation))
    setRotation(componentNode, unpack(referenceRotation))

    setWorldTranslation(linkNode, unpack(referenceTranslation))

    link(linkNode, componentNode)
end

---
-- @param grabPoints
-- @param vehicle
-- @param reference
--
function HoseSystemPlayerInteractiveHandling:hardUnparkHose(grabPoints, vehicle, reference)
    if #grabPoints < 2 then
        return
    end

    local connectedReferences = HoseSystemUtil:getReferencesWithSingleConnection(vehicle, reference.id)

    for i, r in pairs(connectedReferences) do
        HoseSystemUtil:removeHoseSystemJoint(r.reference)
    end

    if not reference.isObject then
        HoseSystemUtil:removeFromPhysicsRecursively(vehicle)
    end

    self.object:removeFromPhysics()

    setIsCompound(self.object.components[grabPoints[1].componentIndex].node, true)
    setIsCompound(self.object.components[(#self.object.components + 1) / 2].node, true)
    setIsCompound(self.object.components[grabPoints[2].componentIndex].node, true)

    HoseSystemPlayerInteractiveHandling:hardUnparkHoseComponent(grabPoints[1].node, self.object.components[grabPoints[1].componentIndex].node)
    HoseSystemPlayerInteractiveHandling:hardUnparkHoseComponent(self.object.data.centerNode, self.object.components[(#self.object.components + 1) / 2].node)
    HoseSystemPlayerInteractiveHandling:hardUnparkHoseComponent(grabPoints[2].node, self.object.components[grabPoints[2].componentIndex].node)

    HoseSystemUtil:safeDeleteNode(self.object.data.parkStartTargetNode)
    HoseSystemUtil:safeDeleteNode(self.object.data.parkCenterTargetNode)
    HoseSystemUtil:safeDeleteNode(self.object.data.parkEndTargetNode)

    if not reference.isObject then
        HoseSystemUtil:addToPhysicsRecursively(vehicle)
    end

    for i, r in pairs(connectedReferences) do
        HoseSystemUtil:createHoseSystemJoint(r.reference)
    end

    self.object:addToPhysics()

    if self.object.isServer then
        self.object:raiseDirtyFlags(self.object.vehicleDirtyFlag)
    end
end

---
-- @param grabPointNode
-- @param componentNode
--
function HoseSystemPlayerInteractiveHandling:hardUnparkHoseComponent(grabPointNode, componentNode)
    local translation = { getWorldTranslation(componentNode) }

    local direction = { localDirectionToWorld(grabPointNode, 0, 0, 1) }
    local upVector = { localDirectionToWorld(grabPointNode, 0, 1, 0) }

    setTranslation(componentNode, unpack(translation))
    setDirection(componentNode, direction[1], direction[2], direction[3], upVector[1], upVector[2], upVector[3])

    link(getRootNode(), componentNode)
end

---
-- @param grabPoint
-- @param connectedGrabPoints
-- @param vehicle
-- @param reference
-- @param isConnecting
--
function HoseSystemPlayerInteractiveHandling:addToPhysicsParts(grabPoint, connectedGrabPoints, vehicle, reference, isConnecting)
    --    if self.object.isAddedToPhysics then
    --       return true
    --    end

    local connectedComponentIndexes = {}

    for index, gp in pairs(connectedGrabPoints) do
        connectedComponentIndexes[gp.componentIndex] = true
    end

    for componentIndex, component in pairs(self.object.components) do
        -- check what to add or not
        -- we only introduce the components connected to a grabPoint at this stage

        if isConnecting and componentIndex ~= grabPoint.componentIndex then
            for _, gp in pairs(self.object.grabPoints) do
                -- we only add components that are not related to the grabpoint we want to connect
                if gp.componentIndex ~= grabPoint.componentIndex and componentIndex == gp.componentIndex and not connectedComponentIndexes[componentIndex] then
                    -- it also does not exists in the connected table
                    if g_hoseSystem.debugRendering then
                        HoseSystemUtil:log(HoseSystemUtil.DEBUG, 'We only add component ' .. componentIndex .. ' to physics')
                    end

                    addToPhysics(component.node)
                end
            end
        elseif componentIndex == grabPoint.componentIndex then
            addToPhysics(component.node)
        end
    end

    for _, collisionPair in pairs(self.object.collisionPairs) do
        setPairCollision(collisionPair.component1.node, collisionPair.component2.node, collisionPair.enabled)
    end

    if not self.object.isServer then
        return
    end

    if isConnecting and (#connectedComponentIndexes > 0 or #connectedGrabPoints > 0) then
        return
    end

    -- Todo: cleanup
    -- do joints
    -- if we disconnect the hose we need to create the joints on the other connected grabPoint
    local gp = grabPoint
    if not isConnecting then
        gp = HoseSystemUtil:getFirstElement(connectedGrabPoints)
    end

    local object = not isConnecting and HoseSystemReferences:getReferenceVehicle(gp.connectorVehicle) or vehicle
    local reference = not isConnecting and HoseSystemReferences:getReference(gp.connectorVehicle, gp.connectorRefId, gp) or reference

    self:createCustomComponentJoint(gp, object, reference)
end

---
-- @param grabPoint
-- @param object
-- @param reference
--
function HoseSystemPlayerInteractiveHandling:createCustomComponentJoint(grabPoint, object, reference)
    if not self.object.isServer then
        return
    end

    for i, jointDesc in pairs(self.object.componentJoints) do
        -- Only create on the grabPoint index
        if grabPoint.componentJointIndex == i then
            if g_hoseSystem.debugRendering then
                HoseSystemUtil:log(HoseSystemUtil.DEBUG, 'We only add the component joint between the last and first component ' .. i)
            end

            -- Create custom joint since we need the jointTransforms option on the joint
            jointDesc.hoseJointIndex = HoseSystemPlayerInteractiveHandling:constructReferenceJoints({
                actor1 = self.object.components[grabPoint.componentIndex > 1 and 1 or self.object.jointSpline.endComponentId].node,
                actor2 = object.components[reference.componentIndex].node,
                anchor1 = reference.node,
                anchor2 = reference.node,
                isConnector = false,
                rotLimit = { HoseSystemPlayerInteractiveHandling.JOINT_XZ_ROT_LIMIT, HoseSystemPlayerInteractiveHandling.JOINT_XZ_ROT_LIMIT, 0 },
                transLimit = { 0, 0, 0 }
            })
        end
    end
end

---
--
function HoseSystemPlayerInteractiveHandling:deleteCustomComponentJoint()
    if not self.object.isServer then
        return
    end

    for i, jointDesc in pairs(self.object.componentJoints) do
        if jointDesc.hoseJointIndex ~= nil then
            removeJoint(jointDesc.hoseJointIndex)
            jointDesc.hoseJointIndex = nil
        end
    end
end
