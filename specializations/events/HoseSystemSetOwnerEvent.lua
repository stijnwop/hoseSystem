--
-- Owner event
--
-- Authors: Wopster
-- Description: Event the current owner of the hose
--
-- Copyright (c) Wopster, 2017

HoseSystemSetOwnerEvent = {}
HoseSystemSetOwnerEvent_mt = Class(HoseSystemSetOwnerEvent, Event)

InitEventClass(HoseSystemSetOwnerEvent, 'HoseSystemSetOwnerEvent')

function HoseSystemSetOwnerEvent:emptyNew()
    local event = Event:new(HoseSystemSetOwnerEvent_mt)

    return event
end

function HoseSystemSetOwnerEvent:new(object, index, state, player)
    local event = HoseSystemSetOwnerEvent:emptyNew()

    event.object = object
    event.index = index
    event.state = state
    event.player = player

    return event
end

function HoseSystemSetOwnerEvent:writeStream(streamId, connection)
    writeNetworkNodeObject(streamId, self.object)
    streamWriteUIntN(streamId, self.index - 1, HoseSystemUtil.eventHelper.GRABPOINTS_NUM_SEND_BITS)
    streamWriteBool(streamId, self.state)
    writeNetworkNodeObject(streamId, self.player)
end

function HoseSystemSetOwnerEvent:readStream(streamId, connection)
    self.object = readNetworkNodeObject(streamId)
    self.index = streamReadUIntN(streamId, HoseSystemUtil.eventHelper.GRABPOINTS_NUM_SEND_BITS) + 1
    self.state = streamReadBool(streamId)
    self.player = readNetworkNodeObject(streamId)
    self:run(connection)
end

function HoseSystemSetOwnerEvent:run(connection)
    self.object.poly.interactiveHandling:setGrabPointOwner(self.index, self.state, self.player, true)

    if not connection:getIsServer() then
        g_server:broadcastEvent(self, false, connection, self.object)
    end
end

function HoseSystemSetOwnerEvent.sendEvent(object, index, state, player, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(HoseSystemSetOwnerEvent:new(object, index, state, player), nil, nil, object)
        else
            g_client:getServerConnection():sendEvent(HoseSystemSetOwnerEvent:new(object, index, state, player))
        end
    end
end