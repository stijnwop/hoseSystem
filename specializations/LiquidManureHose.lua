---
--
-- Author: Wopster and Xentro
-- Descripion:
-- Date: 26-7-2016
--
-- Liquid Manure Hose
--

LiquidManureHose = {
    debug = false,
    states = {
        attached = 0,
        detached = 1,
        connected = 2,
        parked = 3
    },
    animations = {
        connect = 'connect'
    },
    modDir = g_currentModDirectory,
    eventsDir = g_currentModDirectory .. "specializations/events"
}

source(string.format('%s/%s', LiquidManureHose.eventsDir, 'HoseSystemLoadFillableObjectAndReferenceEvent.lua'))
source(string.format('%s/%s', LiquidManureHose.eventsDir, 'LiquidManureHoseAttachEvent.lua'))
source(string.format('%s/%s', LiquidManureHose.eventsDir, 'LiquidManureHoseChainCountEvent.lua'))
source(string.format('%s/%s', LiquidManureHose.eventsDir, 'LiquidManureHoseDetachEvent.lua'))
source(string.format('%s/%s', LiquidManureHose.eventsDir, 'LiquidManureHoseDropEvent.lua'))
source(string.format('%s/%s', LiquidManureHose.eventsDir, 'LiquidManureHoseGrabEvent.lua'))
source(string.format('%s/%s', LiquidManureHose.eventsDir, 'LiquidManureHoseIsUsedEvent.lua'))
source(string.format('%s/%s', LiquidManureHose.eventsDir, 'LiquidManureHoseSetOwnerEvent.lua'))
source(string.format('%s/%s', LiquidManureHose.eventsDir, 'LiquidManureHoseToggleLockEvent.lua'))

---
-- @param specializations
--
function LiquidManureHose.prerequisitesPresent(specializations)
    return true
end

function LiquidManureHose:preLoad(savegame)
    self.loadObjectChangeValuesFromXML = Utils.overwrittenFunction(self.loadObjectChangeValuesFromXML, LiquidManureHose.loadObjectChangeValuesFromXML)
    self.setObjectChangeValues = Utils.overwrittenFunction(self.setObjectChangeValues, LiquidManureHose.setObjectChangeValues)
end

---
-- @param xmlFile
--
function LiquidManureHose:load(savegame)
    -- Todo: if there is no easier way.. move this to a loadmap script.
    -- MaterialUtil.registerMaterialType("hose")
    -- local i3dMaterials = Utils.loadSharedI3DFile("particleSystems/materialHolder.i3d", self.baseDirectory, false, true)

    -- print("does it exists? : " .. MaterialUtil.getMaterialType("hose"))

    -- local materialType = getChildAt(i3dMaterials, 0)
    -- MaterialUtil.registerMaterialType(getName(materialType))
    -- local fillType = getChildAt(materialType, 0)
    -- local materialHolder = getChildAt(fillType, 0)
    -- MaterialUtil.onCreateMaterial(_, materialHolder)
    --

    -- Init functions
    self.grab = LiquidManureHose.grab
    self.drop = LiquidManureHose.drop
    self.attach = LiquidManureHose.attach
    self.detach = LiquidManureHose.detach
    self.updateHose = LiquidManureHose.updateHose
    self.syncIsUsed = LiquidManureHose.syncIsUsed
    self.setIsUsed = LiquidManureHose.setIsUsed
    self.setOwner = LiquidManureHose.setOwner
    self.getOwner = LiquidManureHose.getOwner
    self.updateOwnerInputParts = LiquidManureHose.updateOwnerInputParts
    self.isPlayer = LiquidManureHose.isPlayer
    self.allowsDetach = LiquidManureHose.allowsDetach
    self.searchReferences = LiquidManureHose.searchReferences
    self.updateRestrictions = LiquidManureHose.updateRestrictions
    self.calculateChainRecursively = LiquidManureHose.calculateChainRecursively
    self.getLastGrabpointRecursively = LiquidManureHose.getLastGrabpointRecursively
    self.setChainCount = LiquidManureHose.setChainCount
    self.doPlayerDistanceCheck = LiquidManureHose.doPlayerDistanceCheck
    self.doReferenceDistanceCheck = LiquidManureHose.doReferenceDistanceCheck
    self.toggleLock = LiquidManureHose.toggleLock
    self.setEmptyEffect = LiquidManureHose.setEmptyEffect
    self.toggleEmptyingEffect = LiquidManureHose.toggleEmptyingEffect
    self.fillableObjectRaycastCallback = LiquidManureHose.fillableObjectRaycastCallback

    self.hardConnect = LiquidManureHose.hardConnect
    self.jointConnect = LiquidManureHose.jointConnect
    self.hardDisconnect = LiquidManureHose.hardDisconnect
    self.hardParkHose = LiquidManureHose.hardParkHose
    self.hardUnparkHose = LiquidManureHose.hardUnparkHose
    self.createConnectJoints = LiquidManureHose.createConnectJoints
    self.removeConnectOrParkJoints = LiquidManureHose.removeConnectOrParkJoints
    self.addToPhysicsFromReference = LiquidManureHose.addToPhysicsFromReference
    self.removeFromPhysicsFromReference = LiquidManureHose.removeFromPhysicsFromReference
    self.addToPhysicsPartly = LiquidManureHose.addToPhysicsPartly
    self.removeFromPhysicsPartly = LiquidManureHose.removeFromPhysicsPartly
    self.updateComponentJointMovement = LiquidManureHose.updateComponentJointMovement

    self.loadFillableObjectAndReference = LiquidManureHose.loadFillableObjectAndReference
    self.doNetworkQueue = LiquidManureHose.doNetworkQueue
    self.vehicleToMountHoseSystem = 0
    self.referenceIdToMountHoseSystem = 0
    self.vehicleIsExtendable = false
    self.queueNetworkObjects = false

    self.inRangeVehicle = nil
    self.inRangeReference = nil
    self.inRangeIsExtendable = false

    LiquidManureHose.loadHoseJoints(self, self.xmlFile)
    LiquidManureHose.loadHoseJointsSpline(self, self.xmlFile)
    LiquidManureHose.loadGrabPoints(self, self.xmlFile)
    LiquidManureHose.loadLiquidManureHose(self, self.xmlFile)
    LiquidManureHose.loadTargets(self, self.xmlFile)
    LiquidManureHose.loadParticleAndEffects(self, self.xmlFile)

    self.currentChainCount = 0
    self.playerRestrictionChainToLongShown = false
    self.walkingSpeed = 0
    self.runningFactor = 0

    -- g_mouseControlsHelp:addIconFilename(LiquidManureHose.modDir .. 'shared/hud/F6_1.dds')
    -- g_mouseControlsHelp:addIconFilename(LiquidManureHose.modDir .. 'shared/hud/F6_2.dds')

    -- self.xPos, self.yPos = getNormalizedScreenValues(30, 30)
    -- self.iconWidth, self.iconHeight = getNormalizedScreenValues(g_uiScale*50, g_uiScale*50)
    -- self.toolIconWidth, self.toolIconHeight = getNormalizedScreenValues(g_uiScale*70, g_uiScale*70)
    -- self.hudMouseHelpWidth, self.hudMouseHelpHeight = getNormalizedScreenValues(g_uiScale*530, g_uiScale*80)
    -- self.iconOffsetX, _ = getNormalizedScreenValues(g_uiScale*25, 0)
    -- self.iconSpacing, _ = getNormalizedScreenValues(g_uiScale*-10, 0)
    -- self.toolIconSpacing, _ = getNormalizedScreenValues(g_uiScale*5, 0)
    -- _, self.hudMouseHelpOffsetY = getNormalizedScreenValues(0, g_uiScale*10)
    -- self.iconOffsetY = (self.hudMouseHelpHeight - self.iconHeight)/2
    -- self.toolIconOffsetY = (self.hudMouseHelpHeight - self.toolIconHeight)/2
    -- self.hudMouseHelpContentOverlay = Overlay:new("hudMouseHelpContentOverlay2", g_baseUIFilename, self.xPos, self.yPos - self.hudMouseHelpHeight - self.hudMouseHelpOffsetY, self.hudMouseHelpWidth, self.hudMouseHelpHeight)

    -- self.hudMouseHelpContentOverlay:setUVs(getNormalizedUVs({
    -- 176,
    -- 457,
    -- 208,
    -- 489
    -- }))
    -- self.hudMouseHelpContentOverlay:setColor(1, 1, 1, 0.9)

    self:toggleLock(false, true)
    --self:playAnimation(LiquidManureHose.animations.connect, 1, nil, true) -- "open" lock
    -- print(LiquidManureHose:print_r(g_currentMission.vehicles))
end

--  This this does not work since we don't know if the attached vehicle exists yet..
function LiquidManureHose:postLoad(savegame)
    -- if savegame ~= nil and not savegame.resetVehicles then
    -- local i = 0

    -- while true do
    -- local key = string.format('%s.grabPoint(%d)', savegame.key, i)

    -- if not hasXMLProperty(savegame.xmlFile, key) then
    -- break
    -- end

    -- local grabPointId = getXMLInt(savegame.xmlFile, key .. '#id')
    -- local connectorVehicleId = getXMLInt(savegame.xmlFile, key .. '#connectorVehicleId')
    -- local isObject = getXMLBool(savegame.xmlFile, key .. '#isObject')
    -- local referenceId = getXMLInt(savegame.xmlFile, key .. '#referenceId')
    -- local isExtendable = getXMLBool(savegame.xmlFile, key .. '#extenable')

    -- if connectorVehicleId ~= nil and grabPointId ~= nil and referenceId ~= nil and isExtendable ~= nil then
    -- local connectorVehicle = not isObject and g_currentMission.vehicles[connectorVehicleId] or g_currentMission.onCreateLoadedObjects[connectorVehicleId]

    -- if connectorVehicle ~= nil then
    -- self:attach(grabPointId, nil, connectorVehicle, referenceId, isExtendable)
    -- else
    -- print('HoseSystem | postLoad - invalid connectorVehicle!')
    -- end
    -- end

    -- i = i + 1
    -- end
    -- end
end

---
-- @param self
-- @param xmlFile
--
function LiquidManureHose.loadHoseJoints(self, xmlFile)
    self.hoseJoints = {}

    local rootJoint = Utils.indexToObject(self.components, getXMLString(xmlFile, 'vehicle.hose.joints#rootJoint'))
    local jointCount = getXMLInt(xmlFile, 'vehicle.hose.joints#numJoints')

    if rootJoint ~= nil and jointCount ~= nil then
        for i = 1, jointCount do
            local count = table.getn(self.hoseJoints)

            -- local jointNode = count > 0 and getChildAt(rootJoint, count-1) or rootJoint
            local jointNode = count > 0 and getChildAt(self.hoseJoints[count].node, 0) or rootJoint

            if jointNode ~= nil then
                table.insert(self.hoseJoints, {
                    node = jointNode,
                    parent = getParent(jointNode)
                })
            end
        end
    end
end

---
-- @param self
-- @param xmlFile
--
function LiquidManureHose.loadHoseJointsSpline(self, xmlFile)
    self.jointSpline = {
        curveControllerTrans = Utils.getNoNil(Utils.getVectorNFromString(getXMLString(xmlFile, 'vehicle.hose#curveControllerTrans'), 3), { 0, 0, 7.5 }), -- set curve "controller" trans relative to grabPoints
        numJoints = table.getn(self.hoseJoints),
        endComponentId = table.getn(self.components),
        lastPosition = { { 0, 0, 0 }, { 0, 0, 0 } },
        firstRunUpdates = 0,
        firstNumRunUpdates = Utils.getNoNil(getXMLInt(xmlFile, 'vehicle.hose#firstNumRunUpdates'), 7),
        length = getXMLFloat(xmlFile, 'vehicle.size#length')
    }
end

---
-- @param self
-- @param xmlFile
--
function LiquidManureHose.loadGrabPoints(self, xmlFile)
    self.grabPoints = {}
    self.nodesToGrabPoints = {}
    self.playerInRangeTool = {}

    local i = 0

    while true do
        local key = string.format('vehicle.hose.grabPoints.grabPoint(%d)', i)

        if not hasXMLProperty(xmlFile, key) then
            break
        end

        local node = Utils.indexToObject(self.components, getXMLString(xmlFile, key .. '#node'))

        if node ~= nil then
            local entry = {
                id = i + 1, -- Table index
                node = node,
                nodeOrgTrans = { getRotation(node) },
                nodeOrgRot = { getRotation(node) },
                jointIndex = 0,
                centerJointIndex = 0,
                hasJointIndex = false, -- We don't sync the actual JointIndex it's server sided
                hasExtenableJointIndex = false, -- We don't sync the actual JointIndex it's server sided
                componentIndex = Utils.getNoNil(getXMLFloat(xmlFile, key .. '#componentIndex'), 0) + 1,
                componentChildNode = Utils.indexToObject(self.components, getXMLString(xmlFile, key .. '#componentChildNode')),
                connectable = Utils.getNoNil(getXMLBool(xmlFile, key .. '#connectable'), false),
                attachState = LiquidManureHose.states.detached,
                connectorRef = nil,
                connectorRefId = 0,
                connectorRefConnectable = false,
                connectorVehicle = nil,
                connectorVehicleId = 0,
                currentOwner = nil,
                isOwned = false
            }

            table.insert(self.playerInRangeTool, {
                node = node,
                playerDistance = 2
            })

            table.insert(self.grabPoints, entry)
            self.nodesToGrabPoints[entry.node] = entry
        else
            print('ManureHose error - Invalid grabPoint node, please check your XML!')
            break
        end

        i = i + 1 -- i++
    end
end

---
-- @param self
-- @param xmlFile
--
function LiquidManureHose.loadLiquidManureHose(self, xmlFile)
    self.supportedFillTypes = {}

    local fillTypeCategories = getXMLString(self.xmlFile, 'vehicle.hose#supportedFillTypeCategories')

    if fillTypeCategories ~= nil then
        local fillTypes = FillUtil.getFillTypeByCategoryName(fillTypeCategories, "Warning: '" .. self.configFileName .. "' has invalid fillTypeCategory '%s'.")

        if fillTypes ~= nil then
            for _, fillType in pairs(fillTypes) do
                self.supportedFillTypes[fillType] = true
            end
        end
    end

    self.originalComponentJoints = self.componentJoints
    local startTrans = { getWorldTranslation(self.components[1].node) }
    local endTrans = { getWorldTranslation(self.components[self.jointSpline.endComponentId].node) }

    if startTrans ~= nil and endTrans ~= nil then
        local filename = getXMLString(xmlFile, 'vehicle.hose.attachComponent#filename')

        if filename ~= nil then
            local linkNode = Utils.indexToObject(self.components, getXMLString(xmlFile, 'vehicle.hose.attachComponent#node'))
            local i3dNode = Utils.loadSharedI3DFile(filename, self.baseDirectory, false, false, false)

            if i3dNode ~= 0 then
                local rootNode = getChildAt(i3dNode, 0)
                link(linkNode, rootNode)
                delete(i3dNode)

                if rootNode ~= nil then
                    setTranslation(rootNode, 0, 0, 0)

                    local jointNode = getChildAt(rootNode, 0)
                    local rightHandNode = (getChildAt(jointNode, 0) ~= nil and getChildAt(jointNode, 0) or nil)
                    local leftHandNode = (getChildAt(jointNode, 1) ~= nil and getChildAt(jointNode, 1) or nil)

                    self.hose = {
                        node = rootNode,
                        filename = filename,
                        centerNode = linkNode,
                        jointNode = jointNode,
                        rightHandNode = rightHandNode,
                        leftHandNode = leftHandNode,
                        length = Utils.vector3Length(endTrans[1] - startTrans[1], endTrans[2] - startTrans[2], endTrans[3] - startTrans[3]),
                        parkStartTargetNode = 0,
                        parkCenterTargetNode = 0,
                        parkEndTargetNode = 0,
                        lastInRangePosition = { 0, 0, 0 },
                        rangeRestrictionMessageShown = false,
                        lastComponentJointGrabPoint = 0,
                        componentJoints = {}
                    }
                end
            end
        end
    end

    local i = 0

    while true do
        local base = string.format("vehicle.hose.componentJoints.joints(%d)", i)

        if not hasXMLProperty(xmlFile, base) then
            break
        end

        local grabPointId = getXMLInt(xmlFile, base .. '#grabPointIndice')

        if grabPointId ~= nil then
            self.hose.componentJoints[grabPointId] = {}

            local j = 0

            while true do
                local key = string.format("%s.joint(%d)", base, j)

                if not hasXMLProperty(xmlFile, key) then
                    break
                end

                local firstComponent = getXMLInt(xmlFile, key .. '#component1')
                local secondComponent = getXMLInt(xmlFile, key .. '#component2')
                local jointIndexStr = getXMLString(xmlFile, key .. '#index')

                if firstComponent == nil or secondComponent == nil or jointIndexStr == nil then
                    break
                end

                local jointNode = Utils.indexToObject(self.components, jointIndexStr)

                if jointNode ~= nil and jointNode ~= 0 then
                    local entry = {}

                    if self:loadComponentJointFromXML(entry, xmlFile, key, j, jointNode, firstComponent, secondComponent) then
                        table.insert(self.hose.componentJoints[grabPointId], entry)
                    end
                end

                j = j + 1
            end
        end

        i = i + 1
    end

    -- print(LiquidManureHose:print_r(self.hose.componentJoints))

    if self.jointSpline.numJoints > 0 then -- we should confirm that 1 or 2 attacherJoints are in place too.
        -- store "hose" in an global table for faster distance check later on
        if g_currentMission.liquidManureHoses == nil then
            g_currentMission.liquidManureHoses = {}
        end

        table.insert(g_currentMission.liquidManureHoses, self)
    end
end

function LiquidManureHose.loadTargets(self, xmlFile)
    self.targets = {}

    local i = 0

    while true do
        local key = string.format('vehicle.hose.targets.target(%d)', i)

        if not hasXMLProperty(xmlFile, key) then
            break
        end

        local ikName = getXMLString(xmlFile, key .. "#ikChainName")
        local target = Utils.indexToObject(self.components, getXMLString(xmlFile, key .. "#target"))
        local x, y, z = Utils.getVectorFromString(Utils.getNoNil(getXMLString(xmlFile, key .. "#targetOffset"), "0 0 0"))
        local rotationNodes = {}
        local j = 0

        while true do
            local nodeKey = key .. string.format(".rotationNode(%d)", j)

            if not hasXMLProperty(xmlFile, nodeKey) then
                break
            end

            local id = getXMLInt(xmlFile, nodeKey .. "#id")

            if id ~= nil then
                local rotation = Utils.getRadiansFromString(Utils.getNoNil(getXMLString(xmlFile, nodeKey .. "#rotation"), "0 0 0"), 3)
                table.insert(rotationNodes, { id = id, rotation = rotation })
            end

            j = j + 1
        end

        self.targets[ikName] = {
            targetNode = target,
            targetOffset = { x, y, z },
            rotationNodes = rotationNodes
        }

        i = i + 1
    end
