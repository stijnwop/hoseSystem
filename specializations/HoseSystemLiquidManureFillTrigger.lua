--
-- HoseSystemLiquidManureFillTrigger
-- 
-- Uses parts from the LiquidManureFillTriggerExtension from Xentro.
--
-- @author: Wopster
--

HoseSystemLiquidManureFillTrigger = {
	states = {
        attached = 0,
        detached = 1,
        connected = 2,
        parked = 3
    }
}

function HoseSystemLiquidManureFillTrigger:new(superFunc, mt)
	local self = superFunc(self, mt)
	
	self.supportsHoseSystem = false
	self.offsetY = 0
	self.lastFillLevelChangeTime = 0
	self.inRageReferenceIndex = nil
	
	return self
end

function HoseSystemLiquidManureFillTrigger:load(superFunc, nodeId, fillLevelObject, fillType)	
	if superFunc(self, nodeId, fillLevelObject, fillType) then
		local xmlFilename = getUserAttribute(nodeId, 'xmlFilename')	
		
	    if xmlFilename == nil then	        
	        return false
	    end
		
		self.getCapacity = HoseSystemLiquidManureFillTrigger.getCapacity
		self.getFreeCapacity = HoseSystemLiquidManureFillTrigger.getFreeCapacity
		self.allowFillType = HoseSystemLiquidManureFillTrigger.allowFillType
		self.getCurrentFillTypes = HoseSystemLiquidManureFillTrigger.getCurrentFillTypes
		self.resetFillLevelIfNeeded = HoseSystemLiquidManureFillTrigger.resetFillLevelIfNeeded
		self.getFillLevel = HoseSystemLiquidManureFillTrigger.getFillLevel
		self.updateShaderPlane = HoseSystemLiquidManureFillTrigger.updateShaderPlane -- shader stuff
		
		self.getNearestReference = HoseSystemLiquidManureFillTrigger.getNearestReference
		self.setIsUsed = HoseSystemLiquidManureFillTrigger.setIsUsed
		self.toggleLock = HoseSystemLiquidManureFillTrigger.toggleLock
		self.toggleManureFlow = HoseSystemLiquidManureFillTrigger.toggleManureFlow
	
		-- detection for hose
		self.checkPlaneY = HoseSystemLiquidManureFillTrigger.checkPlaneY
		self.checkNode = HoseSystemLiquidManureFillTrigger.checkNode
		
		self.delete = Utils.overwrittenFunction(self.delete, HoseSystemLiquidManureFillTrigger.delete)
		self.update = Utils.overwrittenFunction(self.update, HoseSystemLiquidManureFillTrigger.update)
		self.setFillLevel = Utils.overwrittenFunction(self.setFillLevel, HoseSystemLiquidManureFillTrigger.setFillLevel)
		self.getIsActivatable = Utils.overwrittenFunction(self.getIsActivatable, HoseSystemLiquidManureFillTrigger.getIsActivatable)
				
		-- local detectionNode = Utils.indexToObject(nodeId, getUserAttribute(nodeId, 'detectionIndex'))
		-- if detectionNode ~= nil then
			-- self.detectionNode = detectionNode			
			-- g_currentMission:addNodeObject(self.detectionNode, self)
		-- end
		
		self.components = {}
		self.referenceNodes = {}
		self.hoseSystemReferences = {}
		
	    local baseDirectory = g_currentMission.loadingMapBaseDirectory
			
		if baseDirectory == "" then
	        baseDirectory = Utils.getNoNil(self.baseDirectory, baseDirectory)
	    end		
		
		self.xmlFilename = Utils.getFilename(xmlFilename, baseDirectory)
	    local xmlFile = loadXMLFile('hoseSystemFillTrigger', self.xmlFilename)
		
		if xmlFile ~= 0 then
			local objectIdentifier = getUserAttribute(nodeId, 'identifier')
			
			if objectIdentifier ~= nil then
				local i = 0
				local key
				
				while true do
					local objectXMLKey = string.format('map.hoseSystemFillTriggers.hoseSystemFillTrigger(%d)', i)
					
					if not hasXMLProperty(xmlFile, objectXMLKey) then
	                    break
	                end
					
					local objectXMLIdentifier = getXMLString(xmlFile, objectXMLKey .. '#identifier')
					
					if objectXMLIdentifier == objectIdentifier then
	                    key = objectXMLKey
	                    break
					end
					
					i = i + 1
				end
				
				if key ~= nil then
					local pitKey = string.format('%s.pit', key)
					
					if hasXMLProperty(xmlFile, pitKey) then
						local detectionNode = Utils.indexToObject(nodeId, getXMLString(xmlFile, pitKey .. '#bottomNode'))
						
						if detectionNode ~= nil then
							self.detectionNode = detectionNode
							g_currentMission:addNodeObject(self.detectionNode, self)
						end
						
						local coverNode = Utils.indexToObject(nodeId, getXMLString(xmlFile, pitKey .. '#coverNode'))
						
						if coverNode ~= nil then						
							self.coverNode = coverNode
						end
						
						local offsetY = getXMLFloat(xmlFile, pitKey .. '#offsetY')

						if offsetY ~= nil then
							self.offsetY = offsetY
						end
						
						self.moveMinY = getXMLFloat(xmlFile, pitKey .. '#planeMinY')
						self.moveMaxY = getXMLFloat(xmlFile, pitKey .. '#planeMaxY')
						self.movingId = Utils.indexToObject(nodeId, getXMLString(xmlFile, pitKey .. '#planeNode'))
						
						self.animatedObjectSaveId = getXMLString(xmlFile, pitKey .. '#animatedObjectSaveId')
					end
					
					HoseSystemLiquidManureFillTrigger:loadHoseSystemReferences(self, nodeId, xmlFile, string.format('%s.hoseSystemReferences.', key), self.hoseSystemReferences)					
				end
			end
		end
		
		local referencesCount = table.getn(self.hoseSystemReferences)
		
		if referencesCount > 0 then			
			if g_currentMission.hoseSystemReferences == nil then
				g_currentMission.hoseSystemReferences = {}
			end

			table.insert(g_currentMission.hoseSystemReferences, self)
			--print(table.getn(g_currentMission.hoseSystemReferences))
		end
		
		-- well this should hold the supported fillModes
		-- self.fillModes = {}
		self.supportsHoseSystem = self.detectionNode ~= nil or referencesCount > 0
		self.shaderOnIdle = true	
		
		g_currentMission:addNodeObject(self.nodeId, self)
		
		if self.fillLevelObject ~= nil then
			self.fillLevelObject.hoseSystemParent = self
		end
		
		return true
	end
	
	return false
