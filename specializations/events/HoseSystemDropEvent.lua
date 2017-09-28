--
-- Drop event
--
-- Authors: Wopster
-- Description: Event when the hose is dropped by the player
--
-- Copyright (c) Wopster, 2017

HoseSystemDropEvent = {}
HoseSystemDropEvent_mt = Class(HoseSystemDropEvent, Event)

InitEventClass(HoseSystemDropEvent, 'HoseSystemDropEvent')

function HoseSystemDropEvent:emptyNew()
    local event = Event:new(HoseSystemDropEvent_mt)
    return event
end

function HoseSystemDropEvent:new(object, index, player, syncState)
    local event = HoseSystemDropEvent:emptyNew()

    event.object = object
    event.index = index
    event.player = player
    event.syncState = syncState

    return event
end

function HoseSystemDropEvent:writeStream(streamId, connection)
    writeNetworkNodeObject(streamId, self.object)
    streamWriteUIntN(streamId, self.index - 1, HoseSystemUtil.eventHelper.GRABPOINTS_NUM_SEND_BITS)
    writeNetworkNodeObject(streamId, self.player)
    streamWriteUInt8(streamId, self.syncState)
end

function HoseSystemDropEvent:readStream(streamId, connection)
    self.object = readNetworkNodeObject(streamId)
    self.index = streamReadUIntN(streamId, HoseSystemUtil.eventHelper.GRABPOINTS_NUM_SEND_BITS) + 1
    self.player = readNetworkNodeObject(streamId)
    self.syncState = streamReadUInt8(streamId)

    self:run(connection)
end

function HoseSystemDropEvent:run(connection)
    if self.syncState == HoseSystemUtil.eventHelper.STATE_CLIENT or self.syncState == HoseSystemUtil.eventHelper.STATE_SERVER then
        self.object.poly.interactiveHandling:drop(self.index, self.player, self.syncState, true)
    end

    if not connection:getIsServer() then
        g_server:broadcastEvent(self, false, connection, self.object)
    end
end

function HoseSystemDropEvent.sendEvent(object, index, player, syncState, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(HoseSystemDropEvent:new(object, index, player, syncState), nil, nil, object)
        else
            g_client:getServerConnection():sendEvent(HoseSystemDropEvent:new(object, index, player, syncState))
        end
    end
end