end

function LiquidManureHose.loadParticleAndEffects(self, xmlFile)
    if self.isClient then
        self.hoseParticleSystems = {}
        self.hoseEffects = {}

        local i = 0

        while true do
            local key = string.format("vehicle.hose.particles(%d)", i)
            local particleType = getXMLString(xmlFile, key .. "#type")

            if particleType == nil then
                break
            end

            local fillType = Fillable.fillTypeNameToInt[particleType]
            if fillType ~= nil then
                local entry = {}
                local particleNode = Utils.loadParticleSystem(xmlFile, entry, key, self.components, false, "particleSystems/trailerDischargeParticleWeizen.i3d", self.baseDirectory)

                self.hoseParticleSystems[fillType] = entry
            end

            i = i + 1
        end

        -- fixed fs17
        -- local fillTypeNames = getXMLString(xmlFile, "vehicle.hose.effect#fillTypes")
        -- if fillTypeNames ~= nil then
        -- local fillTypes = FillUtil.getFillTypesByNames(fillTypeNames, "Warning: '"..self.configFileName.. "' has invalid fillType '%s'.")

        -- if fillTypes ~= nil then
        -- for _, fillType in pairs(fillTypes) do
        -- self.hoseEffects.fillTypes[fillType] = true
        -- end
        -- end
        -- end

        -- we don't have todo above when switching fillTypes
        --

        local effects = EffectManager:loadEffect(xmlFile, "vehicle.hose.effect", self.components, self)

        if effects ~= nil then
            local effect = {
                effects = effects,
                isActive = false
            }

            self.hoseEffects = effect
        end

        local effectNode = Utils.indexToObject(self.components, getXMLString(xmlFile, "vehicle.hose.emptyingSound#node"))
        if effectNode ~= nil then
            self.emptyingSound = SoundUtil.loadSample(xmlFile, {}, "vehicle.hose.emptyingSound", "$data/maps/sounds/refuel.wav", self.baseDirectory, effectNode)
        end
    end
end

function LiquidManureHose:preDelete()
    if self.isServer then
        if self.grabPoints ~= nil then
            for index, grabPoint in pairs(self.grabPoints) do
                if LiquidManureHose:isAttached(grabPoint.attachState) then
                    if grabPoint.isOwned and self:getOwner(index) ~= nil then
                        self:drop(index, self:getOwner(index), nil, true)
                    end
                elseif LiquidManureHose:isConnected(grabPoint.attachState) then
                    if grabPoint.connectorVehicle ~= nil and grabPoint.connectorRef ~= nil and grabPoint.connectorRef.isUsed then
                        self:detach(index, nil, grabPoint.connectorVehicle, grabPoint.connectorRef.id, grabPoint.connectorRef.connectable ~= nil and grabPoint.connectorRef.connectable, true)
                    end
                end
            end
        end
    end
end

function LiquidManureHose:delete()
    if g_currentMission.liquidManureHoses ~= nil then
        for index = 1, table.getn(g_currentMission.liquidManureHoses) do
            if g_currentMission.liquidManureHoses[index] == self then
                table.remove(g_currentMission.liquidManureHoses, index)
                break
            end
        end
    end

    if self.hose ~= nil and self.hose.node ~= nil and self.hose.centerNode ~= nil then
        Utils.releaseSharedI3DFile(self.hose.filename, self.baseDirectory, true)

        delete(self.hose.node)
        delete(self.hose.centerNode)
    end

    -- Delete effects
    if self.isClient then
        if self.hoseEffects ~= nil and self.hoseEffects.effect ~= nil then
            EffectManager:deleteEffects(self.hoseEffects.effect)
        end

        SoundUtil.deleteSample(self.emptyingSound)
    end

    -- Already been done on pre?
    -- if self.grabPoints ~= nil then
    -- for index, grabPoint in pairs(self.grabPoints) do
    -- if grabPoint.isOwned and self:getOwner(index) ~= nil then
    -- self:drop(index, self:getOwner(index))
    -- elseif grabPoint.isUsed and grabPoint.connectorRef ~= nil and grabPoint.connectorVehicle ~= nil then
    -- self:detach(index)
    -- end
    -- end
    -- end
end

function LiquidManureHose:writeStream(streamId, connection)
    -- if not connection:getIsServer() then
    streamWriteInt8(streamId, table.getn(self.grabPoints))

    for index = 1, table.getn(self.grabPoints) do
        local grabPoint = self.grabPoints[index]

        if grabPoint ~= nil then
            streamWriteInt8(streamId, grabPoint.attachState)

            -- if LiquidManureHose:isConnected(grabPoint.attachState) then
            -- writeNetworkNodeObject(streamId, grabPoint.connectorVehicle)
            writeNetworkNodeObjectId(streamId, networkGetObjectId(grabPoint.connectorVehicle))
            streamWriteInt32(streamId, grabPoint.connectorRef ~= nil and grabPoint.connectorRef.id or 0)
            -- end

            streamWriteBool(streamId, grabPoint.connectorRef ~= nil and grabPoint.connectorRef.connectable or false)
            streamWriteBool(streamId, grabPoint.isOwned)

            writeNetworkNodeObject(streamId, grabPoint.currentOwner)
            -- if grabPoint.isOwned then
            -- end

            streamWriteBool(streamId, grabPoint.hasJointIndex)
            streamWriteBool(streamId, grabPoint.hasExtenableJointIndex)
        end
    end

    streamWriteInt32(streamId, self.currentChainCount)
    writeNetworkNodeObjectId(streamId, self.vehicleToMountHoseSystem)
    streamWriteInt32(streamId, self.referenceIdToMountHoseSystem)
    streamWriteBool(streamId, self.vehicleIsExtendable)
    -- end
end

function LiquidManureHose:readStream(streamId, connection)
    -- if connection:getIsServer() then
    local numGrabPoints = streamReadInt8(streamId)

    for index = 1, numGrabPoints do
        local grabPoint = self.grabPoints[index]

        if grabPoint ~= nil then
            grabPoint.attachState = streamReadInt8(streamId)
            -- grabPoint.connectorVehicle = readNetworkNodeObject(streamId)
            grabPoint.connectorVehicleId = readNetworkNodeObjectId(streamId)

            local referenceId = streamReadInt32(streamId)
            -- print('connectorVehicle readStream = ' .. tostring(grabPoint.connectorVehicle))
            -- print('referenceId readStream = ' .. tostring(referenceId))
            -- if referenceId ~= 0 and grabPoint.connectorVehicle ~= nil then
            -- grabPoint.connectorRef = grabPoint.connectable and grabPoint.connectorVehicle.grabPoints[referenceId] or grabPoint.connectorVehicle.hoseSystemReferences[referenceId]
            -- else
            grabPoint.connectorRefId = referenceId
            -- end

            grabPoint.connectorRefConnectable = streamReadBool(streamId)

            if LiquidManureHose:isConnected(grabPoint.attachState) then
                if grabPoint.connectable then
                    self:toggleLock(true, true) -- close lock
                    --self:playAnimation(LiquidManureHose.animations.connect, -1, nil, true) -- close lock
                end
            end

            local isOwned = streamReadBool(streamId)
            local player = readNetworkNodeObject(streamId)
            print('player readStream = ' .. tostring(player))
            self:setOwner(index, isOwned, player, true)

            grabPoint.hasJointIndex = streamReadBool(streamId)
            grabPoint.hasExtenableJointIndex = streamReadBool(streamId)

            self:syncIsUsed(index, LiquidManureHose:isConnected(grabPoint.attachState), grabPoint.hasExtenableJointIndex, true)
        end
    end

    local count = streamReadInt32(streamId)
    self:setChainCount(count, true)

    local vehicleToMountHoseSystem = readNetworkNodeObjectId(streamId)
    local referenceIdToMountHoseSystem = streamReadInt32(streamId)
    local vehicleIsExtendable = streamReadBool(streamId)
    self:loadFillableObjectAndReference(vehicleToMountHoseSystem, referenceIdToMountHoseSystem, vehicleIsExtendable, true)

    self.queueNetworkObjects = true
    -- end
end

function LiquidManureHose:doNetworkQueue()
    if self.grabPoints ~= nil then
        for index, grabPoint in pairs(self.grabPoints) do
            local vehicle = networkGetObject(grabPoint.connectorVehicleId)

            if vehicle ~= nil and type(grabPoint.connectorRefId) == 'number' then
                grabPoint.connectorVehicle = vehicle
                grabPoint.connectorRef = grabPoint.connectorRefConnectable and vehicle.grabPoints[grabPoint.connectorRefId] or vehicle.hoseSystemReferences[grabPoint.connectorRefId]
                grabPoint.connectorVehicleId = 0
                grabPoint.connectorRefId = 0

                self:syncIsUsed(index, LiquidManureHose:isConnected(grabPoint.attachState), grabPoint.hasExtenableJointIndex, true)
            end
        end
    end

    self.queueNetworkObjects = false
end

function LiquidManureHose:getSaveAttributesAndNodes(nodeIdent)
    local nodes = ""

    if self.grabPoints ~= nil then
        for index, grabPoint in pairs(self.grabPoints) do
            if LiquidManureHose:isConnected(grabPoint.attachState) then
                if grabPoint.connectorVehicle ~= nil and grabPoint.connectorRef ~= nil then
                    if nodes ~= "" then
                        nodes = nodes .. "\n"
                    end

                    local connectorVehicleId = 0
                    local isObject = grabPoint.connectorRef.isObject

                    if not isObject then
                        for i = 0, table.getn(g_currentMission.vehicles), 1 do
                            if g_currentMission.vehicles[i] == grabPoint.connectorVehicle then
                                connectorVehicleId = i
                                break
                            end
                        end
                    else
                        -- print(LiquidManureHose:print_r(grabPoint.connectorVehicle))
                        -- for i, object in pairs(g_currentMission.onCreateLoadedObjects) do
                        -- if g_currentMission.onCreateLoadedObjects[i] == grabPoint.connectorVehicle then
                        -- connectorVehicleId = i
                        -- break
                        -- end
                        -- end
                    end

                    print('The vehicle id is = ' .. connectorVehicleId)

                    local connectorRefId = grabPoint.connectorRef.id
                    local isExtendable = grabPoint.connectable ~= nil and grabPoint.connectable

                    if not grabPoint.connectorRef.connectable then
                        nodes = nodes .. nodeIdent .. '<grabPoint id="' .. index .. '" connectorVehicleId="' .. connectorVehicleId .. '" referenceId="' .. connectorRefId .. '" isObject="' .. tostring(isObject) .. '" extenable="' .. tostring(isExtendable) .. '" />'
                    end

                    if grabPoint.connectorRef.parkable then -- We are saving a parked hose.. we don't need to save the other references.
                        break
                    end
                end
            end
        end
    end

    return nil, nodes
end

function LiquidManureHose:mouseEvent(posX, posY, isDown, isUp, button)
end

function LiquidManureHose:keyEvent(unicode, sym, modifier, isDown)
end

function LiquidManureHose:update(dt)
    if self.queueNetworkObjects then
        self:doNetworkQueue()
    end

    if self.isClient then
        if self.jointSpline.firstRunUpdates < self.jointSpline.firstNumRunUpdates then
            self.jointSpline.firstRunUpdates = self.jointSpline.firstRunUpdates + 1
            self:updateHose(true) -- force firstNumRunUpdates frame updates to give hose time to move.

            if not self.isAddedToPhysics then -- parked hose update
                if self.hose.parkStartTargetNode ~= 0 and self.hose.parkCenterTargetNode ~= 0 and self.hose.parkEndTargetNode ~= 0 then
                    --print('we update')
                    -- local parkNodes = {self.hose.parkStartTargetNode, self.hose.parkCenterTargetNode, self.hose.parkEndTargetNode}
                    -- for i, component in pairs(self.components) do
                    -- local nodeTrans = {getWorldTranslation(parkNodes[i])}
                    -- local trans = {getWorldTranslation(component.node)}

                    -- if nodeTrans[1] ~= trans[1] or nodeTrans[2] ~= trans[2] or nodeTrans[3] ~= trans[3] then
                    -- print('update component')
                    -- --setWorldTranslation(parkNodes[i], unpack(nodeTrans)) -- what if we update the node on it's own translation?

                    -- local parkNode = parkNodes[i]
                    -- local x,y,z = localToWorld(component.node, nodeTrans[1], nodeTrans[2], nodeTrans[3]);
                    -- local upX,upY,upZ = localDirectionToWorld(component.node, 0, 0, 1);
                    -- local dirX,dirY,dirZ = localDirectionToWorld(component.node, 0, 1, 0);
                    -- Utils.setWorldTranslation(component.node, x,y,z);
                    -- Utils.setWorldDirection(component.node, dirX,dirY,dirZ, upX,upY,upZ);
                    -- end
                    -- end
                end
            end
        else
            self:updateHose(false)
        end

        if self.isPlayer() then
            if g_currentMission.player.closestTool ~= nil and g_currentMission.player.closestTool == self then
                local index = g_currentMission.player.closestToolLocationId
                local grabPoint = self.grabPoints[index]

                if grabPoint ~= nil then
                    if LiquidManureHose:isDetached(grabPoint.attachState) then
                        -- if g_i18n:hasText('GRABHOSE') then
                        -- g_currentMission:addHelpButtonText(g_i18n:getText('GRABHOSE'), InputBinding.ATTACH_HOSE)
                        -- end

                        if grabPoint.node ~= nil and g_i18n:hasText('GRABHOSE') then
                            LiquidManureHose:renderTextOnNode(grabPoint.node, g_i18n:getText('GRABHOSE'), string.format(g_i18n:getText('MOUSE_INTERACT'), string.lower(MouseHelper.getButtonName(Input.MOUSE_BUTTON_LEFT))))
                        end

                        --g_mouseControlsHelp.hudMouseHelpContentOverlay:setPosition(nil, g_mouseControlsHelp.yPos)
                        --g_mouseControlsHelp.hudMouseHelpContentOverlay:render()

                        g_currentMission:enableHudIcon('attach', 1)
                        --g_mouseControlsHelp:setMouseButton(MouseControlsHelp.BUTTON_LEFT)
                        --g_mouseControlsHelp:setIconFilename(LiquidManureHose.modDir .. 'shared/hud/F6_1.dds', LiquidManureHose.modDir .. 'shared/hud/F6_2.dds')
                        --g_currentMission:setShowHasMouseButtonInput(true)

                        if InputBinding.hasEvent(InputBinding.ATTACH_HOSE) then
                            self:grab(index, g_currentMission.player)
                        end
                    elseif LiquidManureHose:isConnected(grabPoint.attachState) or LiquidManureHose:isParked(grabPoint.attachState) then
                        if self:allowsDetach(index) or grabPoint.connectorRef.connectable then
                            if grabPoint.hasJointIndex or grabPoint.connectorRef.hasJointIndex then -- Put the index through it with the jointIndex!
                                -- if g_i18n:hasText('DETACHHOSE') then
                                -- g_currentMission:addHelpButtonText(g_i18n:getText('DETACHHOSE'), InputBinding.DETACH_HOSE)
                                -- end

                                if grabPoint.node ~= nil and grabPoint.connectorRef ~= nil and not grabPoint.connectorRef.isLocked and g_i18n:hasText('DETACHHOSE') then
                                    LiquidManureHose:renderTextOnNode(grabPoint.node, g_i18n:getText('DETACHHOSE'), string.format(g_i18n:getText('MOUSE_INTERACT'), string.lower(MouseHelper.getButtonName(Input.MOUSE_BUTTON_RIGHT))))
                                end

                                if InputBinding.hasEvent(InputBinding.DETACH_HOSE) then
                                    --if self:allowsDetach(index) then
                                    local reference = grabPoint.connectorRef
                                    local extenable = not reference.parkable and ((reference.connectable ~= nil and reference.connectable) or (grabPoint.connectable ~= nil and grabPoint.connectable))

                                    if reference.hasJointIndex then
                                        grabPoint.connectorVehicle:detach(reference.id, nil, self, index, extenable)
                                    else
                                        self:detach(index, nil, grabPoint.connectorVehicle, reference.id, extenable)
                                    end

                                    if not grabPoint.connectable and (reference ~= nil and not reference.connectable) and reference.parkable then
                                        -- print('we should grab')
                                        -- TODO: Oke this fucks up the
                                        -- self:grab(index, g_currentMission.player)
                                    end

                                    --else
                                    --g_currentMission:showBlinkingWarning('Manure hose is locked message here!', 1000)
                                    --end
                                end
                            end
                        end
                    end

                    -- Todo: setShowHasMouseButtonInput is gone.. do something with below
                    -- if control.controlAxisIcon ~= nil then
                    -- g_currentMission:addHelpAxis(control.controlActionIndex, control.controlAxisIcon)
                    -- end
                    -- g_currentMission:setShowHasMouseButtonInput(true)
                end
            elseif g_currentMission.player.activeTool ~= nil and g_currentMission.player.activeTool == self then
                local index = g_currentMission.player.activeToolLocationId
                local grabPoint = self.grabPoints[index]

                if grabPoint ~= nil then
                    if grabPoint.isOwned then
                        if LiquidManureHose:isAttached(grabPoint.attachState) then
                            -- g_currentMission.player:setIKDirty()

                            if g_i18n:hasText('DROPHOSE') then
                                g_currentMission:addExtraPrintText(string.format(g_i18n:getText('MOUSE_INTERACT'), string.lower(MouseHelper.getButtonName(Input.MOUSE_BUTTON_RIGHT))) .. ' ' .. g_i18n:getText('DROPHOSE'))
                            end

                            -- if grabPoint.node ~= nil and g_i18n:hasText('DROPHOSE') then
                            -- LiquidManureHose:renderTextOnNode(grabPoint.node, g_i18n:getText('DROPHOSE'), string.format(g_i18n:getText('MOUSE_INTERACT'), string.lower(MouseHelper.getButtonName(Input.MOUSE_BUTTON_RIGHT))))
                            -- end

                            if InputBinding.hasEvent(InputBinding.DETACH_HOSE) then
                                self:drop(index, g_currentMission.player)
                            end

                            -- self:searchReferences(grabPoint)
                            -- self:updateRestrictions(grabPoint, dt)
                            if self.vehicleToMountHoseSystem ~= nil and self.referenceIdToMountHoseSystem ~= nil then
                                local object = networkGetObject(self.vehicleToMountHoseSystem)

                                if object ~= nil then
                                    local reference
                                    if object.hoseSystemReferences ~= nil then
                                        reference = object.hoseSystemReferences[self.referenceIdToMountHoseSystem]
                                    end

                                    local node = grabPoint.node
                                    if reference ~= nil then
                                        node = reference.parkable and grabPoint.node or reference.node
                                    end

                                    -- if g_i18n:hasText('ATTACHHOSE') then
                                    -- g_currentMission:addHelpButtonText(g_i18n:getText('ATTACHHOSE'), InputBinding.ATTACH_HOSE)
                                    -- end

                                    if node ~= nil and g_i18n:hasText('ATTACHHOSE') then
                                        LiquidManureHose:renderTextOnNode(node, g_i18n:getText('ATTACHHOSE'), string.format(g_i18n:getText('MOUSE_INTERACT'), string.lower(MouseHelper.getButtonName(Input.MOUSE_BUTTON_LEFT))))
                                    end

                                    g_currentMission:enableHudIcon('attach', 1)
                                    --g_currentMission:setShowHasMouseButtonInput(true)

                                    if InputBinding.hasEvent(InputBinding.ATTACH_HOSE) then
                                        -- print(LiquidManureHose:print_r(self.fillableObject))
                                        self:attach(index, nil, object, self.referenceIdToMountHoseSystem, self.vehicleIsExtendable)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- Restrictions is server and client sided?
    self:updateRestrictions(dt)

    if self.isServer then
        if self.grabPoints ~= nil then
            for index, grabPoint in pairs(self.grabPoints) do
                if grabPoint.isOwned and LiquidManureHose:isAttached(grabPoint.attachState) then
                    self:searchReferences(grabPoint)
                end
            end
        end
    end