end

function HoseSystemLiquidManureFillTrigger:loadHoseSystemReferences(self, nodeId, xmlFile, base, references)
	local i = 0

	while true do 
		local key = string.format(base .. 'hoseSystemReference(%d)', i)
        if not hasXMLProperty(xmlFile, key) then
            break
        end
		
		local node = Utils.indexToObject(nodeId, getXMLString(xmlFile, key .. '#node'))
		
		if node ~= nil then		
			local id = i + 1
			
			self.referenceNodes[id] = node
			
			g_currentMission:addNodeObject(self.referenceNodes[id], self)
			
			-- build dummy reference
			-- Todo: how to play animations? Create custom stuff for it?
			
			-- build dummy component node
			self.components[id] = {
				node = nodeId
			}
			
			local entry = {
				id = id,
				node = self.referenceNodes[id],
				isUsed = false,
				flowOpened = false, -- false, todo: fix this later with user input
				isLocked = false, -- false, todo: fix this later with user input
				liquidManureHose = nil,
				grabPoints = nil,
				isObject = true,
				componentIndex = id, -- where to joint to?
				parkable = false,
				lockAnimatedObjectSaveId = Utils.getNoNil(getXMLString(xmlFile, key .. '#lockAnimatedObjectSaveId'), nil),
				manureFlowAnimatedObjectSaveId = Utils.getNoNil(getXMLString(xmlFile, key .. '#manureFlowAnimatedObjectSaveId'), nil)
			}
			
			table.insert(references, entry)
		end		
		
		i = i + 1
	end
end

function HoseSystemLiquidManureFillTrigger:delete(superFunc)
	if superFunc ~= nil then
		superFunc(self)
	end
	
	if self.detectionNode ~= nil then		
		g_currentMission:removeNodeObject(self.detectionNode)
	end
	
	if self.referenceNodes ~= nil then
		for _, referenceNode in pairs(self.referenceNodes) do
			g_currentMission:removeNodeObject(referenceNode)
		end
	end
