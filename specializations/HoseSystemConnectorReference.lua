--
--	HoseSystemConnectorReference
--
--	@author: 	 Wopster
--	@descripion: 
--	@website:
--	@history:	 v1.0 - 2016-02-11 - Initial implementation
--

HoseSystemConnectorReference = {
    name = g_currentModName,
    debug = true,
    directions = {
        right = 1, -- positive/negative axis
        left = -1
    }
}

function HoseSystemConnectorReference.prerequisitesPresent(specializations)
    return true
end

function HoseSystemConnectorReference:print_r(t, name, indent)
    local tableList = {}

    function table_r(t, name, indent, full)
        local id = not full and name or type(name) ~= "number" and tostring(name) or '[' .. name .. ']'
        local tag = indent .. id .. ' : '
        local out = {}

        if type(t) == "table" then
            if tableList[t] ~= nil then
                table.insert(out, tag .. '{} -- ' .. tableList[t] .. ' (self reference)')
            else
                tableList[t] = full and (full .. '.' .. id) or id

                if next(t) then -- If table not empty.. fill it further
                    table.insert(out, tag .. '{')

                    for key, value in pairs(t) do
                        table.insert(out, table_r(value, key, indent .. '|  ', tableList[t]))
                    end

                    table.insert(out, indent .. '}')
                else
                    table.insert(out, tag .. '{}')
                end
            end
        else
            local val = type(t) ~= "number" and type(t) ~= "boolean" and '"' .. tostring(t) .. '"' or tostring(t)
            table.insert(out, tag .. val)
        end

        return table.concat(out, '\n')
    end

    return table_r(t, name or 'Value', indent or '')
end

function HoseSystemConnectorReference:load(savegame)
    self.toggleLock = HoseSystemConnectorReference.toggleLock
    self.toggleManureFlow = HoseSystemConnectorReference.toggleManureFlow
    self.setIsUsed = HoseSystemConnectorReference.setIsUsed
    self.getConnectedReference = HoseSystemConnectorReference.getConnectedReference

    -- new
    self.getValidFillObject = HoseSystemConnectorReference.getValidFillObject
    self.getAllowedFillUnitIndex = HoseSystemConnectorReference.getAllowedFillUnitIndex

    self.getLastGrabpointRecursively = HoseSystemConnectorReference.getLastGrabpointRecursively

    self.updateLiquidManureHose = HoseSystemConnectorReference.updateLiquidManureHose
    self.updateLiquidManureHoseSystemFillTrigger = HoseSystemConnectorReference.updateLiquidManureHoseSystemFillTrigger

    -- overwrittenFunctions
    self.getIsOverloadingAllowed = Utils.overwrittenFunction(self.getIsOverloadingAllowed, HoseSystemConnectorReference.getIsOverloadingAllowed)

    self.hoseSystemReferences = {}
    self.dockingSystemReferences = {}

    self.inRageReferenceIndex = nil

    HoseSystemConnectorReference.loadHoseReferences(self, self.xmlFile, 'vehicle.hoseSystemReferences.', self.hoseSystemReferences)
    -- HoseSystemConnectorReference.loadDockingReferences(self, self.xmlFile, 'vehicle.dockingSystemReferences.', self.dockingSystemReferences)

    self.fillObject = nil
    self.fillObjectFound = false
    self.fillObjectHasPlane = false
    self.fillFromFillVolume = false
    self.fillUnitIndex = 0
    self.isSucking = false

    if self.isServer then
        self.lastFillObjectFound = false
        self.lastFillObjectHasPlane = false
        self.lastFillFromFillVolume = false
        self.lastFillUnitIndex = 0
    end

    if self.hasHoseSystemPumpMotor then
        self.pumpMotorFillMode = HoseSystemPumpMotor.getInitialFillMode('hoseSystem')
    end

    self.rayCastNode = 0 -- dynamic node
    self.rayCastingActive = true -- server
    self.allowRayCasting = true -- server

    self.hasHoseSystem = true

    if self.unloadTrigger ~= nil then
        self.unloadTrigger:delete()
        self.unloadTrigger = nil
    end

    HoseSystemConnectorReference:updateCurrentMissionInfo(self)
end

function HoseSystemConnectorReference:postLoad(savegame)
    if savegame ~= nil and not savegame.resetVehicles then
        for id, reference in pairs(self.hoseSystemReferences) do
            local key = string.format('%s.reference(%d)', savegame.key, id - 1)

            self:toggleLock(id, getXMLBool(savegame.xmlFile, key .. '#isLocked'))
            self:toggleManureFlow(id, getXMLBool(savegame.xmlFile, key .. '#flowOpened'))
        end
    end
end