end

function LiquidManureHose:loadFillableObjectAndReference(fillableObject, referenceId, isExtendable, noEventSend)
    self.vehicleToMountHoseSystem = fillableObject
    self.referenceIdToMountHoseSystem = referenceId
    self.vehicleIsExtendable = isExtendable

    if self.isServer then
        if self.vehicleToMountHoseSystem ~= self.lastVehicleToMountHoseSystem or self.referenceIdToMountHoseSystem ~= self.lastReferenceIdToMountHoseSystem or self.vehicleIsExtendable ~= self.lastVehicleIsExtendable then
            if noEventSend == nil or not noEventSend then
                g_server:broadcastEvent(HoseSystemLoadFillableObjectAndReferenceEvent:new(self, self.vehicleToMountHoseSystem, self.referenceIdToMountHoseSystem, self.vehicleIsExtendable))
            end

            -- print('Send event')
            -- print('vehicleToMountHoseSystem ' .. tostring(self.vehicleToMountHoseSystem))
            -- print('referenceIdToMountHoseSystem ' .. tostring(self.referenceIdToMountHoseSystem))
            -- print('vehicleIsExtendable ' .. tostring(self.vehicleIsExtendable))

            self.lastVehicleToMountHoseSystem = self.vehicleToMountHoseSystem
            self.lastReferenceIdToMountHoseSystem = self.referenceIdToMountHoseSystem
            self.lastVehicleIsExtendable = self.vehicleIsExtendable
        end
    end
end

---
-- @param grabPoint
--
function LiquidManureHose:searchReferences(grabPoint)
    -- do this per side? This will do for now.
    self:loadFillableObjectAndReference(0, 0, false)

    local x, y, z = getWorldTranslation(grabPoint.node)
    local nearestDisSequence = 0.6 * 0.6

    if g_currentMission.hoseSystemReferences ~= nil then
        for _, liquidManureHoseReference in pairs(g_currentMission.hoseSystemReferences) do
            -- Hose references
            if liquidManureHoseReference ~= nil then
                for i, reference in pairs(liquidManureHoseReference.hoseSystemReferences) do
                    if not reference.isUsed then
                        local inRange = false

                        local rx, ry, rz = getWorldTranslation(reference.node)
                        local dist = Utils.vector2LengthSq(x - rx, z - rz)

                        if dist < nearestDisSequence then
                            local vehicleDistance = math.abs(y - ry)

                            if vehicleDistance < 1.3 then
                                local cosAngle = LiquidManureHose:calculateCosAngle(reference.node, grabPoint.node)

                                if not reference.parkable then
                                    if not grabPoint.connectable then
                                        if cosAngle > math.rad(-80) and cosAngle < math.rad(80) then -- > -10° < 10° -- > cosAngle > -0.17365 and cosAngle < 0.17365 then -- > -80° < 80°
                                            inRange = true
                                        end
                                    end
                                else
                                    inRange = true
                                end
                            end
                        end

                        if reference.parkable then
                            local rmx, rmy, rmz = getWorldTranslation(reference.maxParkLengthNode)
                            local distance = Utils.vector2LengthSq(x - rmx, z - rmz)

                            --print(distance)
                            if distance < nearestDisSequence then
                                --print(distance)
                                local referenceDistance = math.abs(y - rmy)

                                if referenceDistance < 1.3 then
                                    --print(referenceDistance)
                                    inRange = true
                                end
                            end
                        end

                        if inRange then
                            -- self.inRangeVehicle = reference.isObject and g_currentMission:getNodeObject(liquidManureHoseReference.nodeId) or liquidManureHoseReference -- getNodeObject does work in MP?
                            -- self.inRangeReference = reference.id
                            -- self.inRangeIsExtendable = false

                            -- self:loadFillableObjectAndReference(reference.isObject and g_currentMission:getNodeObject(liquidManureHoseReference.nodeId) or liquidManureHoseReference, reference.id, false)
                            -- local object = reference.isObject and g_currentMission:getNodeObject(liquidManureHoseReference.nodeId) or liquidManureHoseReference
                            local object = reference.isObject and liquidManureHoseReference.fillLevelObject or liquidManureHoseReference
                            self:loadFillableObjectAndReference(networkGetObjectId(object), reference.id, false)
                            break
                        end
                    end
                end
            end
        end
    end

    if g_currentMission.liquidManureHoses ~= nil then
        for _, g_liquidManureHose in pairs(g_currentMission.liquidManureHoses) do
            if g_liquidManureHose ~= self and g_liquidManureHose.grabPoints ~= nil then
                for i, reference in pairs(g_liquidManureHose.grabPoints) do
                    if grabPoint.connectable or reference.connectable then
                        if LiquidManureHose:isDetached(reference.attachState) then
                            local rx, ry, rz = getWorldTranslation(reference.node)
                            local dist = Utils.vector2LengthSq(x - rx, z - rz)

                            if dist < nearestDisSequence then
                                local vehicleDistance = math.abs(y - ry)

                                if vehicleDistance < 1.3 then
                                    if LiquidManureHose:canExtendHoseSytem(reference.id > 1, reference.node, grabPoint.node) then
                                        self:loadFillableObjectAndReference(networkGetObjectId(g_liquidManureHose), reference.id, true)
                                        -- self.inRangeVehicle = g_liquidManureHose
                                        -- self.inRangeReference = reference.id
                                        -- self.inRangeIsExtendable = true
                                        break
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

function LiquidManureHose:updateRestrictions(dt)
    -- So what if we chained up more then 2 hoses? The player should not be able to run.. or is he a super human afterall?
    -- If we have more then 3? Can we still move that fucking thing?

    -- When 4 lock!
    -- self.player.walkingIsLocked = false

    -- When the hose is attached to a reference we shouldn't be able to walk further then the hose length.. reset the location when out off range..

    -- Note: the variable gp should be the current hose we are handling or a looped variable from the self.grabPoints table.. !?

    --[[
        Do not check that we are player but loop and look for if a grapPoint has a owner.. then do the distance check!
        This should work on the server to!

        for ... self.grabPoints do
            local owner = grapPoint.owner

            if owner ~= nil owner.activeTool ~= nil and owner.activeTool == self then
                local index = owner.activeToolLocationId == index from loop

                use grabPoint further!
            end
        end
    ]]

    if self.isServer then
        -- is this only for server? Check later
        if self.grabPoints ~= nil then
            for i, grabPoint in pairs(self.grabPoints) do
                if grabPoint ~= nil then
                    if grabPoint.isOwned then
                        self:doPlayerDistanceCheck(dt, grabPoint)
                    else
                        self:doReferenceDistanceCheck(dt, grabPoint)
                    end
                end
            end
        end
    end

    -- if self.isPlayer() then
    -- if g_currentMission.player.activeTool ~= nil and g_currentMission.player.activeTool == self then
    -- local index = g_currentMission.player.activeToolLocationId
    -- local grabPoint = self.grabPoints[index]

    -- if grabPoint ~= nil and grabPoint.isOwned then
    -- local player = self:getOwner(index)

    -- if player ~= nil and player == g_currentMission.player then
    -- if LiquidManureHose:isAttached(grabPoint.attachState) then
    -- self:setChainCount(1) -- We're always 1 behind cause we are counting the jointIndexes!

    -- if self.grabPoints ~= nil then
    -- if self.isServer then
    -- for i, liquidManureHoseGrabPoint in pairs(self.grabPoints) do

    -- self:calculateChainRecursively(liquidManureHoseGrabPoint)

    -- if liquidManureHoseGrabPoint ~= grabPoint then

    -- if LiquidManureHose:isConnected(liquidManureHoseGrabPoint.attachState) then
    -- if liquidManureHoseGrabPoint.connectorRef ~= nil then
    -- local x, y, z = getWorldTranslation(liquidManureHoseGrabPoint.connectorRef.node)
    -- local px, py, pz = getWorldTranslation(player.rootNode)
    -- local dx, dz = px - x, pz - z
    -- local radius = dx * dx + dz * dz
    -- local inRange = false
    -- local actionRadius = (self.hose.length * self.hose.length) * (self.currentChainCount - 1) -- give it some space because nothing shithead
    -- print("New " .. actionRadius)
    -- print("Radius " .. radius)

    -- if radius < actionRadius then
    -- inRange = true
    -- end

    -- if radius < actionRadius then
    -- self.hose.lastInRangePosition = {getTranslation(player.rootNode)}
    -- else
    -- local x, y, z = getWorldTranslation(player.rootNode)
    -- local gx, gy, gz = getWorldTranslation(liquidManureHoseGrabPoint.node)
    -- local distance = Utils.vector3Length(x - gx, y - gy, z - gz)

    -- if distance > self.hose.length then
    -- local kx, _, kz = getWorldTranslation(liquidManureHoseGrabPoint.connectorRef.node)
    -- local px, _, pz = getWorldTranslation(player.rootNode)
    -- local len = Utils.vector2Length(px - kx, pz - kz)
    -- local x, y, z = unpack(self.hose.lastInRangePosition)

    -- x = kx + ((px - kx) / len) * ((self.hose.length * (self.currentChainCount - 1)) - 0.00001 * dt)
    -- z = kz + ((pz - kz) / len) * ((self.hose.length * (self.currentChainCount - 1)) - 0.00001 * dt)
    -- y = math.max(y, getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 0, z))

    -- player:moveToAbsoluteInternal(x, y, z)
    -- self.hose.lastInRangePosition = {x, y, z}

    -- if not self.hose.rangeRestrictionMessageShown and player == g_currentMission.player then
    -- self.hose.rangeRestrictionMessageShown = true
    -- g_currentMission:showBlinkingWarning(g_i18n:getText('HOSE_RANGERESTRICTION'), 5000)
    -- end
    -- end
    -- end
    -- end
    -- end
    -- end
    -- end
    -- end
    -- print(self.currentChainCount)
    -- if self.currentChainCount >= 4 then
    -- player.walkingIsLocked = true

    -- if not self.playerRestrictionChainToLongShown then
    -- self.playerRestrictionChainToLongShown = true
    -- g_currentMission:showBlinkingWarning('You are not a super human!', 5000)
    -- end
    -- else
    -- player.walkingIsLocked = false

    -- if self.currentChainCount > 1 then
    -- player.walkingSpeed = self.walkingSpeed / ((self.hose.length / 2) * self.currentChainCount)
    -- player.runningFactor = self.runningFactor / ((self.hose.length / 2) * self.currentChainCount)
    -- end
    -- end
    -- end
    -- end
    -- end
    -- end
    -- end
    -- end
end

function LiquidManureHose:calculateChainRecursively(grabPoint)
    if grabPoint ~= nil then
        local count = self.currentChainCount
        -- only count the joint index from the extenable ones?
        if grabPoint.hasExtenableJointIndex then
            count = count + 1
        end

        if grabPoint.connectorRef ~= nil and grabPoint.connectorRef ~= grabPoint then
            if grabPoint.connectorRef.hasExtenableJointIndex then
                count = count + 1
            end
        end

        self:setChainCount(count)

        if grabPoint.connectorVehicle ~= nil then --and grabPoint.connectorVehicle ~= self
            if grabPoint.connectorVehicle.grabPoints ~= nil then
                for i, connectorGrabPoint in pairs(grabPoint.connectorVehicle.grabPoints) do
                    if connectorGrabPoint ~= nil then --and connectorGrabPoint ~= grabPoint then
                        if connectorGrabPoint ~= grabPoint.connectorRef then
                            self:calculateChainRecursively(connectorGrabPoint)
                        end
                    end
                end
            end
        end
    end
end

function LiquidManureHose:getLastGrabpointRecursively(grabPoint, count)
    if grabPoint ~= nil then
        if count ~= nil then
            if grabPoint.hasExtenableJointIndex then
                count = count + 1
            end

            if grabPoint.connectorRef ~= nil and grabPoint.connectorRef ~= grabPoint then
                if grabPoint.connectorRef.hasExtenableJointIndex then
                    count = count + 1
                end
            end
        end

        if grabPoint.connectorVehicle ~= nil then
            if grabPoint.connectorVehicle.grabPoints ~= nil then
                for i, connectorGrabPoint in pairs(grabPoint.connectorVehicle.grabPoints) do
                    if connectorGrabPoint ~= nil then
                        if connectorGrabPoint ~= grabPoint.connectorRef then
                            self:getLastGrabpointRecursively(connectorGrabPoint, count)
                        end
                    end
                end
            end
        end

        return grabPoint, count
    end

    return nil
end

function LiquidManureHose:setChainCount(count, noEventSend)
    liquidManureHoseChainCountEvent.sendEvent(self, count, noEventSend)

    self.currentChainCount = count
end

function LiquidManureHose:doPlayerDistanceCheck(dt, grabPoint)
    local player = self:getOwner(grabPoint.id)

    if player ~= nil then
        if player.positionIsDirty then
            if player.activeTool ~= nil and player.activeTool == self then
                local index = player.activeToolLocationId
                local playerGrabPoint = self.grabPoints[index]

                if grabPoint == playerGrabPoint then
                    if LiquidManureHose:isAttached(grabPoint.attachState) then
                        local dependentGrabpoint

                        self:setChainCount(1) -- We're always 1 behind cause we are counting the jointIndexes!

                        for _, gp in pairs(self.grabPoints) do
                            local _, count = self:getLastGrabpointRecursively(gp, self.currentChainCount)
                            self:setChainCount(count)
                            -- print(count)
                            --self:calculateChainRecursively(gp)
                            if gp ~= grabPoint then
                                dependentGrabpoint = gp
                                break
                            end
                        end

                        if dependentGrabpoint ~= nil then
                            if LiquidManureHose:isConnected(dependentGrabpoint.attachState) or LiquidManureHose:isAttached(dependentGrabpoint.attachState) then
                                if dependentGrabpoint.connectorRef ~= nil then
                                    local x, y, z = getWorldTranslation(dependentGrabpoint.connectorRef.node)
                                    local px, py, pz = getWorldTranslation(player.rootNode)
                                    local dx, dz = px - x, pz - z
                                    local radius = dx * dx + dz * dz
                                    --local inRange = false
                                    -- local actionRadius = (self.hose.length * self.hose.length) * (self.currentChainCount - 1)
                                    local actionRadius = self.currentChainCount > 1 and (self.hose.length * self.hose.length) * 1.2 or self.hose.length * self.hose.length -- give it some space when moving a chain because well..
                                    -- print(" New " .. actionRadius)
                                    -- print("Radius " .. radius)

                                    -- if radius < actionRadius then
                                    -- inRange = true
                                    -- end

                                    if radius < actionRadius then
                                        self.hose.lastInRangePosition = { getTranslation(player.rootNode) }
                                    else
                                        -- local x, y, z = getWorldTranslation(player.rootNode)
                                        -- local gx, gy, gz = getWorldTranslation(dependentGrabpoint.node)
                                        -- local distance = Utils.vector3Length(x - gx, y - gy, z - gz)

                                        -- if distance > self.hose.length then
                                        local kx, _, kz = getWorldTranslation(dependentGrabpoint.connectorRef.node)
                                        local px, _, pz = getWorldTranslation(player.rootNode)
                                        local distance = Utils.vector2Length(px - kx, pz - kz)
                                        local x, y, z = unpack(self.hose.lastInRangePosition)

                                        x = kx + ((px - kx) / distance) * (self.hose.length - 0.00001 * dt)
                                        -- x = kx + ((px - kx) / distance) * (self.hose.length * (self.currentChainCount - 1) - 0.00001 * dt)
                                        z = kz + ((pz - kz) / distance) * (self.hose.length - 0.00001 * dt)
                                        -- z = kz + ((pz - kz) / distance) * (self.hose.length * (self.currentChainCount - 1) - 0.00001 * dt)
                                        y = math.max(y, getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 0, z))

                                        player:moveToAbsoluteInternal(x, y, z)
                                        self.hose.lastInRangePosition = { x, y, z }

                                        if not self.hose.rangeRestrictionMessageShown and player == g_currentMission.player then
                                            self.hose.rangeRestrictionMessageShown = true
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