end

function HoseSystemLiquidManureFillTrigger:update(superFunc, dt)
	if superFunc ~= nil then
		superFunc(self, dt)
	end	
	
	if self:getShowInfo() then
		g_currentMission:addExtraPrintText("supportsHoseSystem = " .. tostring(self.supportsHoseSystem) .. ' hoseSystemReferences = ' .. tostring(table.getn(self.hoseSystemReferences) > 0))
	end
	
	if not self.playerInRange then
		if g_currentMission.animatedObjects ~= nil then -- Note: this is only possible with the extension
			local object = g_currentMission.animatedObjects[self.animatedObjectSaveId]
			
			if object ~= nil then
				if object.animation.time == 1 then --and object.animation.time == object.animation.duration then
					if not self.isEnabled then
						self.isEnabled = not self.isEnabled				
					end
				else
					if self.isEnabled then
						self.isEnabled = not self.isEnabled				
					end
				end
			end
		end
	end
		
	if self.playerInRange then	
		if g_currentMission.animatedObjects ~= nil then
			self.inRageReferenceIndex = self:getNearestReference({getWorldTranslation(g_currentMission.player.rootNode)})
			
			if self.inRageReferenceIndex ~= nil then
				local reference = self.hoseSystemReferences[self.inRageReferenceIndex]
				
				if reference ~= nil then
					if reference.lockAnimatedObjectSaveId ~= nil then
						local animatedObject = g_currentMission.animatedObjects[reference.lockAnimatedObjectSaveId]
		
						if animatedObject ~= nil then
							
						end
					else
						if not reference.isLocked then
							self:toggleLock(self.inRageReferenceIndex, true, true)
						end
					end
					
					if reference.isLocked then
						if reference.manureFlowAnimatedObjectSaveId ~= nil then
							local animatedObject = g_currentMission.animatedObjects[reference.lockAnimatedObjectSaveId]
			
							if animatedObject ~= nil then
								
							end
						else
							if not reference.flowOpened then
								self:toggleManureFlow(self.inRageReferenceIndex, true, true)
							end
						end				
					end				
				end
			end
		end
	end
end

function HoseSystemLiquidManureFillTrigger:getNearestReference(playerTrans)
	if self.hoseSystemReferences == nil then
		return nil
	end
	
	local x, y, z = unpack(playerTrans)
	local nearestDisSequence = 1.5
	
	for referenceIndex, reference in pairs(self.hoseSystemReferences) do
		if reference.isUsed and reference.liquidManureHose ~= nil then
			for grabPointIndex, grabPoint in pairs(reference.liquidManureHose.grabPoints) do
				if HoseSystemLiquidManureFillTrigger:getIsHoseConnected(grabPoint.attachState) and grabPoint.connectorRef == reference then
					local gx, gy, gz = getWorldTranslation(reference.node)
					local dist = Utils.vector3Length(x - gx, y - gy, z - gz)

					if dist < nearestDisSequence then
						nearestDisSequence = dist
						
						return referenceIndex				
					end
				end
			end
		end
	end
	
	return nil
end
function HoseSystemLiquidManureFillTrigger:getIsActivatable(superFunc, fillable)
	if superFunc(self, fillable) then
		if self.supportsHoseSystem then
			if fillable.hasHoseSystem ~= nil and fillable.hasHoseSystem then
				return false
			end
		end
		
		return true
	end
	
	return false
end

function HoseSystemLiquidManureFillTrigger:allowFillType(fillType, allowEmptying)
	return fillType == FillUtil.FILLTYPE_UNKNOWN or fillType == self.fillType -- Confirm working
end

function HoseSystemLiquidManureFillTrigger:getCurrentFillTypes()
	return {self.fillType}
end

function HoseSystemLiquidManureFillTrigger:resetFillLevelIfNeeded(fillType)
	if self.lastFillLevelChangeTime + 500 > g_currentMission.time then
		return false
	end
	
	self:setFillLevel(0)
	
	return true
end

