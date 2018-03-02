--
-- Detach event
--
-- Authors: Wopster
-- Description: Event when the hose is being detached from an object
--
-- Copyright (c) Wopster, 2017

HoseSystemDetachEvent = {}
HoseSystemDetachEvent_mt = Class(HoseSystemDetachEvent, Event)

InitEventClass(HoseSystemDetachEvent, 'HoseSystemDetachEvent')

function HoseSystemDetachEvent:emptyNew()
    local event = Event:new(HoseSystemDetachEvent_mt)
    return event
end

function HoseSystemDetachEvent:new(object, index, vehicle, referenceId, isExtendable)
    local event = HoseSystemDetachEvent:emptyNew()

    event.object = object
    event.index = index
    event.vehicle = vehicle
    event.referenceId = referenceId
    event.isExtendable = isExtendable

    return event
end

function HoseSystemDetachEvent:writeStream(streamId, connection)
    writeNetworkNodeObject(streamId, self.object)
    streamWriteUIntN(streamId, self.index - 1, HoseSystemUtil.eventHelper.GRABPOINTS_NUM_SEND_BITS)
    writeNetworkNodeObject(streamId, self.vehicle)
    streamWriteUIntN(streamId, self.referenceId - 1, HoseSystemUtil.eventHelper.REFERENCES_NUM_SEND_BITS)
    streamWriteBool(streamId, self.isExtendable)
end

function HoseSystemDetachEvent:readStream(streamId, connection)
    self.object = readNetworkNodeObject(streamId)
    self.index = streamReadUIntN(streamId, HoseSystemUtil.eventHelper.GRABPOINTS_NUM_SEND_BITS) + 1
    self.vehicle = readNetworkNodeObject(streamId)
    self.referenceId = streamReadUIntN(streamId, HoseSystemUtil.eventHelper.REFERENCES_NUM_SEND_BITS) + 1
    self.isExtendable = streamReadBool(streamId)
    self:run(connection)
end

function HoseSystemDetachEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(self, false, connection, self.object)
        --        self.object.poly.interactiveHandling:detach(self.index, self.vehicle, self.referenceId, self.isExtendable)
        --    else
        --        self.object.poly.interactiveHandling:detach(self.index, self.vehicle, self.referenceId, self.isExtendable, true)
    end

    self.object.poly.interactiveHandling:detach(self.index, self.vehicle, self.referenceId, self.isExtendable, true)
end

function HoseSystemDetachEvent.sendEvent(object, index, vehicle, referenceId, isExtendable, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(HoseSystemDetachEvent:new(object, index, vehicle, referenceId, isExtendable), nil, nil, object)
        else
            g_client:getServerConnection():sendEvent(HoseSystemDetachEvent:new(object, index, vehicle, referenceId, isExtendable))
        end
    end
end