function HoseSystemConnectorReference.loadHoseReferences(self, xmlFile, base, references)
    local i = 0

    while true do
        local key = string.format(base .. 'hoseSystemReference(%d)', i)

        if not hasXMLProperty(xmlFile, key) then
            break
        end

        local node = Utils.indexToObject(self.components, getXMLString(xmlFile, key .. '#index'))

        if node ~= nil then
            local entry = {
                id = i + 1,
                node = node,
                isUsed = false,
                flowOpened = false,
                isLocked = false,
                hoseSystem = nil,
                grabPoints = nil,
                isObject = false,
                componentIndex = Utils.getNoNil(getXMLFloat(xmlFile, key .. 'componentIndex'), 0) + 1,
                parkable = Utils.getNoNil(getXMLBool(xmlFile, key .. '#parkable'), false),
                lockAnimationName = Utils.getNoNil(getXMLString(xmlFile, key .. '#lockAnimationName'), nil),
                manureFlowAnimationName = Utils.getNoNil(getXMLString(xmlFile, key .. '#manureFlowAnimationName'), nil)
            }

            if entry.parkable then
                entry.parkAnimationName = Utils.getNoNil(getXMLString(xmlFile, key .. '#parkAnimationName'), nil)
                local offsetDirection = Utils.getNoNil(getXMLString(xmlFile, key .. '#offsetDirection'), 'right')
                entry.parkLength = Utils.getNoNil(getXMLFloat(xmlFile, key .. '#parkLength'), 5) -- Default length of 5m
                entry.offsetDirection = offsetDirection ~= 'right' and HoseSystemConnectorReference.directions.left or HoseSystemConnectorReference.directions.right
                entry.startTransOffset = Utils.getNoNil(Utils.getVectorNFromString(getXMLString(xmlFile, key .. '#startTransOffset'), 3), { 0, 0, 0 })
                entry.startRotOffset = Utils.getNoNil(Utils.getVectorNFromString(getXMLString(xmlFile, key .. '#startRotOffset'), 3), { 0, 0, 0 })
                entry.endTransOffset = Utils.getNoNil(Utils.getVectorNFromString(getXMLString(xmlFile, key .. '#endTransOffset'), 3), { 0, 0, 0 })
                entry.endRotOffset = Utils.getNoNil(Utils.getVectorNFromString(getXMLString(xmlFile, key .. '#endRotOffset'), 3), { 0, 0, 0 })
                -- entry.startRotOffset = Utils.getNoNil(Utils.getVectorNFromString(getXMLString(xmlFile, key .. '#parkTransOffset'), 3), {0, 0, 0})
                -- entry.parkTransOffset = Utils.getNoNil(Utils.getVectorNFromString(getXMLString(xmlFile, key .. '#parkTransOffset'), 3), {0, 0, 0})
                -- entry.parkRotOffset = Utils.getNoNil(Utils.getVectorNFromString(getXMLString(xmlFile, key .. '#parkRotOffset'), 3), {0, 0, 0})
                local maxNode = createTransformGroup(('maxNode%d'):format(entry.id))
                link(entry.node, maxNode)
                local trans = { localToWorld(node, 0, 0, entry.offsetDirection ~= 1 and -entry.parkLength or entry.parkLength) }
                setWorldTranslation(maxNode, unpack(trans))
                entry.maxParkLengthNode = maxNode
            end

            table.insert(references, entry)
        end

        i = i + 1
    end
end

function HoseSystemConnectorReference:updateCurrentMissionInfo(object)
    if #object.hoseSystemReferences > 0 then
        if g_currentMission.hoseSystemReferences == nil then
            g_currentMission.hoseSystemReferences = {}
        end

        --        g_currentMission.hoseSystemReferences[self.hoseSystemId] = object
        table.insert(g_currentMission.hoseSystemReferences, object)
    end

    if #object.dockingSystemReferences > 0 then
        if g_currentMission.dockingSystemReferences == nil then
            g_currentMission.dockingSystemReferences = {}
        end

        --        g_currentMission.dockingSystemReferences[self.hoseSystemId] = object
        table.insert(g_currentMission.dockingSystemReferences, object)
    end
end

function HoseSystemConnectorReference:preDelete()
    if self.hoseSystemReferences ~= nil and g_currentMission.hoseSystemHoses ~= nil then
        for referenceId, reference in pairs(self.hoseSystemReferences) do
            if reference.isUsed then
                if reference.hoseSystem ~= nil and reference.hoseSystem.grabPoints ~= nil then
                    for grabPointIndex, grabPoint in pairs(reference.hoseSystem.grabPoints) do
                        if HoseSystem:getIsConnected(grabPoint.state) and grabPoint.connectorRefId == referenceId then
                            reference.hoseSystem.poly.interactiveHandling:detach(grabPointIndex, self, referenceId, false)
                        end
                    end
                end
            end
        end
    end
end

function HoseSystemConnectorReference:delete()
    if g_currentMission.hoseSystemReferences ~= nil then
        for i = 1, #g_currentMission.hoseSystemReferences do
            if g_currentMission.hoseSystemReferences[i] == self then
                table.remove(g_currentMission.hoseSystemReferences, i)
                break
            end
        end
    end

    if g_currentMission.dockingSystemReferences ~= nil then
        for i = 1, #g_currentMission.dockingSystemReferences do
            if g_currentMission.dockingSystemReferences[i] == self then
                table.remove(g_currentMission.dockingSystemReferences, i)
                break
            end
        end
    end
