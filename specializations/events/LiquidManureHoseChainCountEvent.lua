---
-- Created by IntelliJ IDEA.
-- Author: Wopster
-- Date: 28-7-2016
-- Time: 21:09
--
--
--

liquidManureHoseChainCountEvent = {}
liquidManureHoseChainCountEvent_mt = Class(liquidManureHoseChainCountEvent, Event)
InitEventClass(liquidManureHoseChainCountEvent, 'liquidManureHoseChainCountEvent')

function liquidManureHoseChainCountEvent:emptyNew()
    local self = Event:new(liquidManureHoseChainCountEvent_mt)
    self.className = 'liquidManureHoseChainCountEvent'

    return self
end

function liquidManureHoseChainCountEvent:new(liquidManureHose, count)
    local self = liquidManureHoseChainCountEvent:emptyNew()
    self.liquidManureHose = liquidManureHose
    self.count = count

    return self
end

function liquidManureHoseChainCountEvent:writeStream(streamId, connection)
	writeNetworkNodeObject(streamId, self.liquidManureHose)
    streamWriteInt32(streamId, self.count)
end

function liquidManureHoseChainCountEvent:readStream(streamId, connection)
    self.liquidManureHose = readNetworkNodeObject(streamId)
    self.count = streamReadInt32(streamId)
    self:run(connection)
end

function liquidManureHoseChainCountEvent:run(connection)
	if not connection:getIsServer() then
		g_server:broadcastEvent(self, false, connection, self.liquidManureHose)
	end
	
    -- if not connection:getIsServer() then
        -- g_server:broadcastEvent(liquidManureHoseChainCountEvent:new(self.liquidManureHose, self.count), nil, connection, self.liquidManureHose)
    -- end
	
	if self.liquidManureHose ~= nil then
		self.liquidManureHose:setChainCount(self.count, true)
	end
end

function liquidManureHoseChainCountEvent.sendEvent(liquidManureHose, count, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(liquidManureHoseChainCountEvent:new(liquidManureHose, count), nil, nil, liquidManureHose)
        else
            g_client:getServerConnection():sendEvent(liquidManureHoseChainCountEvent:new(liquidManureHose, count))
        end
    end
end