---
-- Created by IntelliJ IDEA.
-- Author: Wopster
-- Date: 28-7-2016
-- Time: 21:09
--
--
--

HoseSystemChainCountEvent = {}
HoseSystemChainCountEvent_mt = Class(HoseSystemChainCountEvent, Event)
InitEventClass(HoseSystemChainCountEvent, 'HoseSystemChainCountEvent')

function HoseSystemChainCountEvent:emptyNew()
    local event = Event:new(HoseSystemChainCountEvent_mt)
    return event
end

function HoseSystemChainCountEvent:new(object, count)
    local event = HoseSystemChainCountEvent:emptyNew()

    event.object = object
    event.count = count

    return event
end

function HoseSystemChainCountEvent:writeStream(streamId, connection)
	writeNetworkNodeObject(streamId, self.object)
    streamWriteInt32(streamId, self.count)
end

function HoseSystemChainCountEvent:readStream(streamId, connection)
    self.object = readNetworkNodeObject(streamId)
    self.count = streamReadInt32(streamId)
    self:run(connection)
end

function HoseSystemChainCountEvent:run(connection)
	if not connection:getIsServer() then
		g_server:broadcastEvent(self, false, connection, self.object)
	end
	
    -- if not connection:getIsServer() then
        -- g_server:broadcastEvent(liquidManureHoseChainCountEvent:new(self.liquidManureHose, self.count), nil, connection, self.liquidManureHose)
    -- end
	
	if self.object ~= nil then
		self.object:setChainCount(self.count, true)
	end
end

function HoseSystemChainCountEvent.sendEvent(object, count, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(HoseSystemChainCountEvent:new(object, count), nil, nil, object)
        else
            g_client:getServerConnection():sendEvent(HoseSystemChainCountEvent:new(object, count))
        end
    end
end