end

function HoseSystemConnectorReference:readStream(streamId, connection)
    self.fillObjectFound = streamReadBool(streamId)
    self.fillFromFillVolume = streamReadBool(streamId)
    local currentReferenceIndex = streamReadInt8(streamId)
    self.currentReferenceIndex = currentReferenceIndex ~= 0 and currentReferenceIndex or nil
    local currentGrabPointIndex = streamReadInt8(streamId)
    self.currentGrabPointIndex = currentGrabPointIndex ~= 0 and currentGrabPointIndex or nil

    if self.hoseSystemReferences ~= nil then
        for id, reference in pairs(self.hoseSystemReferences) do -- Todo: table getn cause we only use the index
            self:toggleLock(id, streamReadBool(streamId), false, true)
            self:toggleManureFlow(id, streamReadBool(streamId), false, true)
        end
    end
end

function HoseSystemConnectorReference:writeStream(streamId, connection)
    streamWriteBool(streamId, self.fillObjectFound)
    streamWriteBool(streamId, self.fillFromFillVolume)
    streamWriteInt8(streamId, self.currentReferenceIndex ~= nil and self.currentReferenceIndex or 0)
    streamWriteInt8(streamId, self.currentGrabPointIndex ~= nil and self.currentGrabPointIndex or 0)

    if self.hoseSystemReferences ~= nil then
        for id, reference in pairs(self.hoseSystemReferences) do
            streamWriteBool(streamId, reference.isLocked)
            streamWriteBool(streamId, reference.flowOpened)
        end
    end
end

function HoseSystemConnectorReference:getSaveAttributesAndNodes(nodeIdent)
    local nodes = ""

    if self.hoseSystemReferences ~= nil then
        for id, reference in pairs(self.hoseSystemReferences) do
            if nodes ~= "" then
                nodes = nodes .. "\n"
            end

            local isLocked = reference.isLocked
            local flowOpened = reference.flowOpened

            nodes = nodes .. nodeIdent .. ('<reference id="%s" isLocked="%s" flowOpened="%s" />'):format(id, tostring(isLocked), tostring(flowOpened))
        end
    end

    return nil, nodes
end

function HoseSystemConnectorReference:mouseEvent(posX, posY, isDown, isUp, button)
end

function HoseSystemConnectorReference:keyEvent(unicode, sym, modifier, isDown)
end

function HoseSystemConnectorReference:update(dt)
    if HoseSystemPlayerInteractive:getIsPlayerValid() then
        local x, y, z = getWorldTranslation(g_currentMission.player.rootNode)
        local nearestDisSequence = 1.5

        self.inRageReferenceIndex = nil

        if self.hoseSystemReferences ~= nil then
            for referenceIndex, reference in pairs(self.hoseSystemReferences) do
                if reference.isUsed then
                    local gx, gy, gz = getWorldTranslation(reference.node)
                    local dist = Utils.vector3Length(x - gx, y - gy, z - gz)

                    if dist < nearestDisSequence then
                        self.inRageReferenceIndex = referenceIndex
                        nearestDisSequence = dist

                        break
                    end
                end
            end
        end

        if self.inRageReferenceIndex ~= nil then
            local reference = self.hoseSystemReferences[self.inRageReferenceIndex]

            if reference ~= nil and reference.hoseSystem ~= nil then
                if reference.lockAnimationName ~= nil and self.animations[reference.lockAnimationName] ~= nil and #self.animations[reference.lockAnimationName].parts > 0 then
                    local _, firstPartAnimation = next(self.animations[reference.lockAnimationName].parts, nil)

                    if firstPartAnimation.node ~= nil and g_i18n:hasText('TOGGLE_LOCK_HOSE') and g_i18n:hasText('LOCK_HOSE_STATE_LOCK') and g_i18n:hasText('LOCK_HOSE_STATE_UNLOCK') then
                        local state = self:getAnimationTime(reference.lockAnimationName) == 0

                        HoseSystemConnectorReference:renderInputTextOnNode(firstPartAnimation.node, string.format(g_i18n:getText('TOGGLE_LOCK_HOSE'), state and g_i18n:getText('LOCK_HOSE_STATE_LOCK') or g_i18n:getText('LOCK_HOSE_STATE_UNLOCK')), string.format(g_i18n:getText('action_mouseInteract'), string.lower(MouseHelper.getButtonName(Input.MOUSE_BUTTON_LEFT))))

                        if InputBinding.hasEvent(InputBinding.toggleLock) then
                            self:toggleLock(self.inRageReferenceIndex, state, false)
                        end
                    end
                end

                if reference.isLocked then
                    if reference.manureFlowAnimationName ~= nil and self.animations[reference.manureFlowAnimationName] ~= nil and #self.animations[reference.manureFlowAnimationName].parts > 0 then
                        local _, firstPartAnimation = next(self.animations[reference.manureFlowAnimationName].parts, nil)

                        if firstPartAnimation.node ~= nil and g_i18n:hasText('TOGGLE_MANUREFLOW_HOSE') and g_i18n:hasText('MANUREFLOW_HOSE_STATE_OPEN') and g_i18n:hasText('MANUREFLOW_HOSE_STATE_CLOSE') then
                            local state = self:getAnimationTime(reference.manureFlowAnimationName) == 0

                            HoseSystemConnectorReference:renderInputTextOnNode(firstPartAnimation.node, string.format(g_i18n:getText('TOGGLE_MANUREFLOW_HOSE'), state and g_i18n:getText('MANUREFLOW_HOSE_STATE_OPEN') or g_i18n:getText('MANUREFLOW_HOSE_STATE_CLOSE')), string.format(g_i18n:getText('action_mouseInteract'), string.lower(MouseHelper.getButtonName(Input.MOUSE_BUTTON_RIGHT))))

                            if InputBinding.hasEvent(InputBinding.toggleManureFlow) then
                                self:toggleManureFlow(self.inRageReferenceIndex, state, false)
                            end
                        end
                    end
                end
            end
        end
    end