function HoseSystemLiquidManureFillTrigger:setFillLevel(superFunc, fillLevel, noEventSend)
	-- superFunc(self, fillLevel, noEventSend)
	
	fillLevel = Utils.clamp(fillLevel, 0, self.capacity)
	
	if self.fillLevel ~= fillLevel then
		self.fillLevel = fillLevel

		if noEventSend == nil or not noEventSend then
			self.fillLevelObject:liquidManureFillLevelChanged(fillLevel, self.fillType, self)
		end

		if self.fillLevelObject.isClient then
			if self.movingId ~= nil then
				local x,y,z = getTranslation(self.movingId)
				local y = self.moveMinY + (self.moveMaxY - self.moveMinY)*self.fillLevel/self.capacity
				setTranslation(self.movingId, x,y,z)
			end
		end
	end
	
	self.lastFillLevelChangeTime = g_currentMission.time
end

function HoseSystemLiquidManureFillTrigger:getFillLevel(fillType)
	if fillType == nil then
		return self.fillLevel
	end

	return fillType == self.fillType and self.fillLevel or 0
end

function HoseSystemLiquidManureFillTrigger:getCapacity(fillType)
	if fillType == nil then
		return self.capacity
	end
	
	return fillType == self.fillType and self.capacity or 0
end

function HoseSystemLiquidManureFillTrigger:getFreeCapacity(fillType)	
	return self:getCapacity(fillType) - self:getFillLevel(fillType)
end

function HoseSystemLiquidManureFillTrigger:getIsHoseConnected(attachState)
    return attachState == HoseSystemLiquidManureFillTrigger.states.connected
end

function HoseSystemLiquidManureFillTrigger:checkNode(nodeId)	
	return self.isEnabled and self.detectionNode == nodeId or false
end

function HoseSystemLiquidManureFillTrigger:checkPlaneY(y)
	local _, py, _ = getWorldTranslation(self.movingId)
	py = py + self.offsetY
	
	return py >= y, py
end

-- 
-- Do this extern..
-- Include pump direction to set different shaderParameter
--
function HoseSystemLiquidManureFillTrigger:updateShaderPlane(pumpIsStarted, pumpDirection, literPerSeconds) -- what more?
	if self.fillLevelObject.isClient then
		if self.supportsHoseSystem then
			if getHasShaderParameter(self.movingId, "displacementScaleSpeedFrequency") then
				if pumpIsStarted then
					self.shaderOnIdle = false
					
					if pumpDirection == 0 then -- in
						setShaderParameter(self.movingId, "displacementScaleSpeedFrequency", 0.02, 4, 15, 1, false)
					elseif pumpDirection == 1 then
						setShaderParameter(self.movingId, "displacementScaleSpeedFrequency", 0.02, 6, 30, 1, false)					
					end
				else
					if not self.shaderOnIdle then
						setShaderParameter(self.movingId, "displacementScaleSpeedFrequency", 0.02, 0.1, 15, 1, false)
						self.shaderOnIdle = true
					end
				end
			end
		end
		-- if getHasShaderParameter(self.movingId, 'the param name') then
			-- setShaderParameter(self.movingId)
		-- end
	end
end

function HoseSystemLiquidManureFillTrigger:toggleLock(index, state, force, noEventSend)
	HoseSystemLiquidManureFillTriggerLockEvent.sendEvent(self.fillLevelObject, index, state, force, noEventSend)
	
	local reference = self.hoseSystemReferences[index]
	
	if reference ~= nil then
		local animatedObject = g_currentMission.animatedObjects[reference.lockAnimatedObjectSaveId]
		
		if animatedObject ~= nil then
			-- local dir = state and 1 or -1		
			-- local shouldPlay = force or not self:getIsAnimationPlaying(reference.lockAnimationName) 
			
			-- if shouldPlay then
				-- self:playAnimation(reference.lockAnimationName, dir, nil, true)
				-- reference.isLocked = state			
			-- end
		else
			reference.isLocked = state	
		end
	end
end

function HoseSystemLiquidManureFillTrigger:toggleManureFlow(index, state, force, noEventSend)
	HoseSystemLiquidManureFillTriggerManureFlowEvent.sendEvent(self.fillLevelObject, index, state, force, noEventSend)
	
	local reference = self.hoseSystemReferences[index]
	
	if reference ~= nil then
		local animatedObject = g_currentMission.animatedObjects[reference.lockAnimatedObjectSaveId]
		
		if animatedObject ~= nil then		
			-- local dir = state and 1 or -1
			-- local shouldPlay = force or not self:getIsAnimationPlaying(reference.manureFlowAnimationName) 
			
			-- if shouldPlay then
				-- self:playAnimation(reference.manureFlowAnimationName, dir, nil, true)
				-- reference.flowOpened = state			
			-- end
		else
			reference.flowOpened = state	
		end
	end
