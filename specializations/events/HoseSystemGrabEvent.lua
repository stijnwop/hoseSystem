--
-- Grab event
--
-- Authors: Wopster
-- Description: Event when the hose is grabbed by the player
--
-- Copyright (c) Wopster, 2017

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
    streamWriteUIntN(streamId, self.index - 1, HoseSystemUtil.eventHelper.GRABPOINTS_NUM_SEND_BITS)
    writeNetworkNodeObject(streamId, self.player)
    streamWriteUInt8(streamId, self.syncState)
end

function HoseSystemGrabEvent:readStream(streamId, connection)
    self.object = readNetworkNodeObject(streamId)
    self.index = streamReadUIntN(streamId, HoseSystemUtil.eventHelper.GRABPOINTS_NUM_SEND_BITS) + 1
    self.player = readNetworkNodeObject(streamId)
    self.syncState = streamReadUInt8(streamId)
    self:run(connection)
end

function HoseSystemGrabEvent:run(connection)
    if self.syncState == HoseSystemUtil.eventHelper.STATE_CLIENT or self.syncState == HoseSystemUtil.eventHelper.STATE_SERVER then
        self.object.poly.interactiveHandling:grab(self.index, self.player, self.syncState, true)
    end

    if not connection:getIsServer() then
        g_server:broadcastEvent(self, false, connection, self.object)
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