function LiquidManureHose:doReferenceDistanceCheck(dt, grabPoint)
    if LiquidManureHose:isConnected(grabPoint.attachState) then
        local dependentGrabpoint

        for _, gp in pairs(self.grabPoints) do
            if gp ~= grabPoint then
                if LiquidManureHose:isConnected(gp.attachState) then -- or LiquidManureHose:isDetached(gp.attachState) then -- Todo: what todo when 1 side is stucked behind a object?
                    dependentGrabpoint = gp
                    break
                end
            end
        end

        if dependentGrabpoint ~= nil then
            if grabPoint.connectorVehicle ~= nil then
                if not grabPoint.connectorRef.connectable and not grabPoint.connectorRef.parkable then -- not dependentGrabpoint.connectorRef.connectable
                    local ax, ay, az = getWorldTranslation(self.components[grabPoint.componentIndex].node)
                    local bx, by, bz = getWorldTranslation(self.components[dependentGrabpoint.componentIndex].node)
                    local distance = Utils.vector3Length(bx - ax, by - ay, bz - az)
                    local allowedDistance = not LiquidManureHose:isDetached(dependentGrabpoint.attachState) and self.hose.length or self.hose.length * 1.2

                    if distance > allowedDistance or distance < (allowedDistance - 1) then
                        if LiquidManureHose.debug then
                            print("LMH Debug | updateRestrictions: distance to far or to close.. hose is detached! Distance: " .. distance)
                        end

                        -- Todo: when moving the wheel shape can not be found.. which gives physics warnings
                        -- self:detach(grabPoint.id, nil, grabPoint.connectorVehicle, grabPoint.connectorRef.id, grabPoint.connectorRef.connectable ~= nil and grabPoint.connectorRef.connectable)
                    end
                end
            end
        end
    end
end

function LiquidManureHose:updateTick(dt)
    if self.isClient then
        -- self:setEmptyEffect(self.emptyEffects.showEmptyEffects, 27, 2)
        self:setEmptyEffect(self.hoseEffects.isActive, FillUtil.FILLTYPE_LIQUIDMANURE, 2)

        if self.hoseEffects.isActive then
            SoundUtil.playSample(self.emptyingSound, 0, 0, nil)
            SoundUtil.play3DSample(self.emptyingSound)
        else
            SoundUtil.stopSample(self.emptyingSound)
            SoundUtil.stop3DSample(self.emptyingSound)
        end
    end

    if self.isServer then
        if self.grabPoints ~= nil then
            for _, gp in pairs(self.grabPoints) do -- Todo: make rayCastNodes as child for grabPoint.node
                if LiquidManureHose:isDetached(gp.attachState) then
                    local rayCastNode = clone(gp.node, true, false, true)

                    if gp.id > 1 then
                        setRotation(rayCastNode, 0, math.rad(180), 0)
                    end

                    local x, y, z = getWorldTranslation(rayCastNode)
                    local dx, dy, dz = localDirectionToWorld(rayCastNode, 0, 0, -1)

                    self.lastRaycastDistance = 0
                    self.lastRaycastObject = nil

                    raycastClosest(x, y, z, dx, dy, dz, 'fillableObjectRaycastCallback', 2, self)

                    local xyz = { worldToLocal(rayCastNode, x, y, z) }
                    xyz[3] = xyz[3] - 2
                    xyz = { localToWorld(rayCastNode, xyz[1], xyz[2], xyz[3]) }
                    local color = { 1, 0 }

                    if self.lastRaycastDistance ~= 0 then
                        color = { 0, 1 }
                        local isUnderFillplane, planeY = self.lastRaycastObject:checkPlaneY(y)

                        if isUnderFillplane then
                            -- todo: make this direction based!
                            local difference = math.abs(planeY - y)

                            if self:getDirtAmount() < difference then
                                self:setDirtAmount(difference)
                            end
                        end
                    end

                    drawDebugLine(x, y, z, color[1], color[2], 0, xyz[1], xyz[2], xyz[3], color[1], color[2], 0)

                    delete(rayCastNode)
                end
            end
        end
    end
end

function LiquidManureHose:draw() end

---
-- @param index
-- @param state
-- @param player
-- @param noEventSend
--
function LiquidManureHose:grab(index, player, state, noEventSend)
    if not noEventSend and state == nil or state == liquidManureHoseGrabEvent.initialise then
        liquidManureHoseGrabEvent.sendEvent(self, index, player, liquidManureHoseGrabEvent.client, noEventSend)
    end


    local grabPoint = self.grabPoints[index]

    if grabPoint ~= nil and player ~= nil then
        --if player == g_currentMission.player then
        if state == nil or state == liquidManureHoseGrabEvent.initialise then
            grabPoint.attachState = LiquidManureHose.states.attached

            self:setOwner(index, true, player)
            self:updateOwnerInputParts(index, true, player == g_currentMission.player)

            self.walkingSpeed = player.walkingSpeed
            self.runningFactor = player.runningFactor

            -- self.emptyEffects.showEmptyEffects = true

            if LiquidManureHose.debug then
                print(LiquidManureHose:print_r({
                    node = grabPoint.node,
                    nodeOrgTrans = grabPoint.nodeOrgTrans,
                    nodeOrgRot = grabPoint.nodeOrgRot,
                    jointIndex = grabPoint.jointIndex,
                    hasJointIndex = grabPoint.hasJointIndex, -- We don't sync the actual JointIndex it's server sided
                    hasExtenableJointIndex = grabPoint.hasExtenableJointIndex, -- We don't sync the actual JointIndex it's server sided
                    componentIndex = grabPoint.componentIndex,
                    connectable = grabPoint.connectable,
                    attachState = grabPoint.attachState,
                    -- connectorRef = grabPoint.connectorRef,
                    -- connectorVehicle = grabPoint.connectorVehicle,
                    currentOwner = grabPoint.currentOwner ~= nil,
                    isOwned = grabPoint.isOwned
                }, 'Grabpoint for current client'))
            end

            if self.isServer then
                if LiquidManureHose.debug then
                    print('Grab hose: we are the server')
                end
                self:grab(index, player, liquidManureHoseGrabEvent.server, noEventSend)
            else
                if LiquidManureHose.debug then
                    print('Grab hose: we are not the server lets sync it with the server')
                end
                liquidManureHoseGrabEvent.sendEvent(self, index, player, liquidManureHoseGrabEvent.server, self.isServer)
            end
        elseif state == liquidManureHoseGrabEvent.server then
            if self.hose ~= nil and self.hose.node ~= nil then

                local node = clone(self.hose.node, true, false, true)
                local jointNode = getChildAt(node, 0)
                local rightHandNode = clone(self.hose.node, true, false, true)
                local leftHandNode = clone(self.hose.node, true, false, true)

                player.hose = {
                    node = node,
                    jointNode = jointNode,
                    rightHandNode = rightHandNode,
                    leftHandNode = leftHandNode,
                    -- walkingSpeed = player.walkingSpeed, -- else this will be overwritten
                    -- runningFactor = player.runningFactor -- else this will be overwritten
                }

                -- LiquidManureHose:orientJoint(grabPoint.node, player.hose.jointNode, false, true, false)

                -- local hoseRot = index > 1 and math.rad(0) or math.rad(180)
                local hoseRot = index > 1 and math.rad(-180) or math.rad(0)

                -- Todo: the hoseRot is also dependent on how much hoses we have attached! If the index we grab is > 1 doesn't always mean we have to rotate it 180 deg
                local lastGrabPoint
                local count

                for _, gp in pairs(self.grabPoints) do
                    if gp ~= grabPoint then -- We grab a side thats not attached so exclude that.
                        lastGrabPoint, count = self:getLastGrabpointRecursively(gp, 1)
                    end
                end

                if count ~= nil and count > 1 and lastGrabPoint ~= nil then
                    print('lastGrabPoint.id ' .. lastGrabPoint.id)
                    --hoseRot = lastGrabPoint.id > 1 and math.rad(180) or math.rad(0)
                end

                LiquidManureHose:orientJoint(grabPoint.node, player.hose.jointNode, false, false, false, hoseRot)

                link(player.toolsRootNode, player.hose.node)
                -- link(player.graphicsRootNode, player.hose.node)
                --link(player.hose.node, player.hose.rightHandNode)

                setTranslation(player.hose.node, -0.4, -0.1, 0.3)
                -- setTranslation(player.hose.node, 0.3, 0.3, -0.6) -- graphicsRootNode
                -- Debug distance
                -- setTranslation(player.hose.node, 0.3, 0.3, -3) -- graphicsRootNode

                -- make this dependent on player rotation
                local yRot = math.abs(Utils.getYRotationBetweenNodes(grabPoint.node, player.toolsRootNode))

                -- local cosAngle = LiquidManureHose:calculateCosAngle(player.graphicsRootNode, grabPoint.node)
                -- print("index= " .. index.. " yRot = " .. yRot)
                setRotation(player.hose.node, 0, yRot >= 1.5 and (index > 1 and math.rad(0) or math.rad(180)) or (index > 1 and math.rad(180) or math.rad(0)), 0)

                --setRotation(player.hose.node, 0, math.rad(180) , 0)

                -- Todo: calculate mass of hose components.. save it in self on game load.
                -- For now just set 4kg for every meter.
                player.hose.mass = (0.004 * self.hose.length) * 100

                LiquidManureHose:constructPlayerJoint({
                    actor1 = player.hose.node,
                    actor2 = self.components[grabPoint.componentIndex].node,
                    anchor1 = player.hose.jointNode,
                    anchor2 = grabPoint.node
                }, player.hose)

                --player.hose.jointIndex = LiquidManureHose:constructJoint(player.hose.node, self.components[grabPoint.componentIndex].node, player.hose.jointNode, grabPoint.node, {1000, 1000, 1000}, {1000, 1000, 1000}, {100, 100, 100}, {100, 100, 100})

                -- Set collision mask on hose components to disable collision with CCT
                for i, component in pairs(self.components) do
                    if i ~= grabPoint.componentIndex then
                        setPairCollision(player.hose.node, component.node, false)
                    end

                    -- Todo only include 2 when we are rotating 180 degrees!
                    if i == grabPoint.componentIndex then -- or 2
                        setCollisionMask(component.node, 32)
                    end
                end

                setCollisionMask(grabPoint.componentChildNode, 32)

                -- Recreate component joints to get more realistic movement
                -- self:updateComponentJointMovement(index)

                --self:updateOwnerInputParts(index, true, player == g_currentMission.player)
                if LiquidManureHose.debug then
                    print(LiquidManureHose:print_r({
                        node = grabPoint.node,
                        nodeOrgTrans = grabPoint.nodeOrgTrans,
                        nodeOrgRot = grabPoint.nodeOrgRot,
                        jointIndex = grabPoint.jointIndex,
                        hasJointIndex = grabPoint.hasJointIndex, -- We don't sync the actual JointIndex it's server sided
                        hasExtenableJointIndex = grabPoint.hasExtenableJointIndex, -- We don't sync the actual JointIndex it's server sided
                        componentIndex = grabPoint.componentIndex,
                        connectable = grabPoint.connectable,
                        attachState = grabPoint.attachState,
                        -- connectorRef = grabPoint.connectorRef,
                        -- connectorVehicle = grabPoint.connectorVehicle,
                        currentOwner = grabPoint.currentOwner ~= nil,
                        isOwned = grabPoint.isOwned
                    }, 'Grabpoint for server'))
                end
            end
        elseif state == liquidManureHoseGrabEvent.client then
            if player ~= g_currentMission.player then
                --print('Grab hose: other clients are getting other infos')

                grabPoint.attachState = LiquidManureHose.states.attached

                self:setOwner(index, true, player)
                self:updateOwnerInputParts(index, true, false)

                if LiquidManureHose.debug then
                    print(LiquidManureHose:print_r({
                        node = grabPoint.node,
                        nodeOrgTrans = grabPoint.nodeOrgTrans,
                        nodeOrgRot = grabPoint.nodeOrgRot,
                        jointIndex = grabPoint.jointIndex,
                        hasJointIndex = grabPoint.hasJointIndex, -- We don't sync the actual JointIndex it's server sided
                        hasExtenableJointIndex = grabPoint.hasExtenableJointIndex, -- We don't sync the actual JointIndex it's server sided
                        componentIndex = grabPoint.componentIndex,
                        connectable = grabPoint.connectable,
                        attachState = grabPoint.attachState,
                        --connectorRef = grabPoint.connectorRef,
                        --connectorVehicle = grabPoint.connectorVehicle,
                        currentOwner = grabPoint.currentOwner ~= nil,
                        isOwned = grabPoint.isOwned
                    }, 'Grabpoint for other clients'))
                end
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
function LiquidManureHose:drop(index, player, state, noEventSend)
    if not noEventSend and state == nil or state == liquidManureHoseDropEvent.initialise then
        liquidManureHoseDropEvent.sendEvent(self, index, player, liquidManureHoseDropEvent.client, noEventSend)
    end

    local grabPoint = self.grabPoints[index]

    if grabPoint ~= nil then
        if player ~= nil then
            -- if player == g_currentMission.player then
            if state == nil or state == liquidManureHoseDropEvent.initialise then
                player = self:getOwner(index)

                if player ~= nil then
                    player.walkingSpeed = self.walkingSpeed
                    player.runningFactor = self.runningFactor

                    -- test
                    -- self.emptyEffects.showEmptyEffects = false
                    grabPoint.attachState = LiquidManureHose.states.detached

                    self:updateOwnerInputParts(index, false, player == g_currentMission.player)
                    self:setOwner(index, false, player)

                    if self.isServer then
                        -- if LiquidManureHose.debug then
                        print('Drop hose: we are the server')
                        -- end
                        self:drop(index, player, liquidManureHoseDropEvent.server, noEventSend)
                    else
                        if LiquidManureHose.debug then
                            print('Drop hose: we are not the server lets sync it with the server')
                        end
                        liquidManureHoseDropEvent.sendEvent(self, index, player, liquidManureHoseDropEvent.server, self.isServer)
                    end
                end
            elseif state == liquidManureHoseDropEvent.server then
                if player.hose ~= nil then
                    setTranslation(grabPoint.node, unpack(grabPoint.nodeOrgTrans))
                    setRotation(grabPoint.node, unpack(grabPoint.nodeOrgRot))

                    -- Player
                    if player.hose.node ~= nil then
                        unlink(player.hose.node)
                        delete(player.hose.node)
                    end

                    if self.isServer then
                        if player.hose.jointIndex ~= 0 then
                            removeJoint(player.hose.jointIndex)
                        end
                    end

                    player.hose.jointIndex = 0
                    player.hose.node = nil
                    player.hose.jointNode = nil

                    for i, component in pairs(self.components) do
                        -- transformId, decimal mask
                        if i == grabPoint.componentIndex then -- or 2
                            setCollisionMask(component.node, 8194)
                        end
                    end

                    setCollisionMask(grabPoint.componentChildNode, 8194)
                end

                if LiquidManureHose.debug then
                    print(LiquidManureHose:print_r({
                        node = grabPoint.node,
                        nodeOrgTrans = grabPoint.nodeOrgTrans,
                        nodeOrgRot = grabPoint.nodeOrgRot,
                        jointIndex = grabPoint.jointIndex,
                        hasJointIndex = grabPoint.hasJointIndex, -- We don't sync the actual JointIndex it's server sided
                        hasExtenableJointIndex = grabPoint.hasExtenableJointIndex, -- We don't sync the actual JointIndex it's server sided
                        componentIndex = grabPoint.componentIndex,
                        connectable = grabPoint.connectable,
                        attachState = grabPoint.attachState,
                        -- connectorRef = grabPoint.connectorRef,
                        -- connectorVehicle = grabPoint.connectorVehicle,
                        currentOwner = grabPoint.currentOwner ~= nil,
                        isOwned = grabPoint.isOwned
                    }, 'Drop: Grabpoint for server'))
                end
            elseif state == liquidManureHoseDropEvent.client then
                if player ~= g_currentMission.player then
                    if LiquidManureHose.debug then
                        print('Drop hose: other clients are getting other infos')
                    end
                    grabPoint.attachState = LiquidManureHose.states.detached

                    self:updateOwnerInputParts(index, false, false)
                    self:setOwner(index, false, player)
                end
            end
        end
    end
end

