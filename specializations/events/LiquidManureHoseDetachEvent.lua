---
-- Created by IntelliJ IDEA.
-- Author: Wopster
-- Date: 28-7-2016
-- Time: 21:09
--
--
--

liquidManureHoseDetachEvent = {}

liquidManureHoseDetachEvent_mt = Class(liquidManureHoseDetachEvent, Event)
InitEventClass(liquidManureHoseDetachEvent, 'liquidManureHoseDetachEvent')

function liquidManureHoseDetachEvent:emptyNew()
    local self = Event:new(liquidManureHoseDetachEvent_mt)
    self.className = 'liquidManureHoseDetachEvent'

    return self
end

function liquidManureHoseDetachEvent:new(liquidManureHose, index, state, vehicle, reference, isExtendable)
    local self = liquidManureHoseDetachEvent:emptyNew()
    self.liquidManureHose = liquidManureHose
    self.index = index
    self.state = state
	self.vehicle = vehicle
    self.reference = reference
    self.isExtendable = isExtendable
	
    return self
end

function liquidManureHoseDetachEvent:readStream(streamId, connection)
    self.liquidManureHose = readNetworkNodeObject(streamId)
    self.index = streamReadInt32(streamId)
    self.state = streamReadInt32(streamId)
	self.vehicle = readNetworkNodeObject(streamId)
    self.reference = streamReadInt32(streamId)
    self.isExtendable = streamReadBool(streamId)
    self:run(connection)
end

function liquidManureHoseDetachEvent:writeStream(streamId, connection)
    writeNetworkNodeObject(streamId, self.liquidManureHose)
    streamWriteInt32(streamId, self.index)
    streamWriteInt32(streamId, self.state)
	writeNetworkNodeObject(streamId, self.vehicle)
    streamWriteInt32(streamId, self.reference)
    streamWriteBool(streamId, self.isExtendable)
end

function liquidManureHoseDetachEvent:run(connection)
	self.liquidManureHose:detach(self.index, self.state, self.vehicle, self.reference, self.isExtendable, true)
	
	if not connection:getIsServer() then
		g_server:broadcastEvent(self, nil, connection, self.liquidManureHose)
	end
	
	-- if self.state == liquidManureHoseDetachEvent.server then
		-- self.liquidManureHose:detach(self.index, self.state, self.vehicle, self.reference, self.isExtendable, false)
	-- elseif self.state == liquidManureHoseDetachEvent.client then
		-- self.liquidManureHose:detach(self.index, self.state, self.vehicle, self.reference, self.isExtendable, true)
	-- end
   
    -- if not connection:getIsServer() then
        -- -- g_server:broadcastEvent(self, nil, connection, self.object)
        -- g_server:broadcastEvent(liquidManureHoseDetachEvent:new(self.liquidManureHose, self.index, self.state, self.vehicle, self.reference, self.isExtendable), nil, connection, self.liquidManureHose)
    -- end
end

function liquidManureHoseDetachEvent.sendEvent(liquidManureHose, index, state, vehicle, reference, isExtendable, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(liquidManureHoseDetachEvent:new(liquidManureHose, index, state, vehicle, reference, isExtendable), nil, nil, liquidManureHose)
        else
            g_client:getServerConnection():sendEvent(liquidManureHoseDetachEvent:new(liquidManureHose, index, state, vehicle, reference, isExtendable))
        end
    end
end