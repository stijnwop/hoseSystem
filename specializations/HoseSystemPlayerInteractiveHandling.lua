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
            if HoseSystem:getIsAttached(grabPoint.state) then
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

                        self:renderHelpTextOnNode(node, g_i18n:getText('action_attachHose'), g_i18n:getText('input_mouseInteract'):format(string.lower(MouseHelper.getButtonName(Input.MOUSE_BUTTON_LEFT))))

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
        local inRange, index = self:getIsPlayerInGrabPointRange()

        if inRange then
            local grabPoint = self.object.grabPoints[index]

            if grabPoint ~= nil then
                if HoseSystem:getIsDetached(grabPoint.state) then
                    self:renderHelpTextOnNode(grabPoint.node, g_i18n:getText('action_grabHose'), g_i18n:getText('input_mouseInteract'):format(string.lower(MouseHelper.getButtonName(Input.MOUSE_BUTTON_LEFT))))

                    g_currentMission:enableHudIcon('attach', 1)

                    if InputBinding.hasEvent(InputBinding.attachHose) then
                        self:grab(index, g_currentMission.player)
                    end
                elseif HoseSystem:getIsConnected(grabPoint.state) or HoseSystem:getIsParked(grabPoint.state) then
                    --
                    if HoseSystemReferences:getAllowsDetach(self.object, index) then -- or grabPoint.connectorRef.connectable then -- Todo: cleanup allowDetach
                        if grabPoint.hasJointIndex then -- or grabPoint.connectorRef.hasJointIndex then -- Put the index through it with the jointIndex!
                            self:renderHelpTextOnNode(grabPoint.node, g_i18n:getText('action_detachHose'), g_i18n:getText('input_mouseInteract'):format(string.lower(MouseHelper.getButtonName(Input.MOUSE_BUTTON_RIGHT))))

                            if InputBinding.hasEvent(InputBinding.detachHose) then
                                --if self:allowsDetach(index) then
                                local vehicle = grabPoint.connectorVehicle
                                --                                local reference = grabPoint.connectable and vehicle.grabPoints[grabPoint.connectorRefId] or vehicle.hoseSystemReferences[grabPoint.connectorRefId]
                                local reference = HoseSystemReferences:getReference(vehicle, grabPoint.connectorRefId, grabPoint)

                                if reference ~= nil then
                                    local extenable = not reference.parkable and ((reference.connectable ~= nil and reference.connectable) or (grabPoint.connectable ~= nil and grabPoint.connectable))

                                    if reference.hasJointIndex then
                                        vehicle.poly.interactiveHandling:detach(reference.id, self, index, extenable)
                                    else
                                        self:detach(index, vehicle, reference.id, extenable)
                                    end

                                    if not grabPoint.connectable and (reference ~= nil and not reference.connectable) and reference.parkable then
                                        -- print('we should grab')
                                        -- TODO: Oke this fucks up the
                                        -- self:grab(index, g_currentMission.player)
                                    end
                                end

                                --else
                                --g_currentMission:showBlinkingWarning('Manure hose is locked message here!', 1000)
                                --end
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