---
-- @param index
-- @param state
-- @param vehicle
-- @param referenceId
-- @param isExtendable
-- @param noEventSend
--
function LiquidManureHose:attach(index, state, vehicle, referenceId, isExtendable, noEventSend)
    -- Todo: remove state param

    -- if not noEventSend or noEventSend == nil then
    liquidManureHoseAttachEvent.sendEvent(self, index, 0, vehicle, referenceId, isExtendable, noEventSend)
    -- end

    local grabPoint = self.grabPoints[index]

    if grabPoint ~= nil then
        if vehicle ~= nil then
            local object = vehicle.hoseSystemReferences ~= nil and vehicle or vehicle.grabPoints ~= nil and vehicle or vehicle.hoseSystemParent
            local reference = isExtendable and object.grabPoints[referenceId] or object.hoseSystemReferences[referenceId]

            if reference ~= nil then
                local grabPoints = { grabPoint }

                if reference.parkable then
                    -- handle parked hose
                    if self.hose.length < reference.parkLength then
                        table.insert(grabPoints, index > 1 and self.grabPoints[1] or self.grabPoints[table.getn(self.grabPoints)])

                        if self.isServer then
                            local lastIndex = table.getn(grabPoints)

                            if LiquidManureHose:isConnected(grabPoints[lastIndex].attachState) then
                                self:detach(grabPoints[lastIndex].id, nil, grabPoints[lastIndex].connectorVehicle, grabPoints[lastIndex].connectorRef.id, (grabPoints[lastIndex].connectorRef.connectable ~= nil and grabPoints[lastIndex].connectorRef.connectable) or (grabPoints[lastIndex].connectable ~= nil and grabPoints[lastIndex].connectable))
                            end
                        end

                        -- Do this after above else it will fuckup the data..
                        if grabPoint.isOwned then -- we can't call it on start since we don't want to drop when the parking place is to small.
                            self:drop(index, self:getOwner(index))
                        end

                        --if self.isServer then
                        self:hardParkHose(grabPoints, object, reference)
                        --end
                    else
                        g_currentMission:showBlinkingWarning(string.format(g_i18n:getText('HOSE_PARKINGPLACE_TO_SHORT'), reference.parkLength, self.hose.length), 5000)

                        return false
                    end
                else
                    -- handle connected hose
                    if grabPoint.isOwned then -- we can't call it on start since we don't want to drop when the parking place is to small.
                        self:drop(index, self:getOwner(index))
                    end

                    -- reference.grabPoints = self.grabPoints
                    -- reference.liquidManureHose = self

                    if isExtendable then
                        -- Set 2 way recognition
                        reference.connectorRef = grabPoint -- current grabPoint
                        reference.connectorVehicle = self

                        if grabPoint.connectable then
                            self:toggleLock(true) -- close lock
                        else
                            object:toggleLock(true) -- close lock
                        end
                    end

                    --					if self.isServer then
                    self:hardConnect(grabPoint, object, reference)
                    --					end
                end

                for _, grabPoint in pairs(grabPoints) do
                    grabPoint.connectorRef = reference
                    grabPoint.connectorVehicle = vehicle

                    self:syncIsUsed(grabPoint.id, true, table.getn(grabPoints) < 2 and isExtendable or false)
                end

                -- force the mesh updates again
                if self.isClient then
                    self:updateHose(true)
                    self.jointSpline.firstRunUpdates = 0
                end
            end
        end
    end

    -- if not noEventSend and state == nil or state == liquidManureHoseAttachEvent.initialise then
    -- liquidManureHoseAttachEvent.sendEvent(self, index, liquidManureHoseAttachEvent.client, vehicle, referenceId, isExtendable, noEventSend)
    -- end

    -- local grabPoint = self.grabPoints[index]

    -- if grabPoint ~= nil then
    -- if state == nil or state == liquidManureHoseAttachEvent.initialise then
    -- local reference = isExtendable and vehicle.grabPoints[referenceId] or vehicle.hoseSystemReferences[referenceId]

    -- -- Are we parking?
    -- if reference.parkable then
    -- if self.hose.length < reference.parkLength then
    -- -- Set more info
    -- local grabPoints = {
    -- grabPoint,
    -- index > 1 and self.grabPoints[1] or self.grabPoints[table.getn(self.grabPoints)]
    -- }

    -- --if self.isServer then
    -- if LiquidManureHose:isConnected(grabPoints[2].attachState) then
    -- self:detach(grabPoints[2].id, nil, grabPoints[2].connectorVehicle, grabPoints[2].connectorRef.id, grabPoints[2].connectorRef.connectable ~= nil and grabPoints[2].connectorRef.connectable)
    -- end
    -- --end

    -- -- Do this after above else it will fuckup the data..
    -- if grabPoint.isOwned then -- we can't call it on start since we don't want to drop when the parking place is to small.
    -- self:drop(index, self:getOwner(index))
    -- end

    -- for _, grabPoint in pairs(grabPoints) do
    -- grabPoint.connectorRef = reference
    -- grabPoint.connectorVehicle = vehicle

    -- self:syncIsUsed(grabPoint.id, true, false)
    -- end
    -- else
    -- g_currentMission:showBlinkingWarning(string.format(g_i18n:getText('HOSE_PARKINGPLACE_TO_SHORT'), reference.parkLength, self.hose.length), 5000)

    -- return
    -- end
    -- else
    -- if grabPoint.isOwned then -- we can't call it on start since we don't want to drop when the parking place is to small.
    -- self:drop(index, self:getOwner(index))
    -- end

    -- -- reference.grabPoints = self.grabPoints
    -- -- reference.liquidManureHose = self

    -- if isExtendable then
    -- -- Set 2 way recognition
    -- reference.connectorRef = grabPoint -- current grabPoint
    -- reference.connectorVehicle = self

    -- if grabPoint.connectable then
    -- self:toggleLock(true) -- close lock
    -- else
    -- vehicle:toggleLock(true) -- close lock
    -- end

    -- --vehicle:updateHose(true)
    -- end

    -- grabPoint.connectorRef = reference
    -- grabPoint.connectorVehicle = vehicle

    -- self:syncIsUsed(index, true, isExtendable)
    -- end

    -- if self.isServer then
    -- self:attach(index, liquidManureHoseAttachEvent.server, vehicle, referenceId, isExtendable)
    -- else
    -- liquidManureHoseAttachEvent.sendEvent(self, index, liquidManureHoseAttachEvent.server, vehicle, referenceId, isExtendable, self.isServer)
    -- end

    -- self:updateHose(true)
    -- -- force the updates again
    -- self.jointSpline.firstRunUpdates = 0

    -- elseif state == liquidManureHoseAttachEvent.server then
    -- local reference = isExtendable and vehicle.grabPoints[referenceId] or vehicle.hoseSystemReferences[referenceId]

    -- if reference.parkable then
    -- local grabPoints = {
    -- grabPoint,
    -- index > 1 and self.grabPoints[1] or self.grabPoints[table.getn(self.grabPoints)]
    -- }

    -- for _, grabPoint in pairs(grabPoints) do
    -- grabPoint.connectorRef = reference
    -- grabPoint.connectorVehicle = vehicle
    -- end

    -- self:hardParkHose(grabPoints, vehicle, reference)

    -- -- Todo: scope if we really need to sync the grabPoint on all clients.. it's done already.
    -- else
    -- self:hardConnect(grabPoint, vehicle, reference)

    -- --if isExtendable then
    -- -- we need 2 way recognition
    -- --grabPoint.connectorRef.connectorRef = grabPoint
    -- --grabPoint.connectorRef.connectorVehicle = self
    -- --end

    -- grabPoint.connectorRef = reference
    -- grabPoint.connectorVehicle = vehicle

    -- -- self:syncIsUsed(index, true, isExtendable)
    -- end
    -- elseif state == liquidManureHoseAttachEvent.client then
    -- if player ~= g_currentMission.player then
    -- print('Attachhose: we are other clients lets get some info')
    -- grabPoint.connectorRef = isExtendable and vehicle.grabPoints[referenceId] or vehicle.hoseSystemReferences[referenceId]
    -- grabPoint.connectorVehicle = vehicle

    -- -- grabPoint.attachState = LiquidManureHose.states.connected
    -- -- grabPoint.connectorRef.grabPoints = self.grabPoints
    -- -- grabPoint.connectorRef.liquidManureHose = self

    -- if grabPoint.connectorRef.parkable then
    -- --self:syncIsUsed(index, true, false)
    -- else
    -- --self:syncIsUsed(index, true, isExtendable)
    -- end
    -- end
    -- end
    -- end
end

---
-- @param index
-- @param state
-- @param noEventSend
--
function LiquidManureHose:detach(index, state, vehicle, referenceId, isExtendable, noEventSend)
    -- Todo: remove state param

    -- if not noEventSend or noEventSend == nil then
    liquidManureHoseDetachEvent.sendEvent(self, index, 0, vehicle, referenceId, isExtendable, noEventSend)
    -- end

    local grabPoint = self.grabPoints[index]

    if grabPoint ~= nil then
        if vehicle ~= nil then
            local object = vehicle.hoseSystemReferences ~= nil and vehicle or vehicle.grabPoints ~= nil and vehicle or vehicle.hoseSystemParent
            local reference = isExtendable and object.grabPoints[referenceId] or object.hoseSystemReferences[referenceId]

            if reference ~= nil then
                local grabPoints = { grabPoint }

                if reference.parkable then
                    -- handle parked hose
                    table.insert(grabPoints, index > 1 and self.grabPoints[1] or self.grabPoints[table.getn(self.grabPoints)])

                    --if self.isServer then
                    self:hardUnparkHose(grabPoints, object, reference)
                    --end
                else
                    -- handle connected hose
                    if grabPoint.connectable then
                        self:toggleLock(false) -- open lock
                    end

                    if reference.connectable then
                        object:toggleLock(false) -- open lock
                    end

                    --					if self.isServer then
                    self:hardDisconnect(grabPoint, object, reference)
                    --					end
                end

                for _, grabPoint in pairs(grabPoints) do
                    self:syncIsUsed(grabPoint.id, false, false)

                    grabPoint.connectorRef = nil
                    grabPoint.connectorVehicle = nil

                    if self.isServer then
                        setTranslation(grabPoint.node, unpack(grabPoint.nodeOrgTrans))
                        setRotation(grabPoint.node, unpack(grabPoint.nodeOrgRot))
                    end
                end
            end
        end
    end


    -- if not noEventSend and state == nil or state == liquidManureHoseDetachEvent.initialise then
    -- liquidManureHoseDetachEvent.sendEvent(self, index, liquidManureHoseDetachEvent.client, vehicle, referenceId, isExtendable, noEventSend)
    -- end

    -- local grabPoint = self.grabPoints[index]

    -- if grabPoint ~= nil then
    -- if state == nil or state == liquidManureHoseDetachEvent.initialise then
    -- local reference = isExtendable and vehicle.grabPoints[referenceId] or vehicle.hoseSystemReferences[referenceId]
    -- -- local reference = grabPoint.connectorRef
    -- -- local vehicle = grabPoint.connectorVehicle

    -- if self.isServer then
    -- self:detach(index, liquidManureHoseDetachEvent.server, vehicle, referenceId, isExtendable)
    -- else
    -- liquidManureHoseDetachEvent.sendEvent(self, index, liquidManureHoseDetachEvent.server, vehicle, referenceId, isExtendable, self.isServer)
    -- end

    -- if reference.parkable then
    -- -- Handle park detach
    -- local grabPoints = {
    -- controllingGrabPoint = grabPoint,
    -- endGrabPoint = index > 1 and self.grabPoints[1] or self.grabPoints[table.getn(self.grabPoints)]
    -- }

    -- for _, grabPoint in pairs(grabPoints) do
    -- self:syncIsUsed(grabPoint.id, false, false)

    -- grabPoint.connectorRef = nil
    -- grabPoint.connectorVehicle = nil

    -- -- setTranslation(grabPoint.node, unpack(grabPoint.nodeOrgTrans))
    -- -- setRotation(grabPoint.node, unpack(grabPoint.nodeOrgRot))
    -- end
    -- else
    -- self:syncIsUsed(index, false, false)

    -- -- When we don't grab it right after detach we should set this
    -- -- grabPoint.attachState = LiquidManureHose.states.detached
    -- if grabPoint.connectable then
    -- self:toggleLock(false) -- open lock
    -- end

    -- if reference.connectable then
    -- vehicle:toggleLock(false) -- open lock
    -- end

    -- -- We create the jointIndex on this grabPoint.. to indicate it for the clients set bool
    -- -- grabPoint.hasJointIndex = false
    -- grabPoint.connectorRef = nil
    -- grabPoint.connectorVehicle = nil
    -- end
    -- elseif state == liquidManureHoseDetachEvent.server then
    -- local reference = isExtendable and vehicle.grabPoints[referenceId] or vehicle.hoseSystemReferences[referenceId]
    -- -- local vehicle = grabPoint.connectorVehicle

    -- if reference.parkable then
    -- local grabPoints = {
    -- grabPoint,
    -- index > 1 and self.grabPoints[1] or self.grabPoints[table.getn(self.grabPoints)]
    -- }

    -- self:hardUnparkHose(grabPoints)

    -- for _, grabPoint in pairs(grabPoints) do
    -- -- self:syncIsUsed(index, false, false)
    -- grabPoint.connectorRef = nil
    -- grabPoint.connectorVehicle = nil

    -- setTranslation(grabPoint.node, unpack(grabPoint.nodeOrgTrans))
    -- setRotation(grabPoint.node, unpack(grabPoint.nodeOrgRot))
    -- end
    -- else
    -- -- self:syncIsUsed(index, false, false)

    -- self:hardDisconnect(grabPoint, vehicle, reference)
    -- -- self:removeConnectOrParkJoints(grabPoint)

    -- -- if grabPoint.connectorRef ~= nil then
    -- -- if grabPoint.connectable or grabPoint.connectorRef.connectable then
    -- -- if grabPoint.connectorRef.connectorRef ~= nil then -- Todo: test this!
    -- -- removeJoint(grabPoint.connectorRef.connectorRef.jointIndex)
    -- -- grabPoint.connectorRef.connectorRef = nil
    -- -- grabPoint.connectorRef.connectorVehicle = nil
    -- -- end
    -- -- end
    -- -- end

    -- grabPoint.connectorRef = nil
    -- grabPoint.connectorVehicle = nil

    -- setTranslation(grabPoint.node, unpack(grabPoint.nodeOrgTrans))
    -- setRotation(grabPoint.node, unpack(grabPoint.nodeOrgRot))
    -- -- if grabPoint.connectorRef ~= nil then
    -- -- -- Hose to hose set parent hose to detached again
    -- -- if grabPoint.connectorRef.attachState ~= nil then
    -- -- grabPoint.connectorRef.attachState = LiquidManureHose.states.detached
    -- -- else
    -- -- -- We got a normal connectorRef
    -- -- grabPoint.connectorRef.isUsed = false
    -- -- end
    -- -- end

    -- if LiquidManureHose.debug then
    -- print(LiquidManureHose:print_r({
    -- node = grabPoint.node,
    -- nodeOrgTrans = grabPoint.nodeOrgTrans,
    -- nodeOrgRot = grabPoint.nodeOrgRot,
    -- jointIndex = grabPoint.jointIndex,
    -- hasJointIndex = grabPoint.hasJointIndex, -- We don't sync the actual JointIndex it's server sided
    -- hasExtenableJointIndex = grabPoint.hasExtenableJointIndex, -- We don't sync the actual JointIndex it's server sided
    -- componentIndex = grabPoint.componentIndex,
    -- connectable = grabPoint.connectable,
    -- attachState = grabPoint.attachState,
    -- connectorRef = grabPoint.connectorRef,
    -- -- connectorVehicle = grabPoint.connectorVehicle,
    -- currentOwner = grabPoint.currentOwner ~= nil,
    -- isOwned = grabPoint.isOwned
    -- }, 'Detach: Grabpoint for server'))
    -- end
    -- end

    -- --liquidManureHoseDetachEvent.sendEvent(self, index, liquidManureHoseDetachEvent.client, noEventSend)
    -- elseif state == liquidManureHoseDetachEvent.client then
    -- if player ~= g_currentMission.player then
    -- -- if not shouldGrab then sync
    -- -- self:syncIsUsed(index, false, false)
    -- grabPoint.connectorRef = nil
    -- grabPoint.connectorVehicle = nil

    -- if not grabPoint.connectable and (reference ~= nil and not reference.connectable) then
    -- -- print('we should grab')
    -- --self:grab(index, g_currentMission.player, liquidManureHoseGrabEvent.client)
    -- end

    -- -- When we don't grab it right after detach we should set this
    -- -- grabPoint.attachState = LiquidManureHose.states.detached

    -- -- Todo: resync connectorRef and connectorVehicle they should be nil!

    -- if grabPoint.connectorRef ~= nil then
    -- if grabPoint.connectorRef.connectable then
    -- -- if grabPoint.connectorVehicle.grabPoints ~= nil then
    -- -- local refGrabPoint = grabPoint.connectorVehicle.grabPoints[referenceId]

    -- -- refGrabPoint.attachState = LiquidManureHose.states.detached
    -- -- end
    -- print('is connectorRef still bigger then nil?')

    -- --grabPoint.connectorVehicle:playAnimation(LiquidManureHose.animations.connect, 1, nil, true) -- "open" lock
    -- end
    -- end

    -- -- We create the jointIndex on this grabPoint.. to indicate it for the clients set bool
    -- -- grabPoint.hasJointIndex = false
    -- end
    -- end
    -- end
end

