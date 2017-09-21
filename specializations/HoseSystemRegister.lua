--
--	
--
--	@author: 	 Wopster
--	@descripion: Register specializations for the HoseSystem
--	@history:	 
--				 
--

HoseSystemRegistrationHelper = {
    baseDirectory = g_currentModDirectory,
    runAtFirstFrame = true
}

local srcDirectory = HoseSystemRegistrationHelper.baseDirectory .. 'specializations'
local eventDirectory = HoseSystemRegistrationHelper.baseDirectory .. 'specializations/events'

local files = {
    ('%s/%s'):format(eventDirectory, 'HoseSystemReferenceIsUsedEvent'),
    ('%s/%s'):format(eventDirectory, 'HoseSystemReferenceLockEvent'),
    ('%s/%s'):format(eventDirectory, 'HoseSystemReferenceManureFlowEvent'),
    ('%s/%s'):format(srcDirectory, 'HoseSystemUtil'),
}

for _, directory in pairs(files) do
    source(directory .. '.lua')
end

if SpecializationUtil.specializations['hoseSystemConnectorReference'] == nil then
    SpecializationUtil.registerSpecialization('hoseSystemConnectorReference', 'HoseSystemConnectorReference', HoseSystemRegistrationHelper.baseDirectory .. 'specializations/HoseSystemConnectorReference.lua')
end

if SpecializationUtil.specializations['hoseSystemPumpMotor'] == nil then
    SpecializationUtil.registerSpecialization('hoseSystemPumpMotor', 'HoseSystemPumpMotor', HoseSystemRegistrationHelper.baseDirectory .. 'specializations/HoseSystemPumpMotor.lua')
end

function HoseSystemRegistrationHelper:loadMap(name)
    self.loadHoseSystemReferenceIds = {}
    self.minDistance = 2
    self.syncClients = false

    if not g_currentMission.hoseSystemRegistrationHelperIsLoaded then
        -- Register the hoseSystemConnectorReference to vehicles
        self:register()

        -- Register the fill mode for the hose system
        HoseSystemPumpMotor.registerFillMode('hoseSystem')

        -- Register the material for the hose system
        MaterialUtil.registerMaterialType('hoseSystem')
        local materialHolder = loadI3DFile(HoseSystemRegistrationHelper.baseDirectory .. 'particleSystems/materialHolder.i3d')
        --		delete(materialHolder)

        g_currentMission.hoseSystemRegistrationHelperIsLoaded = true
    else
        print("HoseSystemRegistrationHelper - error: The HoseSystemRegistrationHelper has been loaded already! Remove one of the copy's!")
    end
end

function HoseSystemRegistrationHelper:deleteMap()
    g_currentMission.hoseSystemRegistrationHelperIsLoaded = false
end

function HoseSystemRegistrationHelper:keyEvent(unicode, sym, modifier, isDown)
end

function HoseSystemRegistrationHelper:mouseEvent(posX, posY, isDown, isUp, button)
end

function HoseSystemRegistrationHelper:update(dt)
    self:getIsPlayerInGrabPointRange()

    if g_server ~= nil then -- only server
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
                                    local connectorVehicle = g_currentMission.hoseSystemReferences[connectorVehicleId]

                                    if connectorVehicle ~= nil then
                                        vehicle.poly.interactiveHandling:attach(grabPointId, connectorVehicle, referenceId, isExtendable, true) -- will be synched later
                                    else
                                        if HoseSystem.debugRendering then
                                            print('HoseSystemRegistrationHelper - error: Invalid connectorVehicle!')
                                        end
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
end

function HoseSystemRegistrationHelper:draw()
end

function HoseSystemRegistrationHelper:getIsPlayerInGrabPointRange()
    if g_currentMission.player.hoseSystem == nil then
        g_currentMission.player.hoseSystem = {}
    end

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

---
--
function HoseSystemRegistrationHelper:register()
    for _, vehicle in pairs(VehicleTypeUtil.vehicleTypes) do
        if vehicle ~= nil then
            local customEnvironment

            if vehicle.name:find('.') then
                customEnvironment = Utils.splitString('.', vehicle.name)[1]
            end

            if customEnvironment ~= nil then
                if rawget(SpecializationUtil.specializations, customEnvironment .. '.HoseSystemConnector') ~= nil or rawget(SpecializationUtil.specializations, customEnvironment .. '.hoseSystemConnector') ~= nil then
                    -- Found connector specialization
                    if HoseSystem.debugRendering then
                        print('HoseSystem - hoseSystemConnectorReference specialization added to: ' .. customEnvironment)
                    end

                    table.insert(vehicle.specializations, SpecializationUtil.getSpecialization('hoseSystemConnectorReference'))
                    table.insert(vehicle.specializations, SpecializationUtil.getSpecialization('hoseSystemPumpMotor')) -- insert pump as well.. no way to check this without doing it dirty
                end
            end
        end
    end
end

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