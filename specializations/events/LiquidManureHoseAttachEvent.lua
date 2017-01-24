---
-- Created by IntelliJ IDEA.
-- Author: Wopster
-- Date: 28-7-2016
-- Time: 21:09
--
--
--

liquidManureHoseAttachEvent = {}

liquidManureHoseAttachEvent_mt = Class(liquidManureHoseAttachEvent, Event)
InitEventClass(liquidManureHoseAttachEvent, 'liquidManureHoseAttachEvent')

function liquidManureHoseAttachEvent:emptyNew()
    local self = Event:new(liquidManureHoseAttachEvent_mt)
    self.className = 'liquidManureHoseAttachEvent'

    return self
end

function liquidManureHoseAttachEvent:new(liquidManureHose, index, state, vehicle, reference, isExtendable)
    local self = liquidManureHoseAttachEvent:emptyNew()
    self.liquidManureHose = liquidManureHose
    self.index = index
    self.state = state
    self.vehicle = vehicle
    self.reference = reference
    self.isExtendable = isExtendable
	
    return self
end

function liquidManureHoseAttachEvent:readStream(streamId, connection)
    self.liquidManureHose = readNetworkNodeObject(streamId)
    self.index = streamReadInt32(streamId)
    self.state = streamReadInt32(streamId)
    self.vehicle = readNetworkNodeObject(streamId)
    self.reference = streamReadInt32(streamId)
    self.isExtendable = streamReadBool(streamId)
    self:run(connection)
end

function liquidManureHoseAttachEvent:writeStream(streamId, connection)
    writeNetworkNodeObject(streamId, self.liquidManureHose)
    streamWriteInt32(streamId, self.index)
	streamWriteInt32(streamId, self.state)
    writeNetworkNodeObject(streamId, self.vehicle)
    streamWriteInt32(streamId, self.reference)
    streamWriteBool(streamId, self.isExtendable)
end

function liquidManureHoseAttachEvent:run(connection)
	self.liquidManureHose:attach(self.index, self.state, self.vehicle, self.reference, self.isExtendable, true)
	
	if not connection:getIsServer() then
		g_server:broadcastEvent(self, nil, connection, self.liquidManureHose)
	end
	
	-- if self.state == liquidManureHoseAttachEvent.server then
		-- self.liquidManureHose:attach(self.index, self.state, self.vehicle, self.reference, self.isExtendable, false)
	-- elseif self.state == liquidManureHoseAttachEvent.client then
		-- self.liquidManureHose:attach(self.index, self.state, self.vehicle, self.reference, self.isExtendable, true)
	-- end
		
    -- if not connection:getIsServer() then
        -- g_server:broadcastEvent(liquidManureHoseAttachEvent:new(self.liquidManureHose, self.index, self.state, self.vehicle, self.reference, self.isExtendable), nil, connection, self.liquidManureHose)
    -- end
end

function liquidManureHoseAttachEvent.sendEvent(liquidManureHose, index, state, vehicle, reference, isExtendable, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(liquidManureHoseAttachEvent:new(liquidManureHose, index, state, vehicle, reference, isExtendable), nil, nil, liquidManureHose)
        else
            g_client:getServerConnection():sendEvent(liquidManureHoseAttachEvent:new(liquidManureHose, index, state, vehicle, reference, isExtendable))
        end
    end
end