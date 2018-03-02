--
-- HoseSystemRegistrationHelper
--
-- Authors: Wopster
-- Description: The register class to load specializations and handle features like getting hoses inrange and attach hoses from savegame
--
-- Copyright (c) Wopster, 2017

HoseSystemRegistrationHelper = {
    baseDirectory = g_currentModDirectory,
    runAtFirstFrame = true
}

HoseSystemRegistrationHelper.HOSE_SYSTEM_SPEC_KEY = 'hoseSystemVehicle'
HoseSystemRegistrationHelper.HOSE_SYSTEM_MATERIAL_TYPE = 'hoseSystem'

---
--
function HoseSystemRegistrationHelper:preLoadHoseSystem()
    if g_hoseSystem ~= nil then
        -- loaded already
    end

    getfenv(0)["g_hoseSystem"] = self

    self.log = HoseSystemUtil.log

    self.baseDirectory = HoseSystemRegistrationHelper.baseDirectory
    self.hoseSystemHoses = {}
    self.hoseSystemReferences = {}
end

---
-- @param name
--
function HoseSystemRegistrationHelper:loadMap(name)
    self.loadHoseSystemReferenceIds = {}
    self.minDistance = 2

    if not g_currentMission.hoseSystemRegistrationHelperIsLoaded then
        -- Register the fill mode for the hose system
        HoseSystemPumpMotor.registerFillMode(HoseSystemConnectorFactory.TYPE_HOSE_COUPLING)
        HoseSystemPumpMotor.registerFillMode(HoseSystemFillArmFactory.TYPE_DOCK)
        HoseSystemPumpMotor.registerFillMode(HoseSystemFillArmFactory.TYPE_ARM)

        -- Register the material for the hose system
        MaterialUtil.registerMaterialType(HoseSystemRegistrationHelper.HOSE_SYSTEM_MATERIAL_TYPE)
        loadI3DFile(HoseSystemRegistrationHelper.baseDirectory .. 'particleSystems/materialHolder.i3d')

        -- Todo: delete
        g_currentMission.hoseSystemLog = HoseSystemUtil.log
        g_currentMission.hoseSystemRegistrationHelperIsLoaded = true
    else
        HoseSystemUtil:log(HoseSystemUtil.ERROR, "The HoseSystemRegistrationHelper has been loaded already! Remove one of the copy's!")
    end

    addConsoleCommand("gsToggleHoseSystemDebugRendering", "Toggles the debug rendering of the HoseSystem", "consoleCommandToggleHoseSystemDebugRendering", HoseSystemUtil)
end

---
--
function HoseSystemRegistrationHelper:deleteMap()
    removeConsoleCommand("gsToggleHoseSystemDebugRendering")
    g_currentMission.hoseSystemRegistrationHelperIsLoaded = false
end

---
-- @param unicode
-- @param sym
-- @param modifier
-- @param isDown
--
function HoseSystemRegistrationHelper:keyEvent(unicode, sym, modifier, isDown)
end

---
-- @param posX
-- @param posY
-- @param isDown
-- @param isUp
-- @param button
--
function HoseSystemRegistrationHelper:mouseEvent(posX, posY, isDown, isUp, button)
end

