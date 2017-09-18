--
-- Created by IntelliJ IDEA.
-- User: stijn
-- Date: 14-4-2017
-- Time: 13:29
-- To change this template use File | Settings | File Templates.
--

HoseSystemPlayerInteractiveHandling = {}
local HoseSystemPlayerInteractiveHandling_mt = Class(HoseSystemPlayerInteractiveHandling, HoseSystemPlayerInteractive)

function HoseSystemPlayerInteractiveHandling:new(object, mt)
    local interactiveHandling = HoseSystemPlayerInteractive:new(object, mt == nil and HoseSystemPlayerInteractiveHandling_mt or mt)

    interactiveHandling.doNetworkObjectsIteration = false

    return interactiveHandling
end

function HoseSystemPlayerInteractiveHandling:delete()
    HoseSystemPlayerInteractiveHandling:superClass().delete(self)
end

function HoseSystemPlayerInteractiveHandling:update(dt)
    HoseSystemPlayerInteractiveHandling:superClass().update(self, dt)

    -- only client sided
    if not self.object.isClient then
        return
    end

    if g_currentMission.player.hoseSystem ~= nil and g_currentMission.player.hoseSystem.interactiveHandling ~= nil then
        local index = g_currentMission.player.hoseSystem.index
        local grabPoint = self.object.grabPoints[index]

        if grabPoint ~= nil then
            if HoseSystem:getIsAttached(grabPoint.state) and grabPoint.isOwned then
                g_currentMission:addExtraPrintText(g_i18n:getText('input_mouseInteract'):format(string.lower(MouseHelper.getButtonName(Input.MOUSE_BUTTON_RIGHT))) .. ' ' .. g_i18n:getText('action_dropHose'))

                if InputBinding.hasEvent(InputBinding.detachHose) then
                    self:drop(index, grabPoint.currentOwner)
                end

                if HoseSystemReferences:getHasReferenceInRange(self.object) then
                    local object = networkGetObject(self.object.vehicleToMountHoseSystem)

                    if object ~= nil then
                        local reference = HoseSystemReferences:getReference(object, self.object.referenceIdToMountHoseSystem, grabPoint)

                        local node = grabPoint.node
                        if reference ~= nil then
                            node = reference.parkable and grabPoint.node or reference.node
                        end

                        HoseSystemUtil:renderHelpTextOnNode(node, g_i18n:getText('action_attachHose'), g_i18n:getText('input_mouseInteract'):format(string.lower(MouseHelper.getButtonName(Input.MOUSE_BUTTON_LEFT))))

                        g_currentMission:enableHudIcon('attach', 1)

                        if InputBinding.hasEvent(InputBinding.attachHose) then
                            -- print(LiquidManureHose:print_r(self.fillableObject))
                            self:attach(index, object, self.object.referenceIdToMountHoseSystem, self.object.referenceIsExtendable)
                        end
                    end
                end
            end
        end
    else
        --        local index = self:getIsPlayerInGrabPointRange()

        if g_currentMission.player.hoseSystem ~= nil and g_currentMission.player.hoseSystem.closestIndex ~= nil and g_currentMission.player.hoseSystem.closestHoseSystem == self.object then
            local index = g_currentMission.player.hoseSystem.closestIndex
            local grabPoint = self.object.grabPoints[index]

            if grabPoint ~= nil then
                if HoseSystem:getIsDetached(grabPoint.state) then
                    HoseSystemUtil:renderHelpTextOnNode(grabPoint.node, g_i18n:getText('action_grabHose'), g_i18n:getText('input_mouseInteract'):format(string.lower(MouseHelper.getButtonName(Input.MOUSE_BUTTON_LEFT))))

                    g_currentMission:enableHudIcon('attach', 1)

                    if InputBinding.hasEvent(InputBinding.attachHose) then
                        self:grab(index, g_currentMission.player)
                    end
                elseif HoseSystem:getIsConnected(grabPoint.state) or HoseSystem:getIsParked(grabPoint.state) then
                    --
                    if HoseSystemReferences:getAllowsDetach(self.object, index) then -- or grabPoint.connectorRef.connectable then
                        if grabPoint.hasJointIndex then -- or grabPoint.connectorRef.hasJointIndex then -- Put the index through it with the jointIndex!
                            HoseSystemUtil:renderHelpTextOnNode(grabPoint.node, g_i18n:getText('action_detachHose'), g_i18n:getText('input_mouseInteract'):format(string.lower(MouseHelper.getButtonName(Input.MOUSE_BUTTON_RIGHT))))

                            if InputBinding.hasEvent(InputBinding.detachHose) then
                                --if self:allowsDetach(index) then
                                local vehicle = grabPoint.connectorVehicle
                                --                                local reference = grabPoint.connectable and vehicle.grabPoints[grabPoint.connectorRefId] or vehicle.hoseSystemReferences[grabPoint.connectorRefId]
                                local reference = HoseSystemReferences:getReference(vehicle, grabPoint.connectorRefId, grabPoint)

                                if reference ~= nil then
                                    local extenable = not reference.parkable and ((reference.connectable ~= nil and reference.connectable) or (grabPoint.connectable ~= nil and grabPoint.connectable))

                                    if reference.hasJointIndex then
                                        vehicle.poly.interactiveHandling:detach(reference.id, self.object, index, extenable)
                                    else
                                        self:detach(index, vehicle, reference.id, extenable)
                                    end

                                    if not grabPoint.connectable and (reference ~= nil and not reference.connectable) and reference.parkable then
                                        -- print('we should grab')
                                        -- TODO: Oke this fucks up the
                                        -- self:grab(index, g_currentMission.player)
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
                --print('Grab hose: other clients are getting other infos')
                player:setWoodWorkVisibility(true, false)
            end
        elseif syncState == HoseSystemUtil.eventHelper.STATE_SERVER then
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
                -- Todo: lookup better way to get the correct attach rotation
                setRotation(player.hoseSystem.kinematicHelper.node, 0, yRot, 0)

                player.hoseSystem.jointIndex = HoseSystemPlayerInteractiveHandling:constructPlayerJoint({
                    actor1 = player.hoseSystem.kinematicHelper.node,
                    actor2 = self.object.components[grabPoint.componentIndex].node,
                    anchor1 = player.hoseSystem.kinematicHelper.node,
                    anchor2 = grabPoint.node
                }, player.hoseSystem)

                for i, component in pairs(self.object.components) do
                    if i ~= grabPoint.componentIndex then
                        setPairCollision(player.hoseSystem.kinematicHelper.node, component.node, false)
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
                setCollisionMask(self.object.components[grabPoint.componentIndex].node, HoseSystem.cctCollisionMask)
                setCollisionMask(self.object.components[(#self.object.components + 1) / 2].node, HoseSystem.cctCollisionMask)
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
                            -- set rot on 5 deg for some realistic movement
                            self:setJointRotAndTransLimit({ 5, 0, 5 }, { 0, 0, 0 })
                        end
                    end
                end
            end

            if grabPoint.componentIndex ~= nil then
                setCollisionMask(self.object.components[grabPoint.componentIndex].node, HoseSystem.hoseCollisionMask)
                setCollisionMask(self.object.components[(#self.object.components + 1) / 2].node, HoseSystem.hoseCollisionMask)
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

            if reference.parkable then
                -- handle parked hose
                if self.object.data.length < reference.parkLength then
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
                    g_currentMission:showBlinkingWarning(string.format(g_i18n:getText('info_hoseParkingPlaceToShort'), reference.parkLength, self.object.data.length), 5000)

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

    -- event
    HoseSystemIsUsedEvent.sendEvent(self.object, index, isConnected, isExtendable, isCalledFromReference, noEventSend)

    local grabPoint = self.object.grabPoints[index]

    if grabPoint ~= nil then
        local vehicle = HoseSystemReferences:getReferenceVehicle(grabPoint.connectorVehicle)

        grabPoint.state = isConnected and HoseSystem.STATE_CONNECTED or HoseSystem.STATE_DETACHED
        grabPoint.hasJointIndex = not isCalledFromReference and isConnected -- tell clients on which grabPoint to call the detach function on

        if vehicle ~= nil and not isCalledFromReference then
            local reference = HoseSystemReferences:getReference(grabPoint.connectorVehicle, grabPoint.connectorRefId, grabPoint)

            if not isExtendable and not reference.connectable then
                reference.hoseSystem = isConnected and self.object or nil
            end

            -- we have to call on depending objects to tell that we are connecting
            if self.object.isServer then
                -- call reference functions
                if grabPoint.connectable or isExtendable then
                    vehicle.poly.interactiveHandling:setGrabPointIsUsed(reference.id, isConnected, grabPoint.connectable, true)
                else
                    vehicle:setIsUsed(reference.id, isConnected)
                end
            end
        end
    end
end

---
-- @param jointDesc
-- @param playerHoseDesc
--
function HoseSystemPlayerInteractiveHandling:constructPlayerJoint(jointDesc, playerHoseDesc)
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
    --    constructor:setBreakable(forceLimit, forceLimit)

    --    addJointBreakReport(playerHoseDesc.jointIndex, 'onGrabJointBreak', self)

    return constructor:finalize()
end

function HoseSystemPlayerInteractiveHandling:constructReferenceJoints(jointDesc)
    local constructor = JointConstructor:new()

    constructor:setActors(jointDesc.actor1, jointDesc.actor2)
    constructor:setJointTransforms(jointDesc.anchor1, jointDesc.anchor2)
    constructor:setEnableCollision(false)

    local rotLimitSpring = { 0, 0, 0 }
    local rotLimitDamping = { 0, 0, 0 }
    local transLimitSpring = { 0, 0, 0 }
    local translimitDamping = { 0, 0, 0 }

    if jointDesc.isConnector then
        local connectorMass = getMass(jointDesc.actor1) -- * 100 -- create a strong joint

        for i = 1, 3 do
            rotLimitSpring[i] = connectorMass
            rotLimitDamping[i] = math.sqrt(connectorMass * rotLimitSpring[i]) * 2
            transLimitSpring[i] = connectorMass
            translimitDamping[i] = math.sqrt(connectorMass * transLimitSpring[i]) * 2
        end
    end

    constructor:setRotationLimitSpring(rotLimitSpring[1], rotLimitDamping[1], rotLimitSpring[2], rotLimitDamping[2], rotLimitSpring[3], rotLimitDamping[3])
    constructor:setTranslationLimitSpring(transLimitSpring[1], translimitDamping[1], transLimitSpring[2], translimitDamping[1], transLimitSpring[3], translimitDamping[3])

    for axis = 1, 3 do
        constructor:setRotationLimit(axis - 1, -jointDesc.rotLimit[axis], jointDesc.rotLimit[axis])
        constructor:setTranslationLimit(axis - 1, true, -jointDesc.transLimit[axis], jointDesc.transLimit[axis])
    end

    return constructor:finalize()
end

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
    if not self.object.isServer then
        return false
    end

    if jointIndex == g_currentMission.player.hoseSystem.jointIndex then
        g_currentMission.player.hoseSystem.interactiveHandling:drop(g_currentMission.player.hoseSystem.index, g_currentMission.player)
    end

    return false
end

function HoseSystemPlayerInteractiveHandling:hardConnect(grabPoint, vehicle, reference)
    -- Note: cause we delete the connector vehicle from physics we have to attach it back later on
    local grabPoints = {}
    -- Get all the hoses that are connected to a references from the Vehicle
    local connectedRreferences = HoseSystemUtil:getReferencesWithSingleConnection(vehicle, reference.id)

    --    print('all the attached references with single connection = ' .. #connectedRreferences)

    for index, gp in pairs(self.object.grabPoints) do
        if gp.id ~= grabPoint.id and HoseSystem:getIsConnected(gp.state) then
            table.insert(grabPoints, gp)
        end
    end

    --    print("component id of grabPoint before doing something with physics = " .. grabPoint.componentIndex)
    --    print("connectedGrabPoints before doing something with physics = " .. #grabPoints)

    for i, r in pairs(connectedRreferences) do
        HoseSystemUtil:removeHoseSystemJoint(r.reference)
    end

    -- we always completely delete the current handled hose
    self.object:removeFromPhysics()

    if not reference.isObject then
        HoseSystemUtil:removeFromPhysicsRecursively(vehicle)
    else
        removeFromPhysics(vehicle.nodeId)
    end

    setIsCompoundChild(self.object.components[grabPoint.componentIndex].node, true)

    local linkComponent = function(vehicle, grabPoint, reference)
        local moveDir = grabPoint.id > 1 and -1 or 1
        moveDir = (grabPoint.connectable or reference.connectable) and (moveDir > 0 and (reference.id > 1 and 1 or -1) or -1) or moveDir
        local direction = { localDirectionToLocal(vehicle.components[grabPoint.componentIndex].node, grabPoint.node, 0, 0, moveDir) }
        local upVector = { localDirectionToLocal(vehicle.components[grabPoint.componentIndex].node, grabPoint.node, 0, grabPoint.id > 1 and -1 or 1, 0) }

        setDirection(vehicle.components[grabPoint.componentIndex].node, direction[1], direction[2], direction[3], upVector[1], upVector[2], upVector[3])

        local translation = { localToLocal(vehicle.components[grabPoint.componentIndex].node, grabPoint.node, 0, 0, (grabPoint.connectable or reference.connectable) and -0.025 or 0) } -- Todo: make offset value dynamic
        setTranslation(vehicle.components[grabPoint.componentIndex].node, unpack(translation))

        link(reference.node, vehicle.components[grabPoint.componentIndex].node)
    end

    linkComponent(self.object, grabPoint, reference)

    for i, r in pairs(connectedRreferences) do
        HoseSystemUtil:createHoseSystemJoint(r.reference)
    end

    -- Only add the hose to physics partly when not dealing with an extenable hose
    if reference.isObject ~= nil then
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

    if self.object.isServer then
        self.object:raiseDirtyFlags(self.object.vehicleDirtyFlag) -- set bit.. we update the server
        self.object.forceCompontentUpdate = true

        if not reference.isObject then
            vehicle:raiseDirtyFlags(vehicle.vehicleDirtyFlag)
        end
    end
end


function HoseSystemPlayerInteractiveHandling:hardDisconnect(grabPoint, vehicle, reference)
    local grabPoints = {}
    -- Get all the hoses that are connected to a references from the Vehicle
    local connectedRreferences = HoseSystemUtil:getReferencesWithSingleConnection(vehicle, reference.id)

    for index, gp in pairs(self.object.grabPoints) do
        if gp.id ~= grabPoint.id and HoseSystem:getIsConnected(gp.state) then
            table.insert(grabPoints, gp)
        end
    end

    --    print("HARDISCONNECT - id = " .. grabPoint.id)
    --    print("HARDISCONNECT - component id of grabPoint before doing something with physics = " .. grabPoint.componentIndex)
    --    print("HARDISCONNECT - connectedGrabPoints before doing something with physics = " .. table.getn(grabPoints))

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

    for i, r in pairs(connectedRreferences) do
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

    for i, r in pairs(connectedRreferences) do
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

function HoseSystemPlayerInteractiveHandling:hardParkHose(grabPoints, vehicle, reference)
    if #grabPoints < 2 then
        return
    end

    local connectedRreferences = HoseSystemUtil:getReferencesWithSingleConnection(vehicle, reference.id)

    for i, r in pairs(connectedRreferences) do
        HoseSystemUtil:removeHoseSystemJoint(r.reference)
    end

    if not reference.isObject then
        HoseSystemUtil:removeFromPhysicsRecursively(vehicle)
    end

    local index = grabPoints[1].id

    -- Create nodes
    local startTargetNode = createTransformGroup('startTargetNode')
    local centerTargetNode = createTransformGroup('centerTargetNode')
    local endTargetNode = createTransformGroup('endTargetNode')

    link(reference.node, startTargetNode)
    link(reference.node, centerTargetNode)
    link(reference.node, endTargetNode)

    self.object:removeFromPhysics()

    setIsCompoundChild(self.object.components[grabPoints[1].componentIndex].node, true)
    setIsCompoundChild(self.object.components[(#self.object.components + 1) / 2].node, true)
    setIsCompoundChild(self.object.components[grabPoints[2].componentIndex].node, true)

    -- Not needed on park function
    --LiquidManureHose:orientConnectionJoint(reference.node, grabPoints[1].node, grabPoints[1].id, grabPoints[1].connectable, reference.id, isExtendable)
    --LiquidManureHose:orientConnectionJoint(reference.node, self.components[grabPoints[1].componentIndex].node, grabPoints[1].id, grabPoints[1].connectable, reference.id, isExtendable)

    local referenceTranslation = { getWorldTranslation(reference.node) }
    local xRotOffset, yRotOffset, zRotOffset = unpack(reference.startRotOffset)
    local referenceRotation = { localRotationToLocal(self.object.components[grabPoints[1].componentIndex].node, grabPoints[1].node, xRotOffset, yRotOffset, zRotOffset) }
    --local referenceRotation = {getRotation(reference.node)}

    --setTranslation(self.components[grabPoints[1].componentIndex].node, unpack(referenceTranslation))

    if reference.offsetDirection ~= 1 then
        referenceRotation[2] = index == 1 and referenceRotation[2] + math.rad(0) or referenceRotation[2] + math.rad(180)
    else
        referenceRotation[2] = index == 1 and math.rad(0) + referenceRotation[2] or math.rad(180) + referenceRotation[2]
    end

    --local referenceRotation = {localRotationToWorld(startTargetNode, unpack(referenceRotation))}
    -- setRotation(startTargetNode, unpack(referenceRotation))
    --setWorldRotation(startTargetNode, unpack(referenceRotation))

    local direction = { localDirectionToLocal(self.object.components[grabPoints[1].componentIndex].node, grabPoints[1].node, 0, 0, grabPoints[1].id > 1 and 1 or -1) } -- grabPoints[1].id > 1 and 1 or -1 grabPoints[1].id > 1 and 1 or -1
    local upVector = { localDirectionToLocal(self.object.components[grabPoints[1].componentIndex].node, grabPoints[1].node, 0, 1, 0) } -- grabPoints[1].id > 1 and -1 or 1

    setDirection(self.object.components[grabPoints[1].componentIndex].node, direction[1], direction[2], direction[3], upVector[1], upVector[2], upVector[3])

    local xOffset, yOffset, zOffset = unpack(reference.startTransOffset)
    local translation = { localToLocal(self.object.components[grabPoints[1].componentIndex].node, grabPoints[1].node, xOffset, yOffset, zOffset) }
    setTranslation(self.object.components[grabPoints[1].componentIndex].node, unpack(translation))
    setRotation(self.object.components[grabPoints[1].componentIndex].node, unpack(referenceRotation))

    --    local quaternion = {mathEulerToQuaternion(unpack(referenceRotation))}
    --    self.object:setWorldPositionQuaternion(translation[1],translation[2],translation[3], quaternion[1], quaternion[2], quaternion[3], quaternion[4], grabPoints[1].componentIndex, false)

    --link(reference.node, self.components[grabPoints[1].componentIndex].node)
    setWorldTranslation(startTargetNode, unpack(referenceTranslation))

    link(startTargetNode, self.object.components[grabPoints[1].componentIndex].node)

    local centerTranslation = reference.offsetDirection ~= 1 and { localToWorld(reference.node, 0, 0, -self.object.data.length / 2) } or { localToWorld(reference.node, 0, 0, self.object.data.length / 2) }
    local centerRotation = { getRotation(self.object.data.centerNode) }

    -- setTranslation(self.components[(table.getn(self.components) + 1) / 2].node, unpack(centerTranslation)) -- this of course only works on even values

    -- Note: does offsetDirection have influence on the y rotation?
    if reference.offsetDirection ~= 1 then
        centerRotation[2] = index == 1 and math.rad(0) or math.rad(180)
    else
        centerRotation[2] = index == 1 and math.rad(180) or math.rad(0)
    end

    local centerRotation = { localRotationToWorld(centerTargetNode, unpack(centerRotation)) }
    -- setWorldRotation(centerTargetNode, unpack(centerRotation))
    -- setRotation(centerTargetNode, unpack(centerRotation))
    -- setRotation(self.components[(table.getn(self.components) + 1) / 2].node, unpack(centerRotation))

    local direction = { localDirectionToLocal(self.object.components[(#self.object.components + 1) / 2].node, self.object.data.centerNode, 0, 0, 1) }
    local upVector = { localDirectionToLocal(self.object.components[(#self.object.components + 1) / 2].node, self.object.data.centerNode, 0, 1, 0) }

    setDirection(self.object.components[(#self.object.components + 1) / 2].node, direction[1], direction[2], direction[3], upVector[1], upVector[2], upVector[3])

    local translation = { localToLocal(self.object.components[(#self.object.components + 1) / 2].node, self.object.data.centerNode, 0, 0, 0) }
    setTranslation(self.object.components[(#self.object.components + 1) / 2].node, unpack(translation))
    --
    --    local quaternion = {mathEulerToQuaternion(getRotation(self.object.components[(#self.object.components + 1) / 2].node))}
    --    self.object:setWorldPositionQuaternion(translation[1],translation[2],translation[3], quaternion[1], quaternion[2], quaternion[3], quaternion[4], (#self.object.components + 1) / 2, false)

    --link(centerTargetNode, self.components[(table.getn(self.components) + 1) / 2].node)
    setWorldTranslation(centerTargetNode, unpack(centerTranslation))

    link(centerTargetNode, self.object.components[(#self.object.components + 1) / 2].node)

    local endTranslation = reference.offsetDirection ~= 1 and { localToWorld(reference.node, 0, 0, -self.object.data.length) } or { localToWorld(reference.node, 0, 0, self.object.data.length) }

    -- setTranslation(self.components[grabPoints[2].componentIndex].node, unpack(endTranslation))

    -- Note: does offsetDirection have influence on the y rotation?
    -- Note: this is not going to work with world rotations
    local xRotOffset, yRotOffset, zRotOffset = unpack(reference.endRotOffset)
    local referenceRotation = { localRotationToLocal(self.object.components[grabPoints[2].componentIndex].node, grabPoints[2].node, xRotOffset, yRotOffset, zRotOffset) }
    --local referenceRotation = {getRotation(reference.node)}

    if reference.offsetDirection ~= 1 then
        referenceRotation[2] = index == 1 and referenceRotation[2] + math.rad(0) or referenceRotation[2] + math.rad(180)
    else
        referenceRotation[2] = index == 1 and math.rad(0) + referenceRotation[2] or math.rad(180) + referenceRotation[2]
    end

    --local referenceRotation = {localRotationToWorld(endTargetNode, unpack(referenceRotation))}
    --setWorldRotation(endTargetNode, unpack(referenceRotation))
    --setRotation(endTargetNode, unpack(referenceRotation))
    --setRotation(self.components[grabPoints[2].componentIndex].node, unpack(referenceRotation))

    -- todo: set direction based on first grabPoints[1].id!
    local direction = { localDirectionToLocal(self.object.components[grabPoints[2].componentIndex].node, grabPoints[2].node, 0, 0, grabPoints[2].id > 1 and 1 or -1) } --grabPoints[2].id > 1 and -1 or 1
    local upVector = { localDirectionToLocal(self.object.components[grabPoints[2].componentIndex].node, grabPoints[2].node, 0, 1, 0) } -- grabPoints[1].id > 1 and -1 or 1

    setDirection(self.object.components[grabPoints[2].componentIndex].node, direction[1], direction[2], direction[3], upVector[1], upVector[2], upVector[3])

    local xOffset, yOffset, zOffset = unpack(reference.endTransOffset)
    local translation = { localToLocal(self.object.components[grabPoints[2].componentIndex].node, grabPoints[2].node, xOffset, yOffset, zOffset) }
    setTranslation(self.object.components[grabPoints[2].componentIndex].node, unpack(translation))
    setRotation(self.object.components[grabPoints[2].componentIndex].node, unpack(referenceRotation))

    --    if not self.object.isServer then
    --        local quaternion = {mathEulerToQuaternion(unpack(referenceRotation))}
    --        self.object:setWorldPositionQuaternion(translation[1],translation[2],translation[3], quaternion[1], quaternion[2], quaternion[3], quaternion[4], grabPoints[2].componentIndex, false)
    --    end

    --link(endTargetNode, self.components[grabPoints[2].componentIndex].node)
    setWorldTranslation(endTargetNode, unpack(endTranslation))

    link(endTargetNode, self.object.components[grabPoints[2].componentIndex].node)

    --grabPoints[1].jointIndex = HoseSystemPlayerInteractiveHandling:constructJoint(vehicle.components[reference.componentIndex].node, self.components[grabPoints[1].componentIndex].node, startTargetNode, startTargetNode, {1000, 1000, 1000}, {1000, 1000, 1000}, {1000, 1000, 1000}, {1000, 1000, 1000})
    --grabPoints[1].centerJointIndex = HoseSystemPlayerInteractiveHandling:constructJoint(vehicle.components[reference.componentIndex].node, self.components[(table.getn(self.components) + 1) / 2].node, centerTargetNode, centerTargetNode, {1000, 1000, 1000}, {1000, 1000, 1000}, {1000, 1000, 1000}, {1000, 1000, 1000})
    --grabPoints[2].jointIndex = HoseSystemPlayerInteractiveHandling:constructJoint(vehicle.components[reference.componentIndex].node, self.components[grabPoints[2].componentIndex].node, endTargetNode, endTargetNode, {1000, 1000, 1000}, {1000, 1000, 1000}, {1000, 1000, 1000}, {1000, 1000, 1000})

    self.object.data.parkStartTargetNode = startTargetNode
    self.object.data.parkCenterTargetNode = centerTargetNode
    self.object.data.parkEndTargetNode = endTargetNode

    for i, r in pairs(connectedRreferences) do
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

function HoseSystemPlayerInteractiveHandling:hardUnparkHose(grabPoints, vehicle, reference)
    if #grabPoints < 2 then
        return
    end

    local connectedRreferences = HoseSystemUtil:getReferencesWithSingleConnection(vehicle, reference.id)

    for i, r in pairs(connectedRreferences) do
        HoseSystemUtil:removeHoseSystemJoint(r.reference)
    end

    if not reference.isObject then
        HoseSystemUtil:removeFromPhysicsRecursively(vehicle)
    end

    self.object:removeFromPhysics()

    setIsCompound(self.object.components[grabPoints[1].componentIndex].node, true)
    setIsCompound(self.object.components[(#self.object.components + 1) / 2].node, true)
    setIsCompound(self.object.components[grabPoints[2].componentIndex].node, true)

    --
    local translation = { getWorldTranslation(self.object.components[grabPoints[1].componentIndex].node) }
    setTranslation(self.object.components[grabPoints[1].componentIndex].node, unpack(translation))

    local direction = { localDirectionToWorld(grabPoints[1].node, 0, 0, 1) }
    local upVector = { localDirectionToWorld(grabPoints[1].node, 0, 1, 0) }

    setDirection(self.object.components[grabPoints[1].componentIndex].node, direction[1], direction[2], direction[3], upVector[1], upVector[2], upVector[3])

    link(getRootNode(), self.object.components[grabPoints[1].componentIndex].node)
    --
    --
    local translation = { getWorldTranslation(self.object.components[(#self.object.components + 1) / 2].node) }
    setTranslation(self.object.components[(#self.object.components + 1) / 2].node, unpack(translation))

    local direction = { localDirectionToWorld(self.object.data.centerNode, 0, 0, 1) }
    local upVector = { localDirectionToWorld(self.object.data.centerNode, 0, 1, 0) }

    setDirection(self.object.components[(#self.object.components + 1) / 2].node, direction[1], direction[2], direction[3], upVector[1], upVector[2], upVector[3])

    link(getRootNode(), self.object.components[(#self.object.components + 1) / 2].node)
    --
    --
    local translation = { getWorldTranslation(self.object.components[grabPoints[2].componentIndex].node) }
    setTranslation(self.object.components[grabPoints[2].componentIndex].node, unpack(translation))

    local direction = { localDirectionToWorld(grabPoints[2].node, 0, 0, 1) }
    local upVector = { localDirectionToWorld(grabPoints[2].node, 0, 1, 0) }

    setDirection(self.object.components[grabPoints[2].componentIndex].node, direction[1], direction[2], direction[3], upVector[1], upVector[2], upVector[3])
    link(getRootNode(), self.object.components[grabPoints[2].componentIndex].node)
    --

    delete(self.object.data.parkStartTargetNode)
    delete(self.object.data.parkCenterTargetNode)
    delete(self.object.data.parkEndTargetNode)

    if not reference.isObject then
        HoseSystemUtil:addToPhysicsRecursively(vehicle)
    end

    for i, r in pairs(connectedRreferences) do
        HoseSystemUtil:createHoseSystemJoint(r.reference)
    end

    self.object:addToPhysics()

    if self.object.isServer then
        self.object:raiseDirtyFlags(self.object.vehicleDirtyFlag)
    end
end

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
                    if HoseSystem.debugRendering then
                        print('We only add component ' .. componentIndex .. ' to physics')
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
        gp = connectedGrabPoints[1]
    end

    local object = not isConnecting and HoseSystemReferences:getReferenceVehicle(gp.connectorVehicle) or vehicle
    local reference = not isConnecting and HoseSystemReferences:getReference(gp.connectorVehicle, gp.connectorRefId, gp) or reference

    self:createCustomComponentJoint(gp, object, reference)
end

function HoseSystemPlayerInteractiveHandling:createCustomComponentJoint(grabPoint, object, reference)
    if not self.object.isServer then
        return
    end

    for i, jointDesc in pairs(self.object.componentJoints) do
        -- Only create on the grabPoint index
        if grabPoint.componentJointIndex == i then
            if HoseSystem.debugRendering then
                print('We only add the component joint between the last and first component ' .. i)
            end

            -- Create custom joint since we need the jointTransforms option on the joint
            jointDesc.hoseJointIndex = HoseSystemPlayerInteractiveHandling:constructReferenceJoints({
                actor1 = self.object.components[grabPoint.componentIndex > 1 and 1 or self.object.jointSpline.endComponentId].node,
                actor2 = object.components[reference.componentIndex].node,
                anchor1 = reference.node,
                anchor2 = reference.node,
                isConnector = false,
                rotLimit = { 5, 0, 5 },
                transLimit = { 0, 0, 0 }
            })
        end
    end
end

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