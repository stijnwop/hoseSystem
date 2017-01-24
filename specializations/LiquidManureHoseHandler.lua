--
-- 
-- 
-- @author: Wopster
--

LiquidManureHoseHandler = {}

function LiquidManureHoseHandler:loadMap()
	if not g_currentMission.isLiquidManureHoseHandlerLoaded then
		addConsoleCommand('LMHDebug', 'Toggle debug.', 'toggleDebug', self)

		g_currentMission.isLiquidManureHoseHandlerLoaded = true
		self.loadHandler = g_currentMission.isLiquidManureHoseHandlerLoaded -- keep this local
	end
	
	self.loadLiquidManureHoseReferenceIds = {}
end

function LiquidManureHoseHandler:deleteMap()
	if g_isRealTerrainManagerLoaded then
		removeConsoleCommand('LMHDebug')

		g_currentMission.isLiquidManureHoseHandlerLoaded = false
	end
end

function LiquidManureHoseHandler:mouseEvent(posX, posY, isDown, isUp, button)
end

function LiquidManureHoseHandler:keyEvent(unicode, sym, modifier, isDown)
end

function LiquidManureHoseHandler:update(dt)
	if g_server ~= nil then
		if g_currentMission.isLiquidManureHoseHandlerLoaded and self.loadHandler then
			if g_currentMission.missionInfo.vehiclesXMLLoad ~= nil then			
				local xmlFile = loadXMLFile('VehiclesXML', g_currentMission.missionInfo.vehiclesXMLLoad);
				
				LiquidManureHoseHandler:loadVehicles(xmlFile, self.loadLiquidManureHoseReferenceIds)
				
				if self.loadLiquidManureHoseReferenceIds ~= nil then
					for xmlVehicleId, vehicleId in pairs(self.loadLiquidManureHoseReferenceIds) do
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
								local isObject = getXMLBool(xmlFile, key .. '#isObject')
								local isExtendable = getXMLBool(xmlFile, key .. '#extenable')
								
								if connectorVehicleId ~= nil and grabPointId ~= nil and referenceId ~= nil and isExtendable ~= nil then								
									local connectorVehicle = not isObject and g_currentMission.vehicles[connectorVehicleId] or g_currentMission.onCreateLoadedObjects[connectorVehicleId]
					
									if connectorVehicle ~= nil then
										print('attaching')
										vehicle:attach(grabPointId, nil, connectorVehicle, referenceId, isExtendable)
									else
										if liquidManureHose.debug then
											print('HoseSystem | postLoad - invalid connectorVehicle!')
										end				
									end
								end
							end
							
							i = i + 1
						end
					end
				end
				
				self.loadLiquidManureHoseReferenceIds = {}
				delete(xmlFile)
			end
			
			self.loadHandler = false
		end
	end
end

function LiquidManureHoseHandler:draw()
end

function LiquidManureHoseHandler:toggleDebug()
	if liquidManureHose then
		liquidManureHose.debug = not liquidManureHose.debug
		
		return string.format('LiquidManureHose debug mode: %s', liquidManureHose.debug and 'enabled' or 'disabled')
	end
end

function LiquidManureHoseHandler:loadVehicles(xmlFile, referenceIds)
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

addModEventListener(LiquidManureHoseHandler)