---
-- @param dt
--
function HoseSystemRegistrationHelper:update(dt)
    self:getIsPlayerInGrabPointRange()

    if not g_currentMission:getIsServer() then
        return
    end

    if g_currentMission.hoseSystemRegistrationHelperIsLoaded and HoseSystemRegistrationHelper.runAtFirstFrame then
        if g_currentMission.missionInfo.vehiclesXMLLoad ~= nil then
            local xmlFile = loadXMLFile('VehiclesXML', g_currentMission.missionInfo.vehiclesXMLLoad)

            HoseSystemRegistrationHelper:loadVehicles(xmlFile, self.loadHoseSystemReferenceIds)

            if self.loadHoseSystemReferenceIds ~= nil then
                for xmlVehicleId, vehicleId in pairs(self.loadHoseSystemReferenceIds) do
                    local i = 0

                    while true do
                        local key = string.format('careerVehicles.vehicle(%d).grabPoint(%d)', xmlVehicleId, i)

                        if not hasXMLProperty(xmlFile, key) then
                            break
                        end

                        local vehicle = g_currentMission.vehicles[vehicleId]

                        if vehicle ~= nil then
                            local grabPointId = getXMLInt(xmlFile, key .. '#id')
                            local connectorVehicleId = getXMLInt(xmlFile, key .. '#connectorVehicleId')
                            local referenceId = getXMLInt(xmlFile, key .. '#referenceId')
                            local isExtendable = getXMLBool(xmlFile, key .. '#extenable')

                            if connectorVehicleId ~= nil and grabPointId ~= nil and referenceId ~= nil and isExtendable ~= nil then
                                if g_currentMission.hoseSystemReferences ~= nil then
                                    local connectorVehicle = g_currentMission.hoseSystemReferences[connectorVehicleId]

                                    if connectorVehicle ~= nil then
                                        if vehicle.poly ~= nil then
                                            vehicle.poly.interactiveHandling:attach(grabPointId, connectorVehicle, referenceId, isExtendable) -- will be synched later
                                        else
                                            HoseSystemUtil:log(HoseSystemUtil.ERROR, 'Something went wrong in your savegame, the vehicle that should be connecting is gone!')
                                        end
                                    else
                                        if HoseSystem.debugRendering then
                                            HoseSystemUtil:log(HoseSystemUtil.ERROR, 'Invalid connectorVehicle on gameload!')
                                        end
                                    end
                                else
                                    HoseSystemUtil:log(HoseSystemUtil.ERROR, 'No references vehicles where loaded but the savegame still has the connection data!')
                                end
                            end
                        end

                        i = i + 1
                    end
                end
            end

            self.loadHoseSystemReferenceIds = {}

            delete(xmlFile)
        end

        HoseSystemRegistrationHelper.runAtFirstFrame = false
    end
end

---
--
function HoseSystemRegistrationHelper:draw()
end

---
--
function HoseSystemRegistrationHelper:getIsPlayerInGrabPointRange()
    if g_currentMission.player ~= nil and g_currentMission.player.hoseSystem == nil then
        g_currentMission.player.hoseSystem = {}
    end

    if g_currentMission.player ~= nil then
        local closestIndex
        local distance = math.huge
        local playerDistance = self.minDistance
        local playerTrans = { getWorldTranslation(g_currentMission.player.rootNode) }

        if HoseSystemPlayerInteractive:getIsPlayerValid(true) and g_currentMission.hoseSystemHoses ~= nil then
            for _, hoseSystem in pairs(g_currentMission.hoseSystemHoses) do
                for index, grabPoint in pairs(hoseSystem.grabPoints) do
                    if grabPoint.node ~= nil then
                        local trans = { getWorldTranslation(grabPoint.node) }
                        local gpDistance = Utils.vector3Length(trans[1] - playerTrans[1], trans[2] - playerTrans[2], trans[3] - playerTrans[3])

                        playerDistance = Utils.getNoNil(grabPoint.playerDistance, playerDistance)

                        if gpDistance < distance and gpDistance < playerDistance then
                            if g_currentMission.player.hoseSystem.closestIndex == nil or g_currentMission.player.hoseSystem.closestHoseSystem == hoseSystem or g_currentMission.player.hoseSystem.closestDistance > gpDistance then
                                g_currentMission.player.hoseSystem.closestIndex = index
                                g_currentMission.player.hoseSystem.closestHoseSystem = hoseSystem
                                g_currentMission.player.hoseSystem.closestDistance = gpDistance
                            end

                            distance = gpDistance
                        end
                    end
                end
            end
        end

        if distance > playerDistance then
            g_currentMission.player.hoseSystem.closestIndex = nil
            g_currentMission.player.hoseSystem.closestHoseSystem = nil
            g_currentMission.player.hoseSystem.closestDistance = nil
        end
    end
end

