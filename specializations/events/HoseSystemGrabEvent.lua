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

function HoseSystemGrabEvent:new(object, index, player, syncState)
    local event = HoseSystemGrabEvent:emptyNew()

    event.object = object
    event.index = index
    event.player = player
    event.syncState = syncState

    return event
end

function HoseSystemGrabEvent:writeStream(streamId, connection)
    writeNetworkNodeObject(streamId, self.object)
    streamWriteInt32(streamId, self.index)
    writeNetworkNodeObject(streamId, self.player)
    streamWriteUIntN(streamId, self.syncState, 3)
end

function HoseSystemGrabEvent:readStream(streamId, connection)
    self.object = readNetworkNodeObject(streamId)
    self.index = streamReadInt32(streamId)
    self.player = readNetworkNodeObject(streamId)
    self.syncState = streamReadUIntN(streamId, 3)
    self:run(connection)
end

function HoseSystemGrabEvent:run(connection)
    if self.syncState == HoseSystemUtil.eventHelper.STATE_CLIENT or self.syncState == HoseSystemUtil.eventHelper.STATE_SERVER then
        self.object.poly.interactiveHandling:grab(self.index, self.player, self.syncState, true)
    end

	if not connection:getIsServer() then
		g_server:broadcastEvent(self, nil, connection, self.object)
	end
end

function HoseSystemGrabEvent.sendEvent(object, index, player, syncState, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(HoseSystemGrabEvent:new(object, index, player, syncState), nil, nil, object)
        else
            g_client:getServerConnection():sendEvent(HoseSystemGrabEvent:new(object, index, player, syncState))
        end
    end
end