end

function HoseSystemLiquidManureFillTrigger:setIsUsed(index, bool, noEventSend) 
	HoseSystemLiquidManureFillTriggerIsUsedEvent.sendEvent(self.fillLevelObject, index, bool, noEventSend)
	
	local reference = self.hoseSystemReferences[index]
	
	if reference ~= nil then
		reference.isUsed = bool	
	end
end

-- LiquidManureFillTrigger
LiquidManureFillTrigger.new = Utils.overwrittenFunction(LiquidManureFillTrigger.new, HoseSystemLiquidManureFillTrigger.new)		
LiquidManureFillTrigger.load = Utils.overwrittenFunction(LiquidManureFillTrigger.load, HoseSystemLiquidManureFillTrigger.load)

-- TipTrigger
-- TipTrigger.load = Utils.overwrittenFunction(TipTrigger.load, HoseSystemLiquidManureFillTrigger.load) -- overwrite to be albe to pump water

---
--
--

HoseSystemLiquidManureFillTriggerIsUsedEvent = {}
HoseSystemLiquidManureFillTriggerIsUsedEvent_mt = Class(HoseSystemLiquidManureFillTriggerIsUsedEvent, Event)
InitEventClass(HoseSystemLiquidManureFillTriggerIsUsedEvent, 'HoseSystemLiquidManureFillTriggerIsUsedEvent')

function HoseSystemLiquidManureFillTriggerIsUsedEvent:emptyNew()
    local self = Event:new(HoseSystemLiquidManureFillTriggerIsUsedEvent_mt)
    self.className = 'HoseSystemLiquidManureFillTriggerIsUsedEvent'

    return self
end

function HoseSystemLiquidManureFillTriggerIsUsedEvent:new(hoseSystemReference, index, bool)
    local self = HoseSystemLiquidManureFillTriggerIsUsedEvent:emptyNew()
    self.hoseSystemReference = hoseSystemReference
    self.index = index
    self.bool = bool

    return self
end

function HoseSystemLiquidManureFillTriggerIsUsedEvent:writeStream(streamId, connection)
	writeNetworkNodeObject(streamId, self.hoseSystemReference)
	streamWriteInt32(streamId, self.index)
	streamWriteBool(streamId, self.bool)
end

function HoseSystemLiquidManureFillTriggerIsUsedEvent:readStream(streamId, connection)
	self.hoseSystemReference = readNetworkNodeObject(streamId)
	self.index = streamReadInt32(streamId)
	self.bool = streamReadBool(streamId)
	
    self:run(connection)
end

function HoseSystemLiquidManureFillTriggerIsUsedEvent:run(connection)
	self.hoseSystemReference.hoseSystemParent:setIsUsed(self.index, self.bool, true)

	if not connection:getIsServer() then
		g_server:broadcastEvent(HoseSystemLiquidManureFillTriggerIsUsedEvent:new(self.hoseSystemReference, self.index, self.bool), nil, connection, self.hoseSystemReference)
	end
end