function LiquidManureHose:hardParkHose(grabPoints, vehicle, reference)
    if table.getn(grabPoints) < 2 then
        return
    end

    if not reference.isObject then
        local currentVehicle = vehicle

        while currentVehicle ~= nil do
            currentVehicle:removeFromPhysics()
            currentVehicle = currentVehicle.attacherVehicle
        end
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

    self:removeFromPhysics()

    setIsCompoundChild(self.components[grabPoints[1].componentIndex].node, true)
    setIsCompoundChild(self.components[(table.getn(self.components) + 1) / 2].node, true)
    setIsCompoundChild(self.components[grabPoints[2].componentIndex].node, true)

    -- Not needed on park function
    --LiquidManureHose:orientConnectionJoint(reference.node, grabPoints[1].node, grabPoints[1].id, grabPoints[1].connectable, reference.id, isExtendable)
    --LiquidManureHose:orientConnectionJoint(reference.node, self.components[grabPoints[1].componentIndex].node, grabPoints[1].id, grabPoints[1].connectable, reference.id, isExtendable)

    local referenceTranslation = { getWorldTranslation(reference.node) }
    local xRotOffset, yRotOffset, zRotOffset = unpack(reference.startRotOffset)
    local referenceRotation = { localRotationToLocal(self.components[grabPoints[1].componentIndex].node, grabPoints[1].node, xRotOffset, yRotOffset, zRotOffset) }
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

    local direction = { localDirectionToLocal(self.components[grabPoints[1].componentIndex].node, grabPoints[1].node, 0, 0, grabPoints[1].id > 1 and 1 or -1) } -- grabPoints[1].id > 1 and 1 or -1 grabPoints[1].id > 1 and 1 or -1
    local upVector = { localDirectionToLocal(self.components[grabPoints[1].componentIndex].node, grabPoints[1].node, 0, 1, 0) } -- grabPoints[1].id > 1 and -1 or 1

    setDirection(self.components[grabPoints[1].componentIndex].node, direction[1], direction[2], direction[3], upVector[1], upVector[2], upVector[3])

    local xOffset, yOffset, zOffset = unpack(reference.startTransOffset)
    local translation = { localToLocal(self.components[grabPoints[1].componentIndex].node, grabPoints[1].node, xOffset, yOffset, zOffset) }
    setTranslation(self.components[grabPoints[1].componentIndex].node, unpack(translation))
    setRotation(self.components[grabPoints[1].componentIndex].node, unpack(referenceRotation))
    --link(reference.node, self.components[grabPoints[1].componentIndex].node)
    setWorldTranslation(startTargetNode, unpack(referenceTranslation))

    link(startTargetNode, self.components[grabPoints[1].componentIndex].node)

    local centerTranslation = reference.offsetDirection ~= 1 and { localToWorld(reference.node, 0, 0, -self.hose.length / 2) } or { localToWorld(reference.node, 0, 0, self.hose.length / 2) }
    local centerRotation = { getRotation(self.hose.centerNode) }

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

    local direction = { localDirectionToLocal(self.components[(table.getn(self.components) + 1) / 2].node, self.hose.centerNode, 0, 0, 1) }
    local upVector = { localDirectionToLocal(self.components[(table.getn(self.components) + 1) / 2].node, self.hose.centerNode, 0, 1, 0) }

    setDirection(self.components[(table.getn(self.components) + 1) / 2].node, direction[1], direction[2], direction[3], upVector[1], upVector[2], upVector[3])

    local translation = { localToLocal(self.components[(table.getn(self.components) + 1) / 2].node, self.hose.centerNode, 0, 0, 0) }
    setTranslation(self.components[(table.getn(self.components) + 1) / 2].node, unpack(translation))

    --link(centerTargetNode, self.components[(table.getn(self.components) + 1) / 2].node)
    setWorldTranslation(centerTargetNode, unpack(centerTranslation))

    link(centerTargetNode, self.components[(table.getn(self.components) + 1) / 2].node)

    local endTranslation = reference.offsetDirection ~= 1 and { localToWorld(reference.node, 0, 0, -self.hose.length) } or { localToWorld(reference.node, 0, 0, self.hose.length) }

    -- setTranslation(self.components[grabPoints[2].componentIndex].node, unpack(endTranslation))

    -- Note: does offsetDirection have influence on the y rotation?
    -- Note: this is not going to work with world rotations
    local xRotOffset, yRotOffset, zRotOffset = unpack(reference.endRotOffset)
    local referenceRotation = { localRotationToLocal(self.components[grabPoints[2].componentIndex].node, grabPoints[2].node, xRotOffset, yRotOffset, zRotOffset) }
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
    local direction = { localDirectionToLocal(self.components[grabPoints[2].componentIndex].node, grabPoints[2].node, 0, 0, grabPoints[2].id > 1 and 1 or -1) } --grabPoints[2].id > 1 and -1 or 1
    local upVector = { localDirectionToLocal(self.components[grabPoints[2].componentIndex].node, grabPoints[2].node, 0, 1, 0) } -- grabPoints[1].id > 1 and -1 or 1

    setDirection(self.components[grabPoints[2].componentIndex].node, direction[1], direction[2], direction[3], upVector[1], upVector[2], upVector[3])

    local xOffset, yOffset, zOffset = unpack(reference.endTransOffset)
    local translation = { localToLocal(self.components[grabPoints[2].componentIndex].node, grabPoints[2].node, xOffset, yOffset, zOffset) }
    setTranslation(self.components[grabPoints[2].componentIndex].node, unpack(translation))
    setRotation(self.components[grabPoints[2].componentIndex].node, unpack(referenceRotation))

    --link(endTargetNode, self.components[grabPoints[2].componentIndex].node)
    setWorldTranslation(endTargetNode, unpack(endTranslation))

    link(endTargetNode, self.components[grabPoints[2].componentIndex].node)

    --grabPoints[1].jointIndex = LiquidManureHose:constructJoint(vehicle.components[reference.componentIndex].node, self.components[grabPoints[1].componentIndex].node, startTargetNode, startTargetNode, {1000, 1000, 1000}, {1000, 1000, 1000}, {1000, 1000, 1000}, {1000, 1000, 1000})
    --grabPoints[1].centerJointIndex = LiquidManureHose:constructJoint(vehicle.components[reference.componentIndex].node, self.components[(table.getn(self.components) + 1) / 2].node, centerTargetNode, centerTargetNode, {1000, 1000, 1000}, {1000, 1000, 1000}, {1000, 1000, 1000}, {1000, 1000, 1000})
    --grabPoints[2].jointIndex = LiquidManureHose:constructJoint(vehicle.components[reference.componentIndex].node, self.components[grabPoints[2].componentIndex].node, endTargetNode, endTargetNode, {1000, 1000, 1000}, {1000, 1000, 1000}, {1000, 1000, 1000}, {1000, 1000, 1000})

    -- delete(startTargetNode)
    -- delete(centerTargetNode)
    -- delete(endTargetNode)

    self.hose.parkStartTargetNode = startTargetNode
    self.hose.parkCenterTargetNode = centerTargetNode
    self.hose.parkEndTargetNode = endTargetNode

    -- for i, component in pairs(self.components) do
    -- if i ~= grabPoints[1].componentIndex and i ~= grabPoints[2].componentIndex then
    -- setPairCollision(vehicle.components[reference.componentIndex].node, component.node, false)
    -- end
    -- end

    if not reference.isObject then
        local currentVehicle = vehicle

        while currentVehicle ~= nil do
            currentVehicle:addToPhysics()
            currentVehicle = currentVehicle.attacherVehicle
        end
    end

    -- self:addToPhysics()

    if self.isServer then
        self:raiseDirtyFlags(self.vehicleDirtyFlag)
        vehicle:raiseDirtyFlags(vehicle.vehicleDirtyFlag)
    end
end

function LiquidManureHose:hardUnparkHose(grabPoints, vehicle, reference)
    if table.getn(grabPoints) < 2 then
        return
    end

    if not reference.isObject then
        vehicle:removeFromPhysics()
    end

    self:removeFromPhysics()

    setIsCompound(self.components[grabPoints[1].componentIndex].node, true)
    setIsCompound(self.components[(table.getn(self.components) + 1) / 2].node, true)
    setIsCompound(self.components[grabPoints[2].componentIndex].node, true)

    --
    local translation = { getWorldTranslation(self.components[grabPoints[1].componentIndex].node) }
    setTranslation(self.components[grabPoints[1].componentIndex].node, unpack(translation))

    local direction = { localDirectionToWorld(grabPoints[1].node, 0, 0, 1) }
    local upVector = { localDirectionToWorld(grabPoints[1].node, 0, 1, 0) }

    setDirection(self.components[grabPoints[1].componentIndex].node, direction[1], direction[2], direction[3], upVector[1], upVector[2], upVector[3])

    link(getRootNode(), self.components[grabPoints[1].componentIndex].node)
    --
    --
    local translation = { getWorldTranslation(self.components[(table.getn(self.components) + 1) / 2].node) }
    setTranslation(self.components[(table.getn(self.components) + 1) / 2].node, unpack(translation))

    local direction = { localDirectionToWorld(self.hose.centerNode, 0, 0, 1) }
    local upVector = { localDirectionToWorld(self.hose.centerNode, 0, 1, 0) }

    setDirection(self.components[(table.getn(self.components) + 1) / 2].node, direction[1], direction[2], direction[3], upVector[1], upVector[2], upVector[3])

    link(getRootNode(), self.components[(table.getn(self.components) + 1) / 2].node)
    --
    --
    local translation = { getWorldTranslation(self.components[grabPoints[2].componentIndex].node) }
    setTranslation(self.components[grabPoints[2].componentIndex].node, unpack(translation))

    local direction = { localDirectionToWorld(grabPoints[2].node, 0, 0, 1) }
    local upVector = { localDirectionToWorld(grabPoints[2].node, 0, 1, 0) }

    setDirection(self.components[grabPoints[2].componentIndex].node, direction[1], direction[2], direction[3], upVector[1], upVector[2], upVector[3])
    link(getRootNode(), self.components[grabPoints[2].componentIndex].node)
    --

    delete(self.hose.parkStartTargetNode)
    delete(self.hose.parkCenterTargetNode)
    delete(self.hose.parkEndTargetNode)

    if not reference.isObject then
        vehicle:addToPhysics()
    end

    self:addToPhysics()

    if self.isServer then
        self:raiseDirtyFlags(self.vehicleDirtyFlag)
    end
end

function LiquidManureHose:jointConnect(grabPoint, vehicle, reference)
    self:createConnectJoints(grabPoint, vehicle, reference)

    for _, component in pairs(self.components) do
        --if component.node ~= jointDesc.rootNodeBackup and not component.collideWithAttachables then
        setPairCollision(component.node, vehicle.rootNode, false)
        --end
    end

    if self.isServer then
    end
end

function LiquidManureHose:hardConnect(grabPoint, vehicle, reference)
    -- Note: cause we delete the connector vehicle from physics we have to attach it back later on
    -- Todo: delete only the connectorVehicle from physics, unlink and remove joints from that one hose when attaching an exentable hose
    local grabPoints = {}
    local connectableGrabPoints = {}

    for index, gp in pairs(self.grabPoints) do
        if gp.id ~= grabPoint.id and LiquidManureHose:isConnected(gp.attachState) then
            if gp.connectable or gp.connectorRef.connectable then
                --gp.connectorVehicle:hardDisconnect(gp, gp.connectorVehicle, gp.connectorRef)
            end

            table.insert(grabPoints, gp)
        end
    end

    if grabPoint.connectable or reference.connectable then
        if vehicle.grabPoints ~= nil then
            for index, gp in pairs(vehicle.grabPoints) do
                if LiquidManureHose:isConnected(gp.attachState) and (gp.connectable or gp.connectorRef.connectable) then
                    print('Vehicle has one connected gp index = ' .. index)
                    print('gp.connectable = ' .. tostring(gp.connectable))
                    --detach(index, state, vehicle, referenceId, isExtendable, noEventSend)
                    table.insert(connectableGrabPoints, { index = gp.id, vehicle = gp.connectorVehicle, referenceId = gp.connectorRef.id })
                    --vehicle:detach(gp.id, nil, gp.connectorVehicle, gp.connectorRef.id, true, true)
                    --vehicle:hardDisconnect(gp, gp.connectorVehicle, gp.connectorRef)
                end
            end
        end
    end

    print("component id of grabPoint before doing something with physics = " .. grabPoint.componentIndex)
    print("connectedGrabPoints before doing something with physics = " .. table.getn(grabPoints))


    -- we always completely delete
    self:removeFromPhysics()

    if self.isServer then
        for _, componentJoint in pairs(self.componentJoints) do
            if componentJoint.hoseJointIndex ~= 0 and componentJoint.hoseJointIndex ~= nil then
                removeJoint(componentJoint.hoseJointIndex)
                componentJoint.hoseJointIndex = 0
            end
        end
    end

    -- self:removeFromPhysicsFromReference(grabPoint, grabPoints)

    -- if not grabPoint.connectable and not reference.connectable and table.getn(grabPoints) > 0 then
    -- self:removeFromPhysicsPartly(grabPoints)
    -- else
    -- print('we completly remove')
    -- self:removeFromPhysics()
    -- end
    --self:removeFromPhysics()

    for index, gp in pairs(connectableGrabPoints) do
        gp.vehicle:removeFromPhysics()
    end

    if not reference.isObject then
        local currentVehicle = vehicle

        while currentVehicle ~= nil do
            currentVehicle:removeFromPhysics()
            currentVehicle = currentVehicle.attacherVehicle
        end

        --setIsCompound(vehicle.components[reference.componentIndex].node, true)

        if not grabPoint.connectable and not reference.connectable then
            setIsCompoundChild(self.components[grabPoint.componentIndex].node, true)
        end
    end

    -- Todo: is this really needed?
    -- LiquidManureHose:orientConnectionJoint(grabPoint.connectorRef.node, grabPoint.node, index, grabPoint.connectable, grabPoint.connectorRef.id, isExtendable)

    -- local trans = {getTranslation(grabPoint.connectorRef.node)}
    -- LiquidManureHose:orientConnectionJoint(grabPoint.connectorRef.node, self.components[grabPoint.componentIndex].node, index, grabPoint.connectable, grabPoint.connectorRef.id, isExtendable)
    local linkComponent = function(vehicle, grabPoint, reference)
        local moveDir = grabPoint.id > 1 and -1 or 1
        moveDir = (grabPoint.connectable or reference.connectable) and (moveDir > 0 and (reference.id > 1 and 1 or -1) or -1) or moveDir
        local direction = { localDirectionToLocal(vehicle.components[grabPoint.componentIndex].node, grabPoint.node, 0, 0, moveDir) }
        local upVector = { localDirectionToLocal(vehicle.components[grabPoint.componentIndex].node, grabPoint.node, 0, grabPoint.id > 1 and -1 or 1, 0) }

        setDirection(vehicle.components[grabPoint.componentIndex].node, direction[1], direction[2], direction[3], upVector[1], upVector[2], upVector[3])

        local translation = { localToLocal(vehicle.components[grabPoint.componentIndex].node, grabPoint.node, 0, 0, 0) }
        setTranslation(vehicle.components[grabPoint.componentIndex].node, unpack(translation))

        link(reference.node, vehicle.components[grabPoint.componentIndex].node)
    end

    linkComponent(self, grabPoint, reference)

    --for index, gp in pairs(connectableGrabPoints) do
    --print(gp.vehicle.grabPoints[gp.referenceId].node)
    --print(vehicle.components[vehicle.grabPoints[gp.index].componentIndex].node)
    --unlink(vehicle.components[vehicle.grabPoints[gp.index].componentIndex].node)
    --link(gp.vehicle.grabPoints[gp.referenceId].node, vehicle.components[vehicle.grabPoints[gp.index].componentIndex].node)
    --linkComponent(vehicle, vehicle.grabPoints[gp.index], gp.vehicle.grabPoints[gp.referenceId])
    --end

    if not grabPoint.connectable and not reference.connectable then
        self:addToPhysicsPartly(grabPoint, grabPoints, vehicle, reference, true)
    else
        self:addToPhysics()
    end

    for index, gp in pairs(connectableGrabPoints) do
        gp.vehicle:addToPhysics()
    end

    -- self:addToPhysics()

    if not reference.isObject then
        local currentVehicle = vehicle

        while currentVehicle ~= nil do
            currentVehicle:addToPhysics()
            currentVehicle = currentVehicle.attacherVehicle
        end
    end

    --for index, gp in pairs(connectableGrabPoints) do
    --gp.vehicle:addToPhysics()
    --		if gp.connectable or gp.connectorRef.connectable then
    --			gp.connectorVehicle:createConnectJoints(gp, gp.connectorVehicle, gp.connectorRef)
    --		end
    --end

    self:createConnectJoints(grabPoint, vehicle, reference)

    for index, gp in pairs(connectableGrabPoints) do
        vehicle:createConnectJoints(vehicle.grabPoints[gp.index], gp.vehicle, gp.vehicle.grabPoints[gp.referenceId])
    end

    if self.isServer then
        self:raiseDirtyFlags(self.vehicleDirtyFlag)
    end

    -- if not reference.isObject then
    -- vehicle:raiseDirtyFlags(vehicle.vehicleDirtyFlag)
    -- end

    -- for i, component in pairs(self.components) do
    -- if i ~= grabPoint.componentIndex then
    -- setPairCollision(grabPoint.connectorVehicle.components[grabPoint.connectorRef.componentIndex].node, component.node, false)
    -- end
    -- end
end

function LiquidManureHose:hardDisconnect(grabPoint, vehicle, reference)
    --simulatePhysics(false) -- stop physics for wheel shapes

    local grabPoints = {}

    for index, gp in pairs(self.grabPoints) do
        if gp.id ~= grabPoint.id and LiquidManureHose:isConnected(gp.attachState) then
            --self:hardDisconnect(gp, gp.connectorVehicle, gp.connectorRef)
            table.insert(grabPoints, gp)
        end
    end

    print("HARDISCONNECT - id = " .. grabPoint.id)
    print("HARDISCONNECT - component id of grabPoint before doing something with physics = " .. grabPoint.componentIndex)
    print("HARDISCONNECT - connectedGrabPoints before doing something with physics = " .. table.getn(grabPoints))

    self:removeConnectOrParkJoints(grabPoint)

    self:removeFromPhysics()
    if self.isServer then
        for _, componentJoint in pairs(self.componentJoints) do
            if componentJoint.hoseJointIndex ~= 0 and componentJoint.hoseJointIndex ~= nil then
                removeJoint(componentJoint.hoseJointIndex)
                componentJoint.hoseJointIndex = 0
            end
        end
    end
    -- if table.getn(grabPoints) > 0 and not grabPoint.connectable and not reference.connectable then
    -- self:removeFromPhysicsPartly(grabPoints)
    -- else
    -- if self.isServer then
    -- for _, componentJoint in pairs(self.componentJoints) do
    -- removeJoint(componentJoint.jointIndex)
    -- end
    -- end

    -- self:removeFromPhysics()
    -- end

    if not reference.isObject then
        local currentVehicle = vehicle

        while currentVehicle ~= nil do
            currentVehicle:removeFromPhysics()
            currentVehicle = currentVehicle.attacherVehicle
        end
    end

    setIsCompound(self.components[grabPoint.componentIndex].node, true)
    -- setIsCompoundChild(self.components[grabPoint.componentIndex].node, true)

    -- local translation = {getWorldTranslation(self.components[grabPoint.componentIndex].node)}
    -- setTranslation(self.components[grabPoint.componentIndex].node, unpack(translation))

    -- local moveDir = grabPoint.id > 1 and -1 or 1
    -- moveDir = (grabPoint.connectable or reference.connectable) and (moveDir > 0 and (reference.id > 1 and 1 or -1) or -1) or moveDir
    -- local direction = {localDirectionToWorld(grabPoint.node, 0, 0, 1)}
    -- local upVector = {localDirectionToWorld(grabPoint.node, 0, 1, 0)}

    -- setDirection(self.components[grabPoint.componentIndex].node, direction[1], direction[2], direction[3], upVector[1], upVector[2], upVector[3])

    -- link(getRootNode(), self.components[grabPoint.componentIndex].node)

    local translation = { getWorldTranslation(self.components[grabPoint.componentIndex].node) }
    setTranslation(self.components[grabPoint.componentIndex].node, unpack(translation))

    local direction = { localDirectionToWorld(self.rootNode, 0, 0, 1) }
    local upVector = { localDirectionToWorld(self.rootNode, 0, 1, 0) }

    setDirection(self.components[grabPoint.componentIndex].node, direction[1], direction[2], direction[3], upVector[1], upVector[2], upVector[3])
    link(getRootNode(), self.components[grabPoint.componentIndex].node)

    if not reference.isObject then
        local currentVehicle = vehicle

        while currentVehicle ~= nil do
            currentVehicle:addToPhysics()
            currentVehicle = currentVehicle.attacherVehicle
        end

        -- whenever the vehicle is an extenable hose
        if reference.connectable then
            setIsCompound(vehicle.components[reference.componentIndex].node, true)
        end
    end

    if table.getn(grabPoints) > 0 and not grabPoint.connectable and not reference.connectable then
        self:addToPhysicsPartly(grabPoint, grabPoints, vehicle, reference, false)
    else
        if self.isServer then
            for _, componentJoint in pairs(self.componentJoints) do
                if componentJoint.hoseJointIndex ~= 0 and componentJoint.hoseJointIndex ~= nil then
                    removeJoint(componentJoint.hoseJointIndex)
                    componentJoint.hoseJointIndex = 0
                end
            end
        end

        print("HARDISCONNECT - We completly reset")
        -- self.componentJoints = self.originalComponentJoints
        -- self:addToPhysics()	-- add all whats not added
        -- self:removeFromPhysics() -- remove the complete hose
        self:addToPhysics() -- add it back
    end

    --self:addToPhysics()

    -- for index, gp in pairs(grabPoints) do
    -- --self:hardConnect(gp, gp.connectorVehicle, gp.connectorRef)

    -- if not gp.connectorRef.isObject and gp.connectorVehicle ~= nil then
    -- gp.connectorVehicle:raiseDirtyFlags(gp.connectorVehicle.vehicleDirtyFlag)
    -- end
    -- end

    -- local endIndex = grabPoint.id > 1 and 1 or table.getn(self.grabPoints)
    -- self:updateComponentJointMovement(endIndex, true)

    if self.isServer then
        self:raiseDirtyFlags(self.vehicleDirtyFlag)
    end

    -- if not reference.isObject then
    -- vehicle:raiseDirtyFlags(vehicle.vehicleDirtyFlag)
    -- end