---
-- @param super
-- @param vehicleData
-- @param asyncCallbackFunction
-- @param asyncCallbackObject
-- @param asyncCallbackArguments
--
function HoseSystemRegistrationHelper.loadVehicle(super, vehicleData, asyncCallbackFunction, asyncCallbackObject, asyncCallbackArguments)
    local customEnvironment, _ = Utils.getModNameAndBaseDirectory(vehicleData.filename)

    if customEnvironment ~= nil then
        local typeDef = VehicleTypeUtil.vehicleTypes[vehicleData.typeName]
        local specializations = typeDef.specializations
        local specializationNames = typeDef.specializationNames

        if specializations ~= nil and specializationNames ~= nil then
            for i = 1, #specializations do
                local specializationName = specializationNames[i]

                if specializationName ~= nil and specializationName:lower() == string.format('%s.%s', customEnvironment, HoseSystemRegistrationHelper.HOSE_SYSTEM_SPEC_KEY):lower() then
                    local specialization = specializations[i]

                    if specialization.preLoadHoseSystem ~= nil then
                        super.xmlFile = loadXMLFile('TempConfig', vehicleData.filename)

                        local vehicleLoadState = specializations[i].preLoadHoseSystem(super, vehicleData.savegame)

                        if vehicleLoadState ~= nil and vehicleLoadState ~= BaseMission.VEHICLE_LOAD_OK then
                            HoseSystemUtil:log(HoseSystemUtil.ERROR, specializationName .. "-specialization 'preLoadHoseSystem' failed!")

                            if asyncCallbackFunction ~= nil then
                                asyncCallbackFunction(asyncCallbackObject, nil, vehicleLoadState, asyncCallbackArguments)
                            end

                            return vehicleLoadState
                        end

                        if not super.hoseSystemLoaded then
                            HoseSystemRegistrationHelper:register(super, typeDef.specializations, customEnvironment)
                        end

                        delete(super.xmlFile)
                        super.xmlFile = nil
                    end
                end
            end
        end
    end
end

---
-- @param vehicle
-- @param specializations
-- @param name
--
function HoseSystemRegistrationHelper:register(vehicle, specializations, name)
    if vehicle.hasHoseSystemConnectors then
        local specialization = SpecializationUtil.getSpecialization('hoseSystemConnector')

        if not SpecializationUtil.hasSpecialization(specialization, specializations) then
            table.insert(specializations, specialization)

            if HoseSystem.debugRendering then
                HoseSystemUtil:log(HoseSystemUtil.DEBUG, 'Connector specialization added to: ' .. name)
            end
        end
    end

    if vehicle.hasHoseSystemPumpMotor then
        local specialization = SpecializationUtil.getSpecialization('hoseSystemPumpMotor')

        if not SpecializationUtil.hasSpecialization(specialization, specializations) then
            table.insert(specializations, specialization)

            if HoseSystem.debugRendering then
                HoseSystemUtil:log(HoseSystemUtil.DEBUG, 'PumpMotor specialization added to: ' .. name)
            end
        end
    end

    if vehicle.hasHoseSystemFillArm then
        local specialization = SpecializationUtil.getSpecialization('hoseSystemFillArm')

        if not SpecializationUtil.hasSpecialization(specialization, specializations) then
            table.insert(specializations, specialization)

            if HoseSystem.debugRendering then
                HoseSystemUtil:log(HoseSystemUtil.DEBUG, 'FillArm specialization added to: ' .. name)
            end
        end
    end

    vehicle.hoseSystemLoaded = true
end

---
-- @param xmlFile
-- @param referenceIds
--
function HoseSystemRegistrationHelper:loadVehicles(xmlFile, referenceIds)
    local i = 0

    while true do
        local key = string.format('careerVehicles.vehicle(%d)', i)

        if not hasXMLProperty(xmlFile, key) then
            break
        end

        if hasXMLProperty(xmlFile, string.format('%s.grabPoint', key)) then
            referenceIds[i] = i + 1
            -- table.insert(referenceIds, {xmlId = i, vehicleId = i + 1)
        end

        i = i + 1
    end
end

addModEventListener(HoseSystemRegistrationHelper)

-- Register the hoseSystemConnector and PumpMotor to vehicles
Vehicle.load = Utils.prependedFunction(Vehicle.load, HoseSystemRegistrationHelper.loadVehicle)