function HoseSystemLiquidManureFillTriggerIsUsedEvent.sendEvent(hoseSystemReference, index, bool, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(HoseSystemLiquidManureFillTriggerIsUsedEvent:new(hoseSystemReference, index, bool), nil, nil, hoseSystemReference)
        else
            g_client:getServerConnection():sendEvent(HoseSystemLiquidManureFillTriggerIsUsedEvent:new(hoseSystemReference, index, bool))
        end
    end
end

HoseSystemLiquidManureFillTriggerLockEvent = {}
HoseSystemLiquidManureFillTriggerLockEvent_mt = Class(HoseSystemLiquidManureFillTriggerLockEvent, Event)
InitEventClass(HoseSystemLiquidManureFillTriggerLockEvent, 'HoseSystemLiquidManureFillTriggerLockEvent')

function HoseSystemLiquidManureFillTriggerLockEvent:emptyNew()
    local self = Event:new(HoseSystemLiquidManureFillTriggerLockEvent_mt)
    self.className = 'HoseSystemLiquidManureFillTriggerLockEvent'

    return self
end

function HoseSystemLiquidManureFillTriggerLockEvent:new(hoseSystemReference, index, state, force)
    local self = HoseSystemLiquidManureFillTriggerLockEvent:emptyNew()
    self.hoseSystemReference = hoseSystemReference
    self.index = index
    self.state = state
    self.force = force

    return self
end

function HoseSystemLiquidManureFillTriggerLockEvent:writeStream(streamId, connection)
	writeNetworkNodeObject(streamId, self.hoseSystemReference)
	streamWriteInt32(streamId, self.index)
	streamWriteBool(streamId, self.state)
	streamWriteBool(streamId, self.force)
end

function HoseSystemLiquidManureFillTriggerLockEvent:readStream(streamId, connection)
	self.hoseSystemReference = readNetworkNodeObject(streamId)
	self.index = streamReadInt32(streamId)
	self.state = streamReadBool(streamId)
	self.force = streamReadBool(streamId)
	
    self:run(connection)
end

function HoseSystemLiquidManureFillTriggerLockEvent:run(connection)
	self.hoseSystemReference.hoseSystemParent:toggleLock(self.index, self.state, self.force, true)

	if not connection:getIsServer() then
		g_server:broadcastEvent(HoseSystemLiquidManureFillTriggerLockEvent:new(self.hoseSystemReference, self.index, self.state, self.force), nil, connection, self.hoseSystemReference)
	end
end

function HoseSystemLiquidManureFillTriggerLockEvent.sendEvent(hoseSystemReference, index, state, force, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(HoseSystemLiquidManureFillTriggerLockEvent:new(hoseSystemReference, index, state, force), nil, nil, hoseSystemReference)
        else
            g_client:getServerConnection():sendEvent(HoseSystemLiquidManureFillTriggerLockEvent:new(hoseSystemReference, index, state, force))
        end
    end
end

HoseSystemLiquidManureFillTriggerManureFlowEvent = {}
HoseSystemLiquidManureFillTriggerManureFlowEvent_mt = Class(HoseSystemLiquidManureFillTriggerManureFlowEvent, Event)
InitEventClass(HoseSystemLiquidManureFillTriggerManureFlowEvent, 'HoseSystemLiquidManureFillTriggerManureFlowEvent')

function HoseSystemLiquidManureFillTriggerManureFlowEvent:emptyNew()
    local self = Event:new(HoseSystemLiquidManureFillTriggerManureFlowEvent_mt)
    self.className = 'HoseSystemLiquidManureFillTriggerManureFlowEvent'

    return self
end

function HoseSystemLiquidManureFillTriggerManureFlowEvent:new(hoseSystemReference, index, state, force)
    local self = HoseSystemLiquidManureFillTriggerManureFlowEvent:emptyNew()
    self.hoseSystemReference = hoseSystemReference
    self.index = index
    self.state = state
    self.force = force

    return self
end

function HoseSystemLiquidManureFillTriggerManureFlowEvent:writeStream(streamId, connection)
	writeNetworkNodeObject(streamId, self.hoseSystemReference)
	streamWriteInt32(streamId, self.index)
	streamWriteBool(streamId, self.state)
	streamWriteBool(streamId, self.force)
end

function HoseSystemLiquidManureFillTriggerManureFlowEvent:readStream(streamId, connection)
	self.hoseSystemReference = readNetworkNodeObject(streamId)
	self.index = streamReadInt32(streamId)
	self.state = streamReadBool(streamId)
	self.force = streamReadBool(streamId)
	
    self:run(connection)
end

function HoseSystemLiquidManureFillTriggerManureFlowEvent:run(connection)
	self.hoseSystemReference.hoseSystemParent:toggleManureFlow(self.index, self.state, self.force, true)

	if not connection:getIsServer() then
		g_server:broadcastEvent(HoseSystemLiquidManureFillTriggerManureFlowEvent:new(self.hoseSystemReference, self.index, self.state, self.force), nil, connection, self.hoseSystemReference)
	end
end

function HoseSystemLiquidManureFillTriggerManureFlowEvent.sendEvent(hoseSystemReference, index, state, force, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(HoseSystemLiquidManureFillTriggerManureFlowEvent:new(hoseSystemReference, index, state, force), nil, nil, hoseSystemReference)
        else
            g_client:getServerConnection():sendEvent(HoseSystemLiquidManureFillTriggerManureFlowEvent:new(hoseSystemReference, index, state, force))
        end
    end
end