end

function LiquidManureHose:createConnectJoints(grabPoint, vehicle, reference)
    if self.isServer then
        if grabPoint ~= nil and vehicle ~= nil and reference ~= nil then
            -- local jointDesc = self.hose.componentJoints[grabPoint.id][1]
            -- self:createComponentJoint(self.components[jointDesc.componentIndices[1]], self.components[jointDesc.componentIndices[2]], jointDesc)

            -- grabPoint.centerJointIndex = LiquidManureHose:constructJoint(self.components[(table.getn(self.components) + 1) / 2].node, vehicle.components[reference.componentIndex].node, reference.node, reference.node, 40, 0, 0, 0)
            local jointDesc = {
                actor1 = vehicle.components[reference.componentIndex].node,
                actor2 = self.components[grabPoint.componentIndex].node,
                anchor1 = reference.node,
                anchor2 = reference.node,
                isConnector = true
            }

            grabPoint.jointIndex = LiquidManureHose:constructConnectorJoint(jointDesc)

            -- for i, component in pairs(self.components) do
            -- if i ~= grabPoint.componentIndex then
            -- setPairCollision(grabPoint.connectorVehicle.components[grabPoint.connectorRef.componentIndex].node, component.node, false)
            -- end
            -- end
        end
    end
end

function LiquidManureHose:addToPhysicsFromReference(grabPoint, grabPoints, reset)
    -- we only add the components that not at the reference.
    -- if more grabPoints are connected we don't add anything
    local connectedCount = table.getn(grabPoints)

    if not reset then
        if connectedCount > 0 then
            print('HoseSystem | addToPhysicsFromReference - We dont add anything')
        else
            for i, component in pairs(self.components) do
            end
        end
    end

    print('HoseSystem | addToPhysicsFromReference - We fully reset')
    self:addToPhysics()

    return self.isAddedToPhysics
end

function LiquidManureHose:removeFromPhysicsFromReference(grabPoint, grabPoints)
    local connectedCount = table.getn(grabPoints)

    if connectedCount > 0 and not grabPoint.connectable and not grabPoint.connectorRef.connectable then
        for i, component in pairs(self.components) do
            local removeFromPhysics = true

            if connectedCount > 0 then
                for index = 1, connectedCount do
                    local grabPoint = grabPoints[index]

                    if grabPoint.componentIndex == i then
                        removeFromPhysics = not removeFromPhysics
                        break
                    end
                end
            end

            if removeFromPhysics then
                print('HoseSystem | removeFromPhysicsFromReference - We only remove component ' .. i .. ' from physics')
            end
        end

        if self.isServer then
            for _, componentJoint in pairs(self.componentJoints) do
                componentJoint.jointIndex = 0
            end
        end

        return true
    end

    print('HoseSystem | removeFromPhysicsFromReference - We fully remove')
    self:removeFromPhysics()

    return true
end

function LiquidManureHose:addToPhysicsPartly(grabPoint, connectedGrabPoints, vehicle, reference, isConnecting)
    if not self.isAddedToPhysics then
        for i, component in pairs(self.components) do
            -- todo: check what to add.. both sides can be attached so only the middle component needs to be added!
            local toPhysics = true

            if i ~= grabPoint.componentIndex then
                if table.getn(connectedGrabPoints) > 0 then
                    for index, gp in pairs(connectedGrabPoints) do
                        if i == gp.componentIndex then
                            toPhysics = false
                            break
                        end
                    end

                    if isConnecting then
                        if i == (table.getn(self.components) + 1) / 2 then
                            toPhysics = false
                        end
                    end
                end
            else
                if isConnecting then
                    toPhysics = false
                end
            end

            if toPhysics then
                print('We only add component ' .. i .. ' to physics')
                addToPhysics(component.node)
            end
        end

        -- self.isAddedToPhysics = true

        if self.isServer then
            -- Note: reference and vehicle are dependent
            local createCustomJoint = function(i, jointDesc, vehicle, reference)
                jointDesc.jointNode = reference.node

                local rot = { localRotationToLocal(jointDesc.jointNode, self.components[jointDesc.componentIndices[i > 1 and 1 or 2]].node, 0, 0, 0) }
                local trans = { localToLocal(jointDesc.jointNode, self.components[jointDesc.componentIndices[i > 1 and 1 or 2]].node, 0, 0, 0) }

                jointDesc.jointLocalPoses[1] = { trans = trans, rot = rot }

                -- self:createComponentJoint(self.components[jointDesc.componentIndices[1]], vehicle.components[reference.componentIndex], jointDesc)
                jointDesc.hoseJointIndex = LiquidManureHose:constructConnectorJoint({
                    actor1 = self.components[jointDesc.componentIndices[i > 1 and 1 or 2]].node,
                    actor2 = vehicle.components[reference.componentIndex].node,
                    anchor1 = jointDesc.jointNode,
                    anchor2 = jointDesc.jointNode,
                    isConnector = false
                })

                -- self.componentJoints[i] = jointDesc
            end

            if isConnecting then
                if table.getn(connectedGrabPoints) > 0 then
                    table.insert(connectedGrabPoints, grabPoint)
                end
            end

            --DebugUtil.printTableRecursively(connectedGrabPoints)

            for i, componentJoint in pairs(self.componentJoints) do
                if table.getn(connectedGrabPoints) > 0 then
                    local customJointDesc = self.hose.componentJoints[connectedGrabPoints[1].id][i]
                    --
                    -- we create custom joints from reference to center on both sides
                    --
                    if isConnecting then
                        --createCustomJoint(i, customJointDesc, connectedGrabPoints[i].connectorVehicle, connectedGrabPoints[i].connectorRef)
                    else
                        if i > 1 then
                            print('this is for creating the other side')
                            createCustomJoint(i, customJointDesc, connectedGrabPoints[1].connectorRef.isObject and connectedGrabPoints[1].connectorVehicle.hoseSystemParent or connectedGrabPoints[1].connectorVehicle, connectedGrabPoints[1].connectorRef) -- Note: we take the vehicle and reference from the grabPoint that is still connected
                        else
                            self:createComponentJoint(self.components[customJointDesc.componentIndices[1]], self.components[customJointDesc.componentIndices[2]], customJointDesc)
                        end
                    end
                else
                    local customJointDesc = self.hose.componentJoints[grabPoint.id][i]

                    --
                    -- we create 1 custom joint from reference to center and one default component joint from center to end
                    --
                    if i > 1 then
                        -- this is the index thats normally combines the two components but now we connect it to the reference.
                        createCustomJoint(i, customJointDesc, reference.isObject and vehicle.hoseSystemParent or vehicle, reference) -- Note: we take the current vehicle and reference from the grabPoint that we handle
                    else
                        self:createComponentJoint(self.components[customJointDesc.componentIndices[1]], self.components[customJointDesc.componentIndices[2]], customJointDesc)
                    end
                end
            end
        end

        for _, collisionPair in pairs(self.collisionPairs) do
            setPairCollision(collisionPair.component1.node, collisionPair.component2.node, collisionPair.enabled);
        end
    end
end

-- implement isConnecting boolean
function LiquidManureHose:removeFromPhysicsPartly(connectedGrabPoints, isConnecting)
    for i, component in pairs(self.components) do
        -- todo: check what to remove.. (like if not removed already)
        local fromPhysics = true

        if table.getn(connectedGrabPoints) > 0 then
            for index, gp in pairs(connectedGrabPoints) do
                if i == gp.componentIndex then -- these are removed already
                    fromPhysics = false
                    break
                end
            end
        end

        if fromPhysics then
            print('We only remove component ' .. i .. ' from physics')
            removeFromPhysics(component.node)
        end
    end

    if self.isServer then
        for _, componentJoint in pairs(self.componentJoints) do
            --removeJoint(componentJoint.jointIndex)
            componentJoint.jointIndex = 0
        end
    end

    self.isAddedToPhysics = false
end

function LiquidManureHose:removeConnectOrParkJoints(grabPoint)
    if self.isServer then
        if grabPoint.jointIndex ~= 0 then
            print('we remove it')
            removeJoint(grabPoint.jointIndex)
        end

        if grabPoint.centerJointIndex ~= 0 then
            removeJoint(grabPoint.centerJointIndex)
        end
    end

    grabPoint.jointIndex = 0
    grabPoint.centerJointIndex = 0

    setTranslation(grabPoint.node, unpack(grabPoint.nodeOrgTrans))
    setRotation(grabPoint.node, unpack(grabPoint.nodeOrgRot))

    -- Todo: Whats this about?
    -- if grabPoint.connectorRef ~= nil then
    -- if grabPoint.connectable or grabPoint.connectorRef.connectable then
    -- if grabPoint.connectorRef.connectorRef ~= nil then -- Todo: test this!
    -- removeJoint(grabPoint.connectorRef.connectorRef.jointIndex)
    -- grabPoint.connectorRef.connectorRef = nil
    -- grabPoint.connectorRef.connectorVehicle = nil
    -- end
    -- end
    -- end
end

function LiquidManureHose:updateComponentJointMovement(index, force)
    if self.isServer then
        if index ~= self.hose.lastComponentJointGrabPoint or force then
            local grabPoint = self.grabPoints[index]

            if grabPoint ~= nil then
                local allowUpdate = true

                for index, gp in pairs(self.grabPoints) do
                    if gp.id ~= grabPoint.id and LiquidManureHose:isConnected(gp.attachState) then
                        allowUpdate = false
                        break
                    end
                end

                if allowUpdate then
                    for i, componentJoint in pairs(self.componentJoints) do
                        if componentJoint.jointIndex ~= 0 then
                            removeJoint(componentJoint.jointIndex)
                            componentJoint.jointIndex = 0
                        end

                        local jointDesc = self.hose.componentJoints[index][i]

                        self:createComponentJoint(self.components[jointDesc.componentIndices[1]], self.components[jointDesc.componentIndices[2]], jointDesc)

                        self.componentJoints[i] = jointDesc
                    end

                    self.hose.lastComponentJointGrabPoint = index
                end
            end
        end
    end
end

---
-- @param force
--
function LiquidManureHose:updateHose(force)
    local js = self.jointSpline

    -- controllers
    local p0 = { localToWorld(self.components[1].node, -js.curveControllerTrans[1], -js.curveControllerTrans[2], -js.curveControllerTrans[3]) } -- controller 1
    local p1 = { getWorldTranslation(self.components[1].node) } -- start
    local p2 = { getWorldTranslation(self.components[js.endComponentId].node) } -- end
    local p3 = { localToWorld(self.components[js.endComponentId].node, js.curveControllerTrans[1], js.curveControllerTrans[2], js.curveControllerTrans[3]) } -- controller 2

    local movedDistance1 = Utils.vector3Length(p1[1] - js.lastPosition[1][1], p1[2] - js.lastPosition[1][2], p1[3] - js.lastPosition[1][3])
    local movedDistance2 = Utils.vector3Length(p2[1] - js.lastPosition[2][1], p2[2] - js.lastPosition[2][2], p2[3] - js.lastPosition[2][3])

    if movedDistance1 > 0.001 or movedDistance2 > 0.001 or force then
        -- print("force " .. tostring(force) .. " distance " .. movedDistance1 .. " - " .. movedDistance2)

        js.lastPosition[1] = p1
        js.lastPosition[2] = p2

        for i = 1, js.numJoints do
            if i <= js.numJoints then
                local t = (i - 1) / (js.numJoints - 1)
                local x = LiquidManureHose:catmullRomSpline(t, p0[1], p1[1], p2[1], p3[1])
                local y = LiquidManureHose:catmullRomSpline(t, p0[2], p1[2], p2[2], p3[2])
                local z = LiquidManureHose:catmullRomSpline(t, p0[3], p1[3], p2[3], p3[3])
                local trans = { worldToLocal(self.hoseJoints[i].parent, x, y, z) }

                setTranslation(self.hoseJoints[i].node, unpack(trans))

                local target = i < js.numJoints and { getWorldTranslation(self.hoseJoints[i + 1].node) } or { localToWorld(self.components[js.endComponentId].node, 0, 0, 1) } -- if true -> target is 1 "trans" in Z axis infront of component.

                if target ~= nil then
                    local base = { getWorldTranslation(self.hoseJoints[i].node) }
                    local direction = { target[1] - base[1], target[2] - base[2], target[3] - base[3] }

                    if (dirX ~= 0 or dirY ~= 0 or dirZ ~= 0) then
                        local upVector = { localDirectionToWorld(self.hoseJoints[i].parent, 0, 1, 0) }
                        Utils.setWorldDirection(self.hoseJoints[i].node, direction[1], direction[2], direction[3], upVector[1], upVector[2], upVector[3])
                    end
                end
            end
        end
    end

    if LiquidManureHose.debug then
        -- debug curve line
        local tableNum = 150 -- more = closer between dots

        for i = 1, tableNum do
            local t = (i - 1) / tableNum
            local x = LiquidManureHose:catmullRomSpline(t, p0[1], p1[1], p2[1], p3[1])
            local y = LiquidManureHose:catmullRomSpline(t, p0[2], p1[2], p2[2], p3[2])
            local z = LiquidManureHose:catmullRomSpline(t, p0[3], p1[3], p2[3], p3[3])

            drawDebugPoint(x, y, z, 0, 1, 1, 1)
        end

        -- draw line to target joint, to show what angle we have.
        for i = 1, js.numJoints do
            local distance = js.length / js.numJoints
            local dot = { localToWorld(self.hoseJoints[i].node, 0, 0, distance) }
            local dot2 = { localToWorld(self.hoseJoints[i].node, 0, 0, 0) }
            drawDebugLine(dot[1], dot[2], dot[3], 1, 0, 0, dot2[1], dot2[2], dot2[3], 0, 1, 0)
            drawDebugPoint(dot[1], dot[2], dot[3], 1, 0, 0, 1)
            drawDebugPoint(dot2[1], dot2[2], dot2[3], 0, 1, 0, 1)
        end
    end
end

---
-- @param t
-- @param p0
-- @param p1
-- @param p2
-- @param p3
--
function LiquidManureHose:catmullRomSpline(t, p0, p1, p2, p3)
    return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t ^ 2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t ^ 3)
end

---
-- @param jointDesc
-- @param playerHoseDesc
--
function LiquidManureHose:constructPlayerJoint(jointDesc, playerHoseDesc)
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
function LiquidManureHose:onGrabJointBreak(jointIndex, breakingImpulse)
    --if self.isServer then
    if jointIndex == g_currentMission.player.hose.jointIndex then
        g_currentMission.player.activeTool:drop(g_currentMission.player.activeToolLocationId, g_currentMission.player)
    end
    --end

    return false
end

---
-- @param jointDesc
--
function LiquidManureHose:constructConnectorJoint(jointDesc)
    local constructor = JointConstructor:new()

    constructor:setActors(jointDesc.actor1, jointDesc.actor2)
    constructor:setJointTransforms(jointDesc.anchor1, jointDesc.anchor2)
    constructor:setEnableCollision(false)

    local rotLimitSpring = {0, 0, 0}
    local rotLimitDamping = {0, 0, 0}
    local transLimitSpring = {0, 0, 0}
    local translimitDamping = {0, 0, 0}

    if jointDesc.isConnector then
        local connectorMass = getMass(jointDesc.actor1) * 100 -- create a strong joint

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
            constructor:setRotationLimit(i, rotLimitSpring[i + 1] + 1, rotLimitSpring[i + 1])
        end

        constructor:setTranslationLimit(i, true, 0, 0)
    end

--    if isRefAttacher ~= nil and isRefAttacher then
--        constructor:setRotationLimitForceLimit(10000000, 10000000, 10000000)
--        constructor:setTranslationLimitForceLimit(10000000, 10000000, 10000000)
--    end

    return constructor:finalize()
end

---
-- @param node
-- @param node2
-- @param forceTrans
-- @param forceMirror
-- @param isConnector
-- @param playerRot
-- @param index
--
function LiquidManureHose:orientJoint(node, node2, forceTrans, forceMirror, isConnector, playerRot, index)
    local x, y, z = getRotation(node)

    if playerRot ~= nil then
        y = playerRot
    end

    local rot = { x, y, z }

    --    local transc = {worldToLocal(node2, x, y, z)}

    if forceTrans then
        local trans = { getTranslation(node) }
        setTranslation(node2, unpack(trans))
    end

    if forceMirror then
        rot[1] = (rot[1] > 0 and rot[1] * 1 or rot[1] < 0 and -rot[1] * 1 or 0)
        rot[2] = (rot[2] > 0 and rot[2] * 1 or rot[2] < 0 and -rot[2] * 1 or 0)
        rot[3] = (rot[3] > 0 and rot[3] * 1 or rot[3] < 0 and -rot[3] * 1 or 0)
    end

    if isConnector then
        local rot2 = { getRotation(node2) }
        rot[2] = (index > 1 and math.rad(180) or math.rad(0))
    end

    setRotation(node2, unpack(rot))

    --    local upX = dx
    --    local upY = math.cos(rad) * dy - math.sin(rad) * dz
    --    local upZ = math.sin(rad) * dy + math.cos(rad) * dz
    --
    --    setDirection(node2, dx, dy, dz, upX, upY, upZ)
end

