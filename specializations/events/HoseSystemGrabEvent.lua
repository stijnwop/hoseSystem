---
-- Created by IntelliJ IDEA.
-- Author: Wopster
-- Date: 28-7-2016
-- Time: 21:09
--
--
--

HoseSystemGrabEvent = {}

HoseSystemGrabEvent_mt = Class(HoseSystemGrabEvent, Event)
InitEventClass(HoseSystemGrabEvent, 'HoseSystemGrabEvent')

function HoseSystemGrabEvent:emptyNew()
    local event = Event:new(HoseSystemGrabEvent_mt)
    return event
end

function HoseSystemGrabEvent:new(object, index, player)
    local event = HoseSystemGrabEvent:emptyNew()

    event.object = object
    event.index = index
    event.player = player

    return event
end

function HoseSystemGrabEvent:writeStream(streamId, connection)
    writeNetworkNodeObject(streamId, self.object)
    streamWriteInt32(streamId, self.index)
    writeNetworkNodeObject(streamId, self.player)
end

function HoseSystemGrabEvent:readStream(streamId, connection)
    self.object = readNetworkNodeObject(streamId)
    self.index = streamReadInt32(streamId)
    self.player = readNetworkNodeObject(streamId)
    self:run(connection)
end

function HoseSystemGrabEvent:run(connection)
	if not connection:getIsServer() then
		g_server:broadcastEvent(self, false, connection, self.object)
	end
	
	self.object:grab(self.index, self.player, self.state, true)
end

function HoseSystemGrabEvent.sendEvent(object, index, player, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(HoseSystemGrabEvent:new(object, index, player), nil, nil, object)
        else
            g_client:getServerConnection():sendEvent(HoseSystemGrabEvent:new(object, index, player))
        end
    end
end