end

function HoseSystemConnectorReference:updateTick(dt)
    if self.hasHoseSystemPumpMotor then
        self:getValidFillObject()

        if self.isServer then
            local isSucking = false

            if self:getFillMode() == self.pumpMotorFillMode then
                local reference = self.hoseSystemReferences[self.currentReferenceIndex]

                -- Todo: determine pump efficiency based on hose chain lenght -> moved feature to version 1.1
                --                if reference ~= nil then
                --                    local count = self.pumpFillEfficiency.maxTimeStatic / 10 * reference.hoseSystem.currentChainCount
                --                    self.pumpFillEfficiency.maxTime = reference.hoseSystem.currentChainCount > 0 and  self.pumpFillEfficiency.maxTimeStatic + count or self.pumpFillEfficiency.maxTimeStatic
                --                    print("CurrentChainCount= " .. reference.hoseSystem.currentChainCount .. "maxTime= " .. self.pumpFillEfficiency.maxTime .. 'What we do to it= ' .. count)
                --                end

                if self.pumpIsStarted then
                    if self.fillObject ~= nil then
                        if self.fillDirection == HoseSystemPumpMotor.IN then
                            local objectFillTypes = self.fillObject:getCurrentFillTypes() -- Note for objects this changed! self.fillIsObject and (fillObject.currentFillType == nil and fillObject.fillType or fillObject:getCurrentFillTypes()) or

                            -- isn't below dubble code?
                            if self.fillObject:getFreeCapacity() ~= self.fillObject:getCapacity() then
                                for _, objectFillType in pairs(objectFillTypes) do
                                    if self:allowUnitFillType(self.fillUnitIndex, objectFillType, false) then
                                        local objectFillLevel = self.fillObject:getFillLevel(objectFillType)
                                        local fillLevel = self:getUnitFillLevel(self.fillUnitIndex)

                                        if objectFillLevel > 0 and fillLevel < self:getUnitCapacity(self.fillUnitIndex) then -- self:getCapacity(FillUtil.FILLTYPE_LIQUIDMANURE) then
                                            if self.fillObject.checkPlaneY ~= nil then
                                                -- Ugh! edit this when done with the raycast stuff on the hose script
                                                local lastGrabPoint, _ = self:getLastGrabpointRecursively(reference.hoseSystem.grabPoints[HoseSystemConnectorReference:getFillableVehicle(self.currentGrabPointIndex, #reference.hoseSystem.grabPoints)])

                                                if not HoseSystem:getIsConnected(lastGrabPoint.state) then

                                                    local _, y, _ = getWorldTranslation(lastGrabPoint.raycastNode)
                                                    --
                                                    --                                                    isSucking, y = self.fillObject:checkPlaneY(y)
                                                    if reference.hoseSystem.lastRaycastDistance ~= 0 then
                                                        isSucking, _ = self.fillObject:checkPlaneY(y)
                                                    end
                                                else
                                                    isSucking = reference ~= nil
                                                end
                                            else
                                                isSucking = reference ~= nil
                                            end

                                            if self.pumpFillEfficiency.currentScale > 0 then
                                                local deltaFillLevel = math.min((self.pumpFillEfficiency.litersPerSecond * self.pumpFillEfficiency.currentScale) * 0.001 * dt, objectFillLevel)

                                                self:doPump(self.fillObject, objectFillType, deltaFillLevel, self.fillVolumeDischargeInfos[self.pumpMotor.dischargeInfoIndex])
                                            end
                                        else
                                            self:setPumpStarted(false)
                                            -- TODO: Send message to client that object is empty
                                        end
                                    else
                                        self:setPumpStarted(false)
                                        -- TODO: Send message to client that we dont allow fillType
                                    end
                                end
                            else
                                self:setPumpStarted(false)
                                -- TODO: Send message to client that object is empty
                            end
                        else
                            local fillType = self:getUnitLastValidFillType(self.fillUnitIndex)
                            local fillLevel = self:getFillLevel(fillType)

                            -- we checked that the fillObject accepts the fillType already
                            if fillLevel > 0 then
                                local deltaFillLevel = math.min((self.pumpFillEfficiency.litersPerSecond * self.pumpFillEfficiency.currentScale) * 0.001 * dt, fillLevel)

                                self:doPump(self.fillObject, fillType, deltaFillLevel, self.fillVolumeUnloadInfos[self.pumpMotor.unloadInfoIndex])
                            else
                                self:setPumpStarted(false)
                            end
                        end
                    end
                end

                if self.isSucking ~= isSucking then
                    self.isSucking = isSucking
                    g_server:broadcastEvent(IsSuckingEvent:new(self, self.isSucking))
                end

                if self.fillObjectFound then
                    if self.fillObject ~= nil and self.fillObject.checkPlaneY ~= nil then -- we are raycasting a fillplane
                        if self.fillObject.updateShaderPlane ~= nil then
                            self.fillObject:updateShaderPlane(self.pumpIsStarted, self.fillDirection, self.pumpFillEfficiency.litersPerSecond * self.pumpFillEfficiency.currentScale)
                        end
                    end
                end
            end
        end

        if self.isClient then
            if self.fillObjectHasPlane then
                if self.fillObjectFound or self.fillFromFillVolume then
                    self:updateLiquidManureHose(true)
                end
            else
                if not self.fillObjectFound and self.pumpIsStarted then
                    self:updateLiquidManureHose(false)
                end
            end
        end
    end
end

function HoseSystemConnectorReference:draw()
end

function HoseSystemConnectorReference:updateLiquidManureHose(allow)
    if self.currentGrabPointIndex ~= nil and self.currentReferenceIndex ~= nil then
        local reference = self.hoseSystemReferences[self.currentReferenceIndex]

        if reference ~= nil then
            local lastGrabPoint, lastHose = self:getLastGrabpointRecursively(reference.hoseSystem.grabPoints[HoseSystemConnectorReference:getFillableVehicle(self.currentGrabPointIndex, #reference.hoseSystem.grabPoints)], reference.hoseSystem)

            if lastGrabPoint ~= nil and lastHose ~= nil then
                local fillType = self:getUnitLastValidFillType(self.fillUnitIndex)

                lastHose:toggleEmptyingEffect(allow and self.pumpIsStarted and self.fillDirection == HoseSystemPumpMotor.OUT, lastGrabPoint.id > 1 and 1 or -1, lastGrabPoint.id, fillType)
                --if not reference.hoseSystem.grabPoints[self.currentGrabPointIndex].connectable then
                -- hoseSystem.emptyEffects.showEmptyEffects = self.pumpIsStarted and self.fillDirection == HoseSystemPumpMotor.OUT and self:getFillLevel(self.currentFillType) > 0
                --end
            end
        end
    end
end

function HoseSystemConnectorReference:getAllowedFillUnitIndex(object)
    if self.fillUnits == nil then
        return 0
    end

    for index, fillUnit in pairs(self.fillUnits) do
        if fillUnit.currentFillType ~= FillUtil.FILLTYPE_UNKNOWN then
            if object:allowFillType(fillUnit.currentFillType) then
                return index
            end
        else
            local fillTypes = self:getUnitFillTypes(index)

            for fillType, bool in pairs(fillTypes) do
                -- check if object accepts any of our fillTypes
                if object:allowFillType(fillType) then
                    return index
                end
            end
        end
    end

    return 0
end

function HoseSystemConnectorReference:getValidFillObject()
    self.currentReferenceIndex = nil
    self.currentGrabPointIndex = nil

    self.currentReferenceIndex, self.currentGrabPointIndex = self:getConnectedReference()

    if self.isServer then
        if self:getFillMode() == self.pumpMotorFillMode then
            -- clean tables/bools
            self.fillObject = nil
            self.fillObjectFound = false
            self.fillObjectHasPlane = false
            self.fillFromFillVolume = false
            self.fillUnitIndex = 0
        end

        if self.currentGrabPointIndex ~= nil and self.currentReferenceIndex ~= nil then
            local reference = self.hoseSystemReferences[self.currentReferenceIndex]

            if reference ~= nil then
                local lastGrabPoint, _ = self:getLastGrabpointRecursively(reference.hoseSystem.grabPoints[HoseSystemConnectorReference:getFillableVehicle(self.currentGrabPointIndex, #reference.hoseSystem.grabPoints)])

                if lastGrabPoint ~= nil then
                    -- check if the last grabPoint is connected
                    if HoseSystem:getIsConnected(lastGrabPoint.state) and not lastGrabPoint.connectable then
                        local lastReference = lastGrabPoint.connectorVehicle.hoseSystemReferences[lastGrabPoint.connectorRefId]
                        local lastVehicle = lastReference.isObject and lastGrabPoint.connectorVehicle.hoseSystemParent or lastGrabPoint.connectorVehicle

                        if lastReference ~= nil and lastVehicle ~= nil and lastVehicle.grabPoints == nil then -- checks if it's not a hose!
                            if lastReference.isUsed and lastReference.flowOpened and lastReference.isLocked then
                                if lastReference.isObject or SpecializationUtil.hasSpecialization(Fillable, lastVehicle.specializations) then
                                    -- check fill units to allow
                                    local allowedFillUnitIndex = self:getAllowedFillUnitIndex(lastVehicle)

                                    if allowedFillUnitIndex ~= 0 then
                                        if self:getFillMode() ~= self.pumpMotorFillMode then
                                            self:setFillMode(self.pumpMotorFillMode)
                                        end

                                        -- we can pump
                                        self.fillObjectFound = true
                                        self.fillObject = lastVehicle
                                        self.fillUnitIndex = allowedFillUnitIndex
                                    end
                                end
                            end
                        end
                    else
                        -- check what the lastGrabPoint has on it's raycast
                        local liquidManureHose = reference.hoseSystem

                        if liquidManureHose ~= nil then
                            if liquidManureHose.lastRaycastDistance ~= 0 then
                                if liquidManureHose.lastRaycastObject ~= nil then -- or how i called it
                                    local allowedFillUnitIndex = self:getAllowedFillUnitIndex(liquidManureHose.lastRaycastObject)

                                    -- Todo: change ray distance!
                                    if allowedFillUnitIndex ~= 0 then
                                        -- we have something else to pump with
                                        if self:getFillMode() ~= self.pumpMotorFillMode then
                                            self:setFillMode(self.pumpMotorFillMode)
                                        end

                                        -- we can pump
                                        self.fillObjectFound = true
                                        self.fillObject = liquidManureHose.lastRaycastObject
                                        self.fillUnitIndex = allowedFillUnitIndex

                                        if self.fillObject.checkPlaneY ~= nil then
                                            self.fillObjectHasPlane = true
                                        end
                                    end
                                end
                            end
                        end
                    end

                    --if fillObject ~= nil then
                    -- rename to modeHoseSystemSYSTEM

                    -- we kinda need to know what we fill and how.. this should prevent stupid code (like above in the updateTick .. fillIsHose etc)
                    -- self.fillThroughHoseSystem = true

                    -- self.fillObject = fillObject
                    -- self.fillFromFillVolume = fillFromFillVolume
                    -- self.fillUnitIndex = fillUnitIndex
                    -- share the fillUnitIndex?


                    -- lookup

                    -- self.fillIsTrailer = fillFromFillVolume
                    -- self.fillHasPlane = fillFromFillVolume
                    -- self.fillIsHose = fillFromFillVolume
                    -- sync fillFromFillVolume
                    --end

                    if self.lastFillObjectFound ~= self.fillObjectFound or self.lastFillFromFillVolume ~= self.fillFromFillVolume or self.lastFillUnitIndex ~= self.fillUnitIndex or self.lastFillObjectHasPlane ~= self.fillObjectHasPlane then
                        g_server:broadcastEvent(SendUpdateOnFillEvent:new(self, self.fillObjectFound, self.fillFromFillVolume, self.fillUnitIndex, self.fillObjectHasPlane))

                        self.lastFillUnitIndex = self.fillUnitIndex
                        self.lastFillObjectFound = self.fillObjectFound
                        self.lastFillFromFillVolume = self.fillFromFillVolume
                        self.lastFillObjectHasPlane = self.fillObjectHasPlane

                        -- self.lastFillIsObject = self.fillIsObject
                        -- self.lastFillIsTrailer = self.fillIsTrailer
                        -- self.lastFillIsHose = self.fillIsHose
                        -- self.lastFillHasPlane = self.fillHasPlane
                    end
                end
            end
        end
    end
end

function HoseSystemConnectorReference:getLastGrabpointRecursively(grabPoint, liquidManureHose)
    if grabPoint ~= nil then
        if grabPoint.connectorVehicle ~= nil then
            if grabPoint.connectorVehicle.grabPoints ~= nil then
                for i, connectorGrabPoint in pairs(grabPoint.connectorVehicle.grabPoints) do
                    if connectorGrabPoint ~= nil then
                        if connectorGrabPoint ~= grabPoint.connectorRef then
                            self:getLastGrabpointRecursively(connectorGrabPoint, grabPoint.connectorRef.hoseSystem)
                        end
                    end
                end
            end
        end

        return grabPoint, liquidManureHose
    end

    return nil, nil
end

function HoseSystemConnectorReference:getFillableVehicle(index, max)
    return index > 1 and 1 or max
end

-- TODO: but what if we have more ? Can whe pump with multiple hoses? Does that lower the pumpEfficiency?
function HoseSystemConnectorReference:getConnectedReference()
    if self.hoseSystemReferences ~= nil then
        for referenceIndex, reference in pairs(self.hoseSystemReferences) do
            if reference.isUsed and reference.flowOpened and reference.isLocked then
                if reference.hoseSystem ~= nil and reference.hoseSystem.grabPoints ~= nil then
                    for grabPointIndex, grabPoint in pairs(reference.hoseSystem.grabPoints) do
                        if HoseSystem:getIsConnected(grabPoint.state) then
                            if grabPoint.connectorVehicle == self then
                                return referenceIndex, grabPointIndex
                            end
                        end
                    end
                end
            end
        end
    end

    -- if self.hoseSystemReferences ~= nil and g_currentMission.liquidManureHoses ~= nil then
    -- for referenceIndex, reference in pairs(self.hoseSystemReferences) do
    -- if reference.isUsed and reference.flowOpened then
    -- for index, liquidManureHose in pairs(g_currentMission.liquidManureHoses) do
    -- if liquidManureHose.grabPoints ~= nil then
    -- for grabPointIndex, grabPoint in pairs(liquidManureHose.grabPoints) do
    -- if HoseSystem:getIsConnected(grabPoint.state) then
    -- if grabPoint.connectorVehicle == self then
    -- return referenceIndex, grabPointIndex, index
    -- end
    -- end
    -- end
    -- end
    -- end

    -- break
    -- end
    -- end
    -- end

    return nil, nil
end

function HoseSystemConnectorReference:toggleLock(index, state, force, noEventSend)
    HoseSystemReferenceLockEvent.sendEvent(self, index, state, force, noEventSend)

    local reference = self.hoseSystemReferences[index]

    if reference ~= nil then
        local dir = state and 1 or -1
        local shouldPlay = force or not self:getIsAnimationPlaying(reference.lockAnimationName)

        if shouldPlay then
            self:playAnimation(reference.lockAnimationName, dir, nil, true)
            reference.isLocked = state
        end
    end
end

function HoseSystemConnectorReference:toggleManureFlow(index, state, force, noEventSend)
    HoseSystemReferenceManureFlowEvent.sendEvent(self, index, state, force, noEventSend)

    local reference = self.hoseSystemReferences[index]

    if reference ~= nil then
        local dir = state and 1 or -1
        local shouldPlay = force or not self:getIsAnimationPlaying(reference.manureFlowAnimationName)

        if shouldPlay then
            self:playAnimation(reference.manureFlowAnimationName, dir, nil, true)
            reference.flowOpened = state
        end
    end
end

function HoseSystemConnectorReference:renderInputTextOnNode(node, actionText, inputBinding)
    if node ~= nil then
        local worldX, worldY, worldZ = localToWorld(node, 0, 0.1, 0)
        local x, y, z = project(worldX, worldY, worldZ)

        if x < 0.95 and y < 0.95 and z < 1 and x > 0.05 and y > 0.05 and z > 0 then
            setTextAlignment(RenderText.ALIGN_CENTER)
            setTextColor(1, 1, 1, 1)
            renderText(x, y + 0.01, 0.017, inputBinding)
            renderText(x, y - 0.02, 0.017, actionText)
            setTextAlignment(RenderText.ALIGN_LEFT)
        end
    end
end

function HoseSystemConnectorReference:setIsUsed(index, bool, noEventSend)
    if self.hoseSystemReferences ~= nil then
        HoseSystemReferenceIsUsedEvent.sendEvent(self, index, bool, noEventSend)

        local reference = self.hoseSystemReferences[index]

        if reference ~= nil then
            reference.isUsed = bool

            -- When detaching while on gameload we do need to sync the animations
            if not bool then
                if reference.lockAnimationName ~= nil then
                    if reference.isLocked then
                        self:toggleLock(index, not reference.isLocked, false)
                    end
                end

                if reference.manureFlowAnimationName ~= nil then
                    if reference.flowOpened then
                        self:toggleManureFlow(index, not reference.flowOpened, false)
                    end
                end
            end

            if reference.parkable then
                local dir = bool and 1 or -1

                if not self:getIsAnimationPlaying(reference.parkAnimationName) then
                    self:playAnimation(reference.parkAnimationName, dir, nil, true)
                end
            end
        end
    end
end

function HoseSystemConnectorReference:getIsOverloadingAllowed()
    return false
end

-- Events
HoseSystemReferenceIsUsedEvent = {}
HoseSystemReferenceIsUsedEvent_mt = Class(HoseSystemReferenceIsUsedEvent, Event)
InitEventClass(HoseSystemReferenceIsUsedEvent, 'HoseSystemReferenceIsUsedEvent')

function HoseSystemReferenceIsUsedEvent:emptyNew()
    local self = Event:new(HoseSystemReferenceIsUsedEvent_mt)
    self.className = 'HoseSystemReferenceIsUsedEvent'

    return self
end

function HoseSystemReferenceIsUsedEvent:new(hoseSystemReference, index, bool)
    local self = HoseSystemReferenceIsUsedEvent:emptyNew()
    self.hoseSystemReference = hoseSystemReference
    self.index = index
    self.bool = bool

    return self
end

function HoseSystemReferenceIsUsedEvent:writeStream(streamId, connection)
    streamWriteInt32(streamId, networkGetObjectId(self.hoseSystemReference))
    streamWriteInt32(streamId, self.index)
    streamWriteBool(streamId, self.bool)
end

function HoseSystemReferenceIsUsedEvent:readStream(streamId, connection)
    self.hoseSystemReference = networkGetObject(streamReadInt32(streamId))
    self.index = streamReadInt32(streamId)
    self.bool = streamReadBool(streamId)
    self:run(connection)
end

function HoseSystemReferenceIsUsedEvent:run(connection)
    self.hoseSystemReference:setIsUsed(self.index, self.bool, true)

    if not connection:getIsServer() then
        g_server:broadcastEvent(HoseSystemReferenceIsUsedEvent:new(self.hoseSystemReference, self.index, self.bool), nil, connection, self.hoseSystemReference)
    end
end

function HoseSystemReferenceIsUsedEvent.sendEvent(hoseSystemReference, index, bool, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(HoseSystemReferenceIsUsedEvent:new(hoseSystemReference, index, bool), nil, nil, hoseSystemReference)
        else
            g_client:getServerConnection():sendEvent(HoseSystemReferenceIsUsedEvent:new(hoseSystemReference, index, bool))
        end
    end
end

HoseSystemReferenceManureFlowEvent = {}
HoseSystemReferenceManureFlowEvent_mt = Class(HoseSystemReferenceManureFlowEvent, Event)
InitEventClass(HoseSystemReferenceManureFlowEvent, 'HoseSystemReferenceManureFlowEvent')

function HoseSystemReferenceManureFlowEvent:emptyNew()
    local self = Event:new(HoseSystemReferenceManureFlowEvent_mt)
    self.className = 'HoseSystemReferenceManureFlowEvent'

    return self
end

function HoseSystemReferenceManureFlowEvent:new(hoseSystemReference, index, state, force)
    local self = HoseSystemReferenceManureFlowEvent:emptyNew()
    self.hoseSystemReference = hoseSystemReference
    self.index = index
    self.state = state
    self.force = force

    return self
end

function HoseSystemReferenceManureFlowEvent:writeStream(streamId, connection)
    streamWriteInt32(streamId, networkGetObjectId(self.hoseSystemReference))
    streamWriteInt32(streamId, self.index)
    streamWriteBool(streamId, self.state)
    streamWriteBool(streamId, self.force)
end

function HoseSystemReferenceManureFlowEvent:readStream(streamId, connection)
    self.hoseSystemReference = networkGetObject(streamReadInt32(streamId))
    self.index = streamReadInt32(streamId)
    self.state = streamReadBool(streamId)
    self.force = streamReadBool(streamId)
    self:run(connection)
end

function HoseSystemReferenceManureFlowEvent:run(connection)
    self.hoseSystemReference:toggleManureFlow(self.index, self.state, self.force, true)

    if not connection:getIsServer() then
        g_server:broadcastEvent(HoseSystemReferenceManureFlowEvent:new(self.hoseSystemReference, self.index, self.state, self.force), nil, connection, self.hoseSystemReference)
    end
end

function HoseSystemReferenceManureFlowEvent.sendEvent(hoseSystemReference, index, state, force, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(HoseSystemReferenceManureFlowEvent:new(hoseSystemReference, index, state, force), nil, nil, hoseSystemReference)
        else
            g_client:getServerConnection():sendEvent(HoseSystemReferenceManureFlowEvent:new(hoseSystemReference, index, state, force))
        end
    end
end

HoseSystemReferenceLockEvent = {}
HoseSystemReferenceLockEvent_mt = Class(HoseSystemReferenceLockEvent, Event)
InitEventClass(HoseSystemReferenceLockEvent, 'HoseSystemReferenceLockEvent')

function HoseSystemReferenceLockEvent:emptyNew()
    local self = Event:new(HoseSystemReferenceLockEvent_mt)
    self.className = 'HoseSystemReferenceLockEvent'

    return self
end

function HoseSystemReferenceLockEvent:new(hoseSystemReference, index, state, force)
    local self = HoseSystemReferenceLockEvent:emptyNew()
    self.hoseSystemReference = hoseSystemReference
    self.index = index
    self.state = state
    self.force = force

    return self
end

function HoseSystemReferenceLockEvent:writeStream(streamId, connection)
    streamWriteInt32(streamId, networkGetObjectId(self.hoseSystemReference))
    streamWriteInt32(streamId, self.index)
    streamWriteBool(streamId, self.state)
    streamWriteBool(streamId, self.force)
end

function HoseSystemReferenceLockEvent:readStream(streamId, connection)
    self.hoseSystemReference = networkGetObject(streamReadInt32(streamId))
    self.index = streamReadInt32(streamId)
    self.state = streamReadBool(streamId)
    self.force = streamReadBool(streamId)
    self:run(connection)
end

function HoseSystemReferenceLockEvent:run(connection)
    self.hoseSystemReference:toggleLock(self.index, self.state, self.force, true)

    if not connection:getIsServer() then
        g_server:broadcastEvent(HoseSystemReferenceLockEvent:new(self.hoseSystemReference, self.index, self.state, self.force), nil, connection, self.hoseSystemReference)
    end
end

function HoseSystemReferenceLockEvent.sendEvent(hoseSystemReference, index, state, force, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(HoseSystemReferenceLockEvent:new(hoseSystemReference, index, state, force), nil, nil, hoseSystemReference)
        else
            g_client:getServerConnection():sendEvent(HoseSystemReferenceLockEvent:new(hoseSystemReference, index, state, force))
        end
    end
end