---
-- @param node
-- @param node2
-- @param index
-- @param isConnector
-- @param index2
-- @param isRefConnector
--
function LiquidManureHose:orientConnectionJoint(node, node2, index, isConnector, index2, isRefConnector)
    local rot = { getRotation(node) }

    if isRefConnector then
        -- depends on what side we are working with..
        if index > 1 then
            setTranslation(node2, 0, 0, -0.07)
        else
            setTranslation(node2, 0, 0, 0)
        end

        -- TODO: Rotate when we are the connectable hose
        if isConnector then
            -- We need to know the target index to calculate the correct rotation here!
            rot[2] = index2 > 1 and math.rad(0) or math.rad(180)
        else
            rot[2] = index > 1 and math.rad(0) or math.rad(180)
        end
    else
        rot[2] = index > 1 and math.rad(180) or math.rad(0)
    end

    setRotation(node2, unpack(rot))
end

---
-- @param cond
-- @param trueValue
-- @param falseValue
--
function LiquidManureHose:ternary(cond, trueValue, falseValue)
    if cond then return trueValue else return falseValue end
end

---
-- @param j1
-- @param j2
--
function LiquidManureHose:calculateCosAngle(j1, j2)
    local x1, y1, z1 = localDirectionToWorld(j1, 1, 0, 0)
    local x2, y2, z2 = localDirectionToWorld(j2, 1, 0, 0)

    return x1 * x2 + y1 * y2 + z1 * z2
end

function LiquidManureHose:canExtendHoseSytem(inverse, node1, node2)
    local rot = math.abs(Utils.getYRotationBetweenNodes(node1, node2))

    if inverse then
        return LiquidManureHose:round(rot, 1) <= 0.6
    end

    return LiquidManureHose:round(rot, 1) >= 2.3
end

function LiquidManureHose:canConnectHoseSystem()
end

---
-- @param number
-- @param idp
--
function LiquidManureHose:round(number, idp)
    local multiplier = 10 ^ (idp or 0)
    return math.floor(number * multiplier + 0.5) / multiplier
end

---
-- @return bool
--
function LiquidManureHose:isPlayer()
    return g_currentMission.controlPlayer and g_currentMission.player ~= nil and g_gui.currentGui == nil and not g_currentMission.isPlayerFrozen and not g_currentMission.player.hasHPWLance and g_currentMission.player.currentTool == nil and not g_currentMission.player.isCarryingObject
end

function LiquidManureHose:setHandNodes(handNode, targetNode, node)
    link(handNode, targetNode)

    --player.hose.currentHandNode = player.toolsHandRightNode

    setRotation(targetNode, getRotation(node))

    -- local x, y, z = getWorldTranslation(node)
    -- x, y, z = worldToLocal(getParent(targetNode), x, y, z)
    -- local a, b, c = getTranslation(targetNode)

    local x, y, z = getTranslation(node)

    setTranslation(targetNode, x, y, z)
    print('other clients should see the link for the handNode');
end

---
-- @param index
-- @param bool
--
function LiquidManureHose:syncIsUsed(index, bool, isExtendable, noEventSend)
    local grabPoint = self.grabPoints[index]

    -- Note: what do we really need to know on a grabPoint?
    -- # The reference
    -- # The vehicle that connects
    -- # attachstate
    -- # hasJointIndex ? what about those? Should be differently used
    -- # hasExtenableJointIndex ? what about those? Should be differently used
    -- #
    -- #
    -- Execptions:
    -- When it's a reference and not extenable hose send more data:
    -- # set reference.liquidManureHose on reference (self)

    if grabPoint ~= nil then
        local vehicle = grabPoint.connectorVehicle
        local reference = grabPoint.connectorRef

        if vehicle ~= nil and reference ~= nil then
            if not isExtendable and not reference.connectable then -- if not a connectable hose send more data
                reference.grabPoints = bool and self.grabPoints or nil
                reference.liquidManureHose = bool and self or nil
            end

            if reference.isObject then
                if self.isServer then -- we call on a object reference
                    vehicle.hoseSystemParent:setIsUsed(reference.id, bool)
                end
            else
                if reference.connectable ~= nil then -- we call on a extenable hose
                    vehicle:setIsUsed(reference.id, bool, false, false)
                else -- we call on a vehicle reference
                    vehicle:setIsUsed(reference.id, bool)
                end
            end
        end
    end

    -- Todo: what if we detach? Set it back man!
    self:setIsUsed(index, bool, bool, isExtendable, noEventSend)
end

---
-- @param index
-- @param isConnected
-- @param hasJointIndex
-- @param hasExtenableJointIndex
-- @param noEventSend
--
function LiquidManureHose:setIsUsed(index, isConnected, hasJointIndex, hasExtenableJointIndex, noEventSend)
    local grabPoint = self.grabPoints[index]

    -- NOTE: do this on the connectorVehicle!! We are losing reference if we do it like this.
    if grabPoint ~= nil then
        -- local vehicle = grabPoint.connectorVehicle

        -- if vehicle.grabPoints ~= nil then
        -- local refGrabPoint = vehicle.grabPoints[grabPoint.connectorRef.id]

        -- refGrabPoint.attachState = bool and LiquidManureHose.states.connected or LiquidManureHose.states.detached
        -- print('the target grabPoint attachState = ' .. refGrabPoint.attachState)
        -- end
        grabPoint.attachState = isConnected and LiquidManureHose.states.connected or LiquidManureHose.states.detached
        grabPoint.hasJointIndex = hasJointIndex
        grabPoint.hasExtenableJointIndex = hasExtenableJointIndex

        -- if grabPoint.connectorRef ~= nil then
        -- grabPoint.connectorRef.attachState = bool and LiquidManureHose.states.connected or LiquidManureHose.states.detached
        -- print('We are a connector and attachState: ' .. tostring(grabPoint.connectorRef.attachState))
        -- end
    end

    if not noEventSend then
        liquidManureHoseIsUsedEvent.sendEvent(self, index, isConnected, hasJointIndex, hasExtenableJointIndex, noEventSend)
    end
end

function LiquidManureHose:toggleLock(shouldLock, noEventSend)
    local dir = shouldLock and -1 or 1

    self:playAnimation(LiquidManureHose.animations.connect, dir, nil, true)

    liquidManureHoseToggleLockEvent.sendEvent(self, shouldLock, noEventSend)
end

---
-- @param index
-- @param state
-- @param player
-- @param noEventSend
--
function LiquidManureHose:setOwner(index, state, player, noEventSend)
    liquidManureHoseSetOwnerEvent.sendEvent(self, index, state, player, noEventSend)

    local grabPoint = self.grabPoints[index]

    if grabPoint ~= nil then
        grabPoint.isOwned = state
        grabPoint.currentOwner = (state and player ~= nil) and player or nil
    end

    -- PlayerInRangeTool
    if player ~= nil then
        player.activeTool = state and self or nil
        player.activeToolLocationId = state and index or nil
    end
end

---
-- @return self.hose.playerHoseOwner
function LiquidManureHose:getOwner(index)
    local grabPoint = self.grabPoints[index]

    if grabPoint ~= nil then
        return grabPoint.currentOwner
    end

    return nil
end

function LiquidManureHose:updateOwnerInputParts(index, isGrab, isControlling)
    local grabPoint = self.grabPoints[index]

    if grabPoint ~= nil then
        local player = self:getOwner(index)

        if player ~= nil and player ~= g_currentMission.player then
            -- if player.animCharSet ~= 0 then
            -- assignAnimTrackClip(player.animCharSet, Player.TRACK_WALK, isGrab and player.walkChainsawAnimClipIndex or player.walkAnimClipIndex)
            -- assignAnimTrackClip(player.animCharSet, Player.TRACK_IDLE, isGrab and player.idleChainsawAnimClipIndex or player.idleAnimClipIndex)
            -- end

            player:setWoodWorkVisibility(isGrab, false)

            if not isGrab then
                player.walkingIsLocked = false

                -- if player.backupTools ~= nil then
                -- player.tools = player.backupTools
                -- player.backupTools = nil
                -- end

                if self.targets ~= nil then
                    for ikChainId, target in pairs(self.targets) do
                        IKUtil.setTarget(player.ikChainsById, ikChainId, nil)
                    end
                end
            else
                -- Not needed anymore
                -- if player.tools ~= nil then
                -- if table.getn(player.tools) > 0 then
                -- player.backupTools = player.tools

                -- if player.currentTool ~= nil then
                -- -- player:setTool(nil)
                -- player:setToolById(0, true)
                -- end

                -- -- Set empty table because default functions aren't checked on nil values...
                -- player.tools = {}
                -- end
                -- end

                if self.targets ~= nil then
                    for ikChainId, target in pairs(self.targets) do
                        IKUtil.setTarget(player.ikChainsById, ikChainId, target)
                    end

                    if player.meshFirstPerson ~= nil then
                        setVisibility(player.meshFirstPerson, true)
                    end

                    player:setIKDirty()
                end
            end

            if not isControlling then
                --local node = clone(self.hose.node, true, false, true)

                if player.hose ~= nil and player.hose.node ~= nil then
                    --p rint('======> link hand to hose')
                    -- TODO: move this to a function and lets it be handled by the player setHandNode function! Override needed!
                    link(player.toolsHandRightNode, player.hose.node)

                    -- local x,y,z = getWorldTranslation(grabPoint.node)
                    -- x,y,z = worldToLocal(player.hose.node, x,y,z)
                    -- local a,b,c = getTranslation(player.hose.node)
                    -- setTranslation(player.hose.node, a-x,b-y,c-z)

                    setTranslation(player.hose.node, 0, 0, 0) -- graphicsRootNode
                    setRotation(player.hose.node, 0, math.rad(-90), 0)


                    -- setTranslation(player.hose.node, 0.3, 0.3, -0.6)
                    -- setRotation(player.hose.node, 0, 0, 0)
                    -- print('player has to hose nodes')
                    -- LiquidManureHose:setHandNodes(player.toolsHandRightNode, self.hose.rightHandNode, grabPoint.node) -- The second parameter should be the actual handNode to aim for!
                else
                    -- player.hose = { -- if we are not the server only the info below is needed
                    -- walkingSpeed = player.walkingSpeed,
                    -- runningFactor = player.runningFactor
                    -- }
                end
            end
        end
    end
end

function LiquidManureHose:setEmptyEffect(activate, fillType, yDirectionSpeed)
    if self.hoseEffects ~= nil and self.hoseEffects.effects ~= nil then
        if activate then
            -- Make setFillType dynamic
            -- LiquidManureHose manure
            -- EffectManager:setFillType(self.emptyEffects.effect, FillUtil.FILLTYPE_CHAFF)
            EffectManager:setFillType(self.hoseEffects.effects, fillType)
            EffectManager:startEffects(self.hoseEffects.effects)
        else
            EffectManager:stopEffects(self.hoseEffects.effects)
        end
    end
end

function LiquidManureHose:toggleEmptyingEffect(activate, yDirectionSpeed, index)
    if self.hoseEffects ~= nil and self.hoseEffects.isActive ~= activate then
        self.hoseEffects.isActive = activate

        if self.hoseEffects.effects ~= nil then
            local grabPoint = self.grabPoints[index]
            local trans = { getWorldTranslation(grabPoint.node) }

            for _, effect in pairs(self.hoseEffects.effects) do
                local rot = { getRotation(effect.node) }

                rot[2] = grabPoint.id == 1 and math.rad(0) or math.rad(180)

                setWorldTranslation(effect.node, unpack(trans))
                setRotation(effect.node, unpack(rot))

                -- local x, _, z, w = getShaderParameter(effect.node, "UVScaleSpeed")
                -- setShaderParameter(effect.node, "UVScaleSpeed", x, yDirectionSpeed, z, w, false)
            end
        end
    end

    -- if self.emptyEffects ~= nil and self.emptyEffects.showEmptyEffects ~= activate then
    -- -- The direction get's fucked when i set a fillType!
    -- -- It's switching materials in the main function.. might need to write my own version
    -- -- self.emptyEffects.effect:setFillType(27)
    -- local grabPoint = self.grabPoints[index]
    -- local effects = self.emptyEffects.effect

    -- --print(LiquidManureHose:print_r(effect))
    -- -- for _, effectNode in pairs(effects) do
    -- -- if grabPoint ~= nil then
    -- -- local rot = {getRotation(effectNode.node)}

    -- -- if grabPoint.id <= 1 then
    -- -- rot[2] = math.rad(180)
    -- -- end

    -- -- --print('rotating! ' .. rot[1] .. rot[2] .. rot[3])
    -- -- --setTranslation(effectNode.linkNode, unpack(trans))
    -- -- setRotation(effectNode.node, unpack(rot))

    -- -- --print(LiquidManureHose:print_r({getShaderParameter(effectNode.node, "UVScaleSpeed")}))
    -- -- local x, _, z, w = getShaderParameter(effectNode.node, "UVScaleSpeed")
    -- -- setShaderParameter(effectNode.node, "UVScaleSpeed", x, yDirectionSpeed, z, w, false)
    -- -- --print(LiquidManureHose:print_r({getShaderParameter(effectNode.node, "UVScaleSpeed")}))
    -- -- end
    -- -- end

    -- self.emptyEffects.showEmptyEffects = activate
    -- end
end

---
-- @param attachState
-- @return bool
--
function LiquidManureHose:isDetached(attachState)
    return attachState == LiquidManureHose.states.detached
end

---
-- @param attachState
-- @return bool
--
function LiquidManureHose:isAttached(attachState)
    return attachState == LiquidManureHose.states.attached
end

---
-- @param attachState
-- @return bool
--
function LiquidManureHose:isParked(attachState)
    return attachState == LiquidManureHose.states.parked
end

---
-- @param attachState
-- @return bool
--
function LiquidManureHose:isConnected(attachState)
    return attachState == LiquidManureHose.states.connected
end

---
-- @param index
-- @return bool
--
function LiquidManureHose:allowsDetach(index)
    local grabPoint = self.grabPoints[index]

    if grabPoint ~= nil then
        if grabPoint.connectorRef ~= nil then
            if grabPoint.connectorRef.flowOpened or grabPoint.connectorRef.isLocked then
                return false
            end
        end
    end

    return true
end

function LiquidManureHose:renderTextOnNode(node, actionText, inputBinding)
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

function LiquidManureHose:loadObjectChangeValuesFromXML(superFunc, xmlFile, key, node, object)
    if self.nodesToGrabPoints ~= nil and self.nodesToGrabPoints[node] ~= nil then
        local grabPoint = self.nodesToGrabPoints[node]

        grabPoint.connectableActive = Utils.getNoNil(getXMLBool(xmlFile, key .. '#connectableActive'), false)
        grabPoint.connectableInactive = Utils.getNoNil(getXMLBool(xmlFile, key .. '#connectableInactive'), false)
    end

    -- local index = getXMLInt(xmlFile, key .. '#grabPointIndice')

    -- if index ~= nil then
    -- local grabPoint = self.grabPoints[index]

    -- if grabPoint ~= nil then
    -- grabPoint.grabPointIndiceObjectChange = index
    -- grabPoint.connectableObjectChange = Utils.getNoNil(getXMLBool(xmlFile, key .. '#connectable'), false)
    -- end
    -- end
end

function LiquidManureHose:setObjectChangeValues(superFunc, object, isActive)
    if self.nodesToGrabPoints ~= nil and self.nodesToGrabPoints[object.node] ~= nil then
        local grabPoint = self.nodesToGrabPoints[object.node]

        if isActive then
            grabPoint.connectable = grabPoint.connectableActive
        else
            grabPoint.connectable = grabPoint.connectableInactive
        end
    end
end

function LiquidManureHose:fillableObjectRaycastCallback(transformId, x, y, z, distance)
    if transformId ~= 0 then
        if transformId == g_currentMission.terrainRootNode then
            return false
        end

        local object = g_currentMission:getNodeObject(transformId)

        if object ~= nil and object.checkNode ~= nil then
            if object:checkNode(transformId) then
                for fillType, _ in pairs(self.supportedFillTypes) do
                    if object:allowFillType(fillType) then
                        self.lastRaycastObject = object
                        self.lastRaycastDistance = distance

                        return false
                    end
                end
            end
        end
    end

    return true
end

function LiquidManureHose:playerDelete(superFunc)
    if self.hose ~= nil then -- only server knows this
        if self.activeTool ~= nil and self.activeTool.drop ~= nil then
            self.activeTool:drop(self.activeToolLocationId, self)
        end
    end

    if superFunc ~= nil then
        superFunc(self)
    end
end

function LiquidManureHose:playerOnLeave(superFunc)
    if superFunc ~= nil then
        superFunc(self)
    end

    if self.hose ~= nil and self.hose.node ~= nil then -- only server knows this
        if self.activeTool ~= nil and self.activeTool.drop ~= nil then
            self.activeTool:drop(self.activeToolLocationId, self)
        end
    end
end

function LiquidManureHose:setPlayerTool(superFunc, tool)
    if self.activeTool ~= nil and self.activeToolLocationId ~= nil or self.hose ~= nil and self.hose.node ~= nil then
        return -- cancel
    end

    if superFunc ~= nil then
        superFunc(self, tool)
    end
end

function LiquidManureHose:setPlayerToolById(superFunc, toolId, noEventSend)
    if self.activeTool ~= nil and self.activeToolLocationId ~= nil or self.hose ~= nil and self.hose.node ~= nil then
        return -- cancel
    end

    if superFunc ~= nil then
        superFunc(self, toolId, noEventSend)
    end
end

function LiquidManureHose:highPressureWasherSetIsTurnedOn(superFunc, isTurnedOn, player, noEventSend)
    if player ~= nil then
        if player.activeTool ~= nil and player.activeToolLocationId ~= nil or player.hose ~= nil and player.hose.node ~= nil then
            return -- cancel
        end
    end

    if superFunc ~= nil then
        superFunc(self, isTurnedOn, player, noEventSend)
    end
end

---
-- Override
--

Player.delete = Utils.overwrittenFunction(Player.delete, LiquidManureHose.playerDelete)
Player.onLeave = Utils.overwrittenFunction(Player.onLeave, LiquidManureHose.playerOnLeave)
Player.setTool = Utils.overwrittenFunction(Player.setTool, LiquidManureHose.setPlayerTool)
Player.setToolById = Utils.overwrittenFunction(Player.setToolById, LiquidManureHose.setPlayerToolById)
HighPressureWasher.setIsTurnedOn = Utils.overwrittenFunction(HighPressureWasher.setIsTurnedOn, LiquidManureHose.highPressureWasherSetIsTurnedOn)

---
-- Debug
--
function LiquidManureHose:print_r(t, name, indent)
    local tableList = {}

    local table_r = function(t, name, indent, full)
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