function HoseSystemPlayerInteractiveHandling:grab(index, player, noEventSend)
    if self.object.grabPoints ~= nil then
        HoseSystemGrabEvent.sendEvent(self, index, player, noEventSend)

        local grabPoint = self.object.grabPoints[index]

        if grabPoint == nil then
            return
        end

        if player ~= nil then
            grabPoint.state = HoseSystem.STATE_ATTACHED

            -- Todo: we call the function set owner
            -- But do not event it again since we already getting reloaded by the grab event
            self:setGrabPointOwner(index, true, player, true)

            player:setWoodWorkVisibility(true, false)

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
                HoseSystemPlayerInteractiveHandling:constructPlayerJoint({
                    actor1 = player.hoseSystem.kinematicHelper.node,
                    actor2 = self.object.components[grabPoint.componentIndex].node,
                    anchor1 = player.hoseSystem.kinematicHelper.node,
                    anchor2 = grabPoint.node
                }, player.hoseSystem)

                -- Set collision mask on hose components to disable collision with CCT
                -- Since we cannot set non collidable objects for the CCT we just set the collision mask of the object
                if grabPoint.componentIndex ~= nil then
                    setCollisionMask(self.object.components[grabPoint.componentIndex].node, HoseSystem.cctCollisionMask)
                    setCollisionMask(self.object.components[(#self.object.components + 1) / 2].node, HoseSystem.cctCollisionMask)
                end

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
        end
    end
end

function HoseSystemPlayerInteractiveHandling:drop(index, player, noEventSend)
    if self.object.grabPoints ~= nil then
        HoseSystemDropEvent.sendEvent(self, index, player, noEventSend)

        local grabPoint = self.object.grabPoints[index]

        if grabPoint == nil then
            return
        end

        if player ~= nil then
            grabPoint.state = HoseSystem.STATE_DETACHED

            self:setGrabPointOwner(index, false, player, true)

            player:setWoodWorkVisibility(false, false)
            player.walkingSpeed = self.object.walkingSpeed
            player.runningFactor = self.object.runningFactor

            if self.object.isServer then
                if player.hoseSystem ~= nil then
                    if player.hoseSystem.jointIndex ~= nil then
                        removeJoint(player.hoseSystem.jointIndex)

                        setTranslation(grabPoint.node, unpack(grabPoint.nodeOrgTrans))
                        setRotation(grabPoint.node, unpack(grabPoint.nodeOrgRot))

                        -- Player
                        if player.hoseSystem.kinematicHelper.node ~= nil then
                            unlink(player.hoseSystem.kinematicHelper.node)
                            delete(player.hoseSystem.kinematicHelper.node)
                        end

                        player.hoseSystem.jointIndex = nil
                        player.hoseSystem.kinematicHelper.node = nil

                        if grabPoint.componentIndex ~= nil then
                            setCollisionMask(self.object.components[grabPoint.componentIndex].node, HoseSystem.hoseCollisionMask)
                            setCollisionMask(self.object.components[(#self.object.components + 1) / 2].node, HoseSystem.hoseCollisionMask)
                        end

                        -- set the joint limits back to zero
                        for index, gp in pairs(self.object.grabPoints) do
                            if index ~= grabPoint.id and HoseSystem:getIsConnected(gp.state) then
                                -- set rot on 1 deg for some realistic movement
                                self:setJointRotAndTransLimit({ 5, 0, 5 }, { 0, 0, 0 })
                            end
                        end
                    end
                end
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
        HoseSystemAttachEvent.sendEvent(self, index, vehicle, referenceId, isExtendable, noEventSend)

        local grabPoint = self.object.grabPoints[index]

        if grabPoint == nil or vehicle == nil then
            return
        end

        --        local object = vehicle.hoseSystemReferences ~= nil and vehicle or vehicle.grabPoints ~= nil and vehicle or vehicle.hoseSystemParent -- this might be really tricky todo
        --        local reference = (isExtendable or grabPoint.connectable) and object.grabPoints[referenceId] or object.hoseSystemReferences[referenceId]
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

                        if HoseSystem:getIsConnected(grabPoints[lastIndex].attachState) then
                            self:detach(grabPoints[lastIndex].id, nil, grabPoints[lastIndex].connectorVehicle, grabPoints[lastIndex].connectorRef.id, (grabPoints[lastIndex].connectorRef.connectable ~= nil and grabPoints[lastIndex].connectorRef.connectable) or (grabPoints[lastIndex].connectable ~= nil and grabPoints[lastIndex].connectable))
                        end

                        -- Todo: also call this on the server only?
                        -- Do this after above else it will fuckup the data..

                        if grabPoint.isOwned then -- we can't call it on start since we don't want to drop when the parking place is to small.
                            self:drop(index, grabPoint.currentOwner)
                        end
                    end

                    --if self.isServer then
                    self:hardParkHose(grabPoints, object, reference)
                    --end
                else
                    g_currentMission:showBlinkingWarning(string.format(g_i18n:getText('HOSE_PARKINGPLACE_TO_SHORT'), reference.parkLength, self.object.data.length), 5000)

                    return false
                end
            else
                -- handle connected hose
                if self.object.isServer then
                    if grabPoint.isOwned then -- we can't call it on start since we don't want to drop when the parking place is to small.
                        self:drop(index, grabPoint.currentOwner)
                    end
                end

                -- reference.grabPoints = self.grabPoints
                -- reference.liquidManureHose = self

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
                    self:setGrabPointIsUsed(grabPoint.id, true, isExtendable)
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
-- @param state
-- @param noEventSend
--
function HoseSystemPlayerInteractiveHandling:detach(index, vehicle, referenceId, isExtendable, noEventSend)
    if self.object.grabPoints ~= nil then
        HoseSystemDetachEvent.sendEvent(self, index, vehicle, referenceId, isExtendable, noEventSend)

        local grabPoint = self.object.grabPoints[index]

        if grabPoint == nil or vehicle == nil then
            return
        end

        if vehicle ~= nil then
            --            local object = vehicle.hoseSystemReferences ~= nil and vehicle or vehicle.grabPoints ~= nil and vehicle or vehicle.hoseSystemParent
            --            local reference = isExtendable and object.grabPoints[referenceId] or object.hoseSystemReferences[referenceId]
            local object = HoseSystemReferences:getReferenceVehicle(vehicle)
            local reference = HoseSystemReferences:getReference(vehicle, referenceId, grabPoint)

            if reference ~= nil then
                local grabPoints = { grabPoint }

                if reference.parkable then
                    -- handle parked hose
                    table.insert(grabPoints, index > 1 and self.object.grabPoints[1] or self.object.grabPoints[#self.object.grabPoints])

                    --if self.isServer then
                    self:hardUnparkHose(grabPoints, object, reference)
                    --end
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
                        self:setGrabPointIsUsed(grabPoint.id, false, isExtendable)

                        setTranslation(grabPoint.node, unpack(grabPoint.nodeOrgTrans))
                        setRotation(grabPoint.node, unpack(grabPoint.nodeOrgRot))
                    end

                    grabPoint.connectorRefId = 0
                    grabPoint.connectorVehicle = nil
                end
            end
        end
    end
end

---
-- @param index
-- @param isOwned
-- @param player
--
function HoseSystemPlayerInteractiveHandling:setGrabPointOwner(index, state, player, noEventSend)
    HoseSystemSetOwnerEvent.sendEvent(self.object, index, state, player, noEventSend)

    local grabPoint = self.object.grabPoints[index]

    grabPoint.isOwned = state
    grabPoint.currentOwner = (state and player ~= nil) and player or nil

    if player.hoseSystem == nil then
        player.hoseSystem = {}
    end

    player.hoseSystem.interactiveHandling = state and self or nil
    player.hoseSystem.index = state and index or nil
end


---
-- @param index
-- @param bool
--
function HoseSystemPlayerInteractiveHandling:setGrabPointIsUsed(index, isConnected, isExtendable, isCalledFromReference, noEventSend)
    if isCalledFromReference == nil then
        isCalledFromReference = false
    end

    -- event
    HoseSystemIsUsedEvent.sendEvent(self, index, isConnected, isExtendable, isCalledFromReference, noEventSend)

    local grabPoint = self.object.grabPoints[index]

    if grabPoint ~= nil then
        local vehicle = grabPoint.connectorVehicle

        grabPoint.state = isConnected and HoseSystem.STATE_CONNECTED or HoseSystem.STATE_DETACHED
        grabPoint.hasJointIndex = not isCalledFromReference and isConnected -- tell clients on which grabPoint to call the detach function on

        if vehicle ~= nil and not isCalledFromReference then
            -- Todo: get reference with the getReference function
            --            local reference = isExtendable and vehicle.grabPoints[grabPoint.connectorRefId] or vehicle.hoseSystemReferences[grabPoint.connectorRefId]
            local reference = HoseSystemReferences:getReference(vehicle, grabPoint.connectorRefId, grabPoint)
            -- Todo: not sure what to call here.. lookup

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

    playerHoseDesc.jointIndex = constructor:finalize()

    --    addJointBreakReport(playerHoseDesc.jointIndex, 'onGrabJointBreak', self)
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

    for i = 0, 2 do
        if jointDesc.isConnector then
            constructor:setRotationLimit(i, 0, 0)
        else
            constructor:setRotationLimit(i, rotLimitSpring[i + 1], rotLimitSpring[i + 1])
        end

        constructor:setTranslationLimit(i, true, 0, 0)
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
    -- Todo: delete only the connectorVehicle from physics, unlink and remove joints from that one hose when attaching an exentable hose
    --    local rootVehicle = vehicle:getRootAttacherVehicle()
    local grabPoints = {}

    for index, gp in pairs(self.object.grabPoints) do
        if gp.id ~= grabPoint.id and HoseSystem:getIsConnected(gp.state) then
            --if gp.connectable or gp.connectorRef.connectable then
            -- local reference = HoseSystemReferences:getReference(gp.connectorVehicle, gp.connectorRefId, gp)

            -- Todo: does this even make senese? Yes it seems or fucking not
            -- if reference ~= nil then
            -- if reference.connectable then
            -- gp.connectorVehicle.poly.interactiveHandling:hardDisconnect(reference, self.object, gp)
            -- elseif gp.connectable then
            -- self:hardDisconnect(gp, gp.connectorVehicle, reference)
            -- end
            -- end
            --end

            -- call detach
            -- self:detach(gp.id, gp.connectorVehicle, gp.connectorRefId, false, true)

            table.insert(grabPoints, gp)
        end
    end

    print("component id of grabPoint before doing something with physics = " .. grabPoint.componentIndex)
    print("connectedGrabPoints before doing something with physics = " .. #grabPoints)

    for index, gp in pairs(grabPoints) do
        -- gp.connectorVehicle:removeFromPhysics()

        -- setIsCompoundChild(gp.connectorVehicle.components[gp.componentIndex].node, true)
    end

    -- we always completely delete the current handled hose
    self.object:removeFromPhysics()

    if not reference.isObject then
        local currentVehicle = vehicle

        while currentVehicle ~= nil do
            currentVehicle:removeFromPhysics()
            currentVehicle = currentVehicle.attacherVehicle
        end

        -- rootVehicle:removeFromPhysics()

        -- for i = #rootVehicle.attachedImplements, 1, -1 do
        -- local implement = rootVehicle.attachedImplements[i]
        -- implement.object:removeFromPhysics()
        -- end

        -- Set solid base compound
        --        if not grabPoint.connectable and not reference.connectable then
        --        end
    else
        removeFromPhysics(vehicle.nodeId)
        --        vehicle:removeFromPhysics() -- This is the hose system parent
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

    -- This should be done before adding the controlling hose back to physics
    for index, gp in pairs(grabPoints) do
        -- gp.connectorVehicle:addToPhysics()
    end

    -- Only add the hose to physics partly when there are attached grabPoints
    if reference.isObject ~= nil then
        self:addToPhysicsParts(grabPoint, grabPoints, vehicle, reference, true)
    else
        self.object:addToPhysics()
    end

    -- Add the vehicles back to physics but sync wheels after the joint creation.
    if not reference.isObject then
        local currentVehicle = vehicle

        while currentVehicle ~= nil do
            currentVehicle:addToPhysics()
            currentVehicle = currentVehicle.attacherVehicle
        end

        -- for i = #rootVehicle.attachedImplements, 1, -1 do
        -- local implement = rootVehicle.attachedImplements[i]
        -- implement.object:addToPhysics()
        -- -- PhysicsUtil.addToPhysics(implement.object)
        -- end

        -- rootVehicle:addToPhysics()
        -- PhysicsUtil.addToPhysics(rootVehicle)
    else
        addToPhysics(vehicle.nodeId)
        --        vehicle:addToPhysics() -- This is the hose system parent
    end

    if self.object.isServer then
        --        local jointDesc = {
        --            actor1 = vehicle.components[reference.componentIndex].node,
        --            actor2 = self.object.components[grabPoint.componentIndex].node,
        --            anchor1 = reference.node,
        --            anchor2 = reference.node,
        --            isConnector = true
        --        }

        -- do we need a joint on connectable hoses?
        --        grabPoint.jointIndex = HoseSystemPlayerInteractiveHandling:constructReferenceJoints(jointDesc)

        --        for i, component in pairs(self.object.components) do
        --            print(i)
        --            if i ~= grabPoint.componentIndex then
        --                setPairCollision(component.node, vehicle.components[reference.componentIndex].node, false)
        --            end
        --        end

        -- for index, gp in pairs(grabPoints) do
        -- local reference = HoseSystemReferences:getReference(gp.connectorVehicle, gp.connectorRefId, gp)

        -- if reference ~= nil then
        -- if reference.connectable then
        -- gp.connectorVehicle.poly.interactiveHandling:hardConnect(reference, self.object, gp)
        -- elseif gp.connectable then
        -- self:hardConnect(gp, gp.connectorVehicle, reference)
        -- end
        -- end

        -- local jointDesc = {
        -- actor1 = gp.connectorVehicle.components[reference.componentIndex].node,
        -- actor2 = self.object.components[gp.componentIndex].node,
        -- anchor1 = reference.node,
        -- anchor2 = reference.node,
        -- isConnector = true
        -- }

        -- gp.jointIndex = HoseSystemPlayerInteractiveHandling:constructReferenceJoints(jointDesc)

        -- old below
        -- vehicle:createConnectJoints(vehicle.grabPoints[gp.index], gp.vehicle, gp.vehicle.grabPoints[gp.referenceId]) -- lookup? referenceId!?
        -- end

        -- if not reference.isObject then
        -- for i = #rootVehicle.attachedImplements, 1, -1 do
        -- local implement = rootVehicle.attachedImplements[i]
        -- PhysicsUtil.syncWheels(implement.object)
        -- end

        -- PhysicsUtil.syncWheels(rootVehicle)
        -- end

        self:setJointRotAndTransLimit({ 5, 0, 5 }, { 0, 0, 0 })
        self.object:raiseDirtyFlags(self.object.vehicleDirtyFlag) -- set bit.. we update the server

        if not reference.isObject then
            --            local currentVehicle = vehicle
            --
            --            while currentVehicle ~= nil do
            --                currentVehicle.raiseDirtyFlags(currentVehicle.vehicleDirtyFlag)
            --                currentVehicle = currentVehicle.attacherVehicle
            --            end
        end
    end
end


function HoseSystemPlayerInteractiveHandling:hardDisconnect(grabPoint, vehicle, reference)
    --simulatePhysics(false) -- stop physics for wheel shapes
    --    local rootVehicle = vehicle:getRootAttacherVehicle()
    local grabPoints = {}

    for index, gp in pairs(self.object.grabPoints) do
        if gp.id ~= grabPoint.id and HoseSystem:getIsConnected(gp.state) then
            --self:hardDisconnect(gp, gp.connectorVehicle, gp.connectorRef)
            table.insert(grabPoints, gp)
        end
    end

    --    print("HARDISCONNECT - id = " .. grabPoint.id)
    --    print("HARDISCONNECT - component id of grabPoint before doing something with physics = " .. grabPoint.componentIndex)
    print("HARDISCONNECT - connectedGrabPoints before doing something with physics = " .. table.getn(grabPoints))

    self:deleteCustomComponentJoint()

    local removeJoint = function(grabPoint)
        if grabPoint.jointIndex ~= nil then
            removeJoint(grabPoint.jointIndex)
            grabPoint.jointIndex = nil
        end
    end

    if self.object.isServer then
        removeJoint(grabPoint)

        --        for index, gp in pairs(grabPoints) do
        --            removeJoint(gp)
        --        end
    end

    for index, gp in pairs(grabPoints) do
        --        gp.connectorVehicle:removeFromPhysics()

        -- setIsCompound(gp.connectorVehicle.components[gp.componentIndex].node, true)
    end

    self.object:removeFromPhysics()

    if not reference.isObject then
        local currentVehicle = vehicle

        while currentVehicle ~= nil do
            currentVehicle:removeFromPhysics()
            currentVehicle = currentVehicle.attacherVehicle
        end
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
        -- whenever the vehicle is an extenable hose
        --        if reference.connectable then
        --            setIsCompound(vehicle.components[reference.componentIndex].node, true)
        --        end
        local currentVehicle = vehicle

        while currentVehicle ~= nil do
            currentVehicle:addToPhysics()
            currentVehicle = currentVehicle.attacherVehicle
        end
    end

    -- only add the hose partly to physics when there are attached grabPoints
    if #grabPoints > 0 and not grabPoint.connectable and not reference.connectable then
        self:addToPhysicsParts(grabPoint, grabPoints, vehicle, reference, false)
    else
        self.object:addToPhysics() -- add it back
    end

    --    for index, gp in pairs(grabPoints) do
    --        gp.connectorVehicle:addToPhysics()
    --        -- self:hardConnect(gp, gp.connectorVehicle, gp.connectorRef)
    --
    --        local reference = HoseSystemReferences:getReference(gp.connectorVehicle, gp.connectorRefId, gp)
    --
    --        local jointDesc = {
    --            actor1 = gp.connectorVehicle.components[reference.componentIndex].node,
    --            actor2 = self.object.components[gp.componentIndex].node,
    --            anchor1 = reference.node,
    --            anchor2 = reference.node,
    --            isConnector = true
    --        }
    --
    --        gp.jointIndex = HoseSystemPlayerInteractiveHandling:constructReferenceJoints(jointDesc)
    --    end

    if self.object.isServer then
        self.object:raiseDirtyFlags(self.object.vehicleDirtyFlag)
    end

    -- if not reference.isObject then
    -- vehicle:raiseDirtyFlags(vehicle.vehicleDirtyFlag)
    -- end
end

function HoseSystemPlayerInteractiveHandling:hardParkHose(grabPoints, vehicle, reference)
    if #grabPoints < 2 then
        return
    end

    local currentVehicle = vehicle

    while currentVehicle ~= nil do
        currentVehicle:removeFromPhysics()
        currentVehicle = currentVehicle.attacherVehicle
    end

    -- if not vehicle.isAddedToPhysics then
    -- vehicle:addToPhysics()
    -- end

    local index = grabPoints[1].id
    local strDir = grabPoints[1].id == 1 and 1 or -1
    print("index = " .. index .. ' dir = ' .. strDir)

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
        print('this?')
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
    --setRotation(centerTargetNode, unpack(centerRotation))
    -- setRotation(self.components[(table.getn(self.components) + 1) / 2].node, unpack(centerRotation))

    local direction = { localDirectionToLocal(self.object.components[(#self.object.components + 1) / 2].node, self.object.data.centerNode, 0, 0, 1) }
    local upVector = { localDirectionToLocal(self.object.components[(#self.object.components + 1) / 2].node, self.object.data.centerNode, 0, 1, 0) }

    setDirection(self.object.components[(#self.object.components + 1) / 2].node, direction[1], direction[2], direction[3], upVector[1], upVector[2], upVector[3])

    local translation = { localToLocal(self.object.components[(#self.object.components + 1) / 2].node, self.object.data.centerNode, 0, 0, 0) }
    setTranslation(self.object.components[(#self.object.components + 1) / 2].node, unpack(translation))

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

    --link(endTargetNode, self.components[grabPoints[2].componentIndex].node)
    setWorldTranslation(endTargetNode, unpack(endTranslation))

    link(endTargetNode, self.object.components[grabPoints[2].componentIndex].node)

    --grabPoints[1].jointIndex = LiquidManureHose:constructJoint(vehicle.components[reference.componentIndex].node, self.components[grabPoints[1].componentIndex].node, startTargetNode, startTargetNode, {1000, 1000, 1000}, {1000, 1000, 1000}, {1000, 1000, 1000}, {1000, 1000, 1000})
    --grabPoints[1].centerJointIndex = LiquidManureHose:constructJoint(vehicle.components[reference.componentIndex].node, self.components[(table.getn(self.components) + 1) / 2].node, centerTargetNode, centerTargetNode, {1000, 1000, 1000}, {1000, 1000, 1000}, {1000, 1000, 1000}, {1000, 1000, 1000})
    --grabPoints[2].jointIndex = LiquidManureHose:constructJoint(vehicle.components[reference.componentIndex].node, self.components[grabPoints[2].componentIndex].node, endTargetNode, endTargetNode, {1000, 1000, 1000}, {1000, 1000, 1000}, {1000, 1000, 1000}, {1000, 1000, 1000})

    -- delete(startTargetNode)
    -- delete(centerTargetNode)
    -- delete(endTargetNode)

    self.object.data.parkStartTargetNode = startTargetNode
    self.object.data.parkCenterTargetNode = centerTargetNode
    self.object.data.parkEndTargetNode = endTargetNode

    -- for i, component in pairs(self.components) do
    -- if i ~= grabPoints[1].componentIndex and i ~= grabPoints[2].componentIndex then
    -- setPairCollision(vehicle.components[reference.componentIndex].node, component.node, false)
    -- end
    -- end

    local currentVehicle = vehicle

    while currentVehicle ~= nil do
        currentVehicle:addToPhysics()
        currentVehicle = currentVehicle.attacherVehicle
    end

    -- self:addToPhysics()

    if self.object.isServer then
        -- this should force and update on the components
        --        self.object:raiseDirtyFlags(self.object.vehicleDirtyFlag)

        if not reference.isObject then
            -- fo
            vehicle:raiseDirtyFlags(vehicle.vehicleDirtyFlag)
        end
    end
end

function HoseSystemPlayerInteractiveHandling:hardUnparkHose(grabPoints, vehicle, reference)
    if #grabPoints < 2 then
        return
    end

    local currentVehicle = vehicle

    while currentVehicle ~= nil do
        currentVehicle:removeFromPhysics()
        currentVehicle = currentVehicle.attacherVehicle
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

    local currentVehicle = vehicle

    while currentVehicle ~= nil do
        currentVehicle:addToPhysics()
        currentVehicle = currentVehicle.attacherVehicle
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
                    --                    if HoseSystem.debugRendering then
                    print('We only add component ' .. componentIndex .. ' to physics')
                    --                    end

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

    --    print('!===================> is this causing that again?')

    -- do joints
    -- if we disconnect the hose we need to create the joints on the other connected grabPoint
    local gp = grabPoint
    if not isConnecting then
        gp = connectedGrabPoints[1]
    end

    local object = not isConnecting and gp.connectorVehicle or vehicle
    local reference = not isConnecting and HoseSystemReferences:getReference(gp.connectorVehicle, gp.connectorRefId, gp) or reference

    self:createCustomComponentJoint(gp, object, reference)
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

function HoseSystemPlayerInteractiveHandling:createCustomComponentJoint(grabPoint, object, reference)
    for i, jointDesc in pairs(self.object.componentJoints) do
        -- how to put some logic into this one?
        if grabPoint.componentJointIndex == i then
            if HoseSystem.debugRendering then
                print('We only add the component joint between the last and first component ' .. i)
            end

            -- create custom joint since we need the jointTransforms on this one
            jointDesc.hoseJointIndex = HoseSystemPlayerInteractiveHandling:constructReferenceJoints({
                actor1 = self.object.components[grabPoint.componentIndex > 1 and 1 or self.object.jointSpline.endComponentId].node,
                actor2 = object.components[reference.componentIndex].node,
                anchor1 = reference.node,
                anchor2 = reference.node,
                isConnector = false
            })
        end
    end
end
