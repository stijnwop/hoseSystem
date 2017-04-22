---
-- Created by IntelliJ IDEA.
-- Author: Wopster
-- Date: 28-7-2016
-- Time: 21:09
--
--
--

HoseSystemActiveGrabPointEvent = {}

HoseSystemActiveGrabPointEvent_mt = Class(HoseSystemActiveGrabPointEvent, Event)
InitEventClass(HoseSystemActiveGrabPointEvent, 'HoseSystemActiveGrabPointEvent')

function HoseSystemActiveGrabPointEvent:emptyNew()
    local event = Event:new(HoseSystemActiveGrabPointEvent_mt)
    return event
end

function HoseSystemActiveGrabPointEvent:new(liquidManureHose, index)
    local self = HoseSystemActiveGrabPointEvent:emptyNew()
    self.liquidManureHose = liquidManureHose
    self.index = index

    return self
end

function HoseSystemActiveGrabPointEvent:readStream(streamId, connection)
	self.liquidManureHose = readNetworkNodeObject(streamId)
	self.index = streamReadInt32(streamId)
	
    self:run(connection)
end

function HoseSystemActiveGrabPointEvent:writeStream(streamId, connection)
    writeNetworkNodeObject(streamId, self.liquidManureHose)
    streamWriteInt32(streamId, self.index)
end

function HoseSystemActiveGrabPointEvent:run(connection)
	self.liquidManureHose:setActiveGrabPointIndex(self.index, true)
	
	if not connection:getIsServer() then
		g_server:broadcastEvent(HoseSystemActiveGrabPointEvent:new(self.liquidManureHose, self.index), nil, connection, self.liquidManureHose)
    end
end

function HoseSystemActiveGrabPointEvent.sendEvent(liquidManureHose, index, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(HoseSystemActiveGrabPointEvent:new(liquidManureHose, index), nil, nil, liquidManureHose)
        else
            g_client:getServerConnection():sendEvent(HoseSystemActiveGrabPointEvent:new(liquidManureHose, index))
        end
    end
end