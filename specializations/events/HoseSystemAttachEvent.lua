--
-- Attach event
--
-- Authors: Wopster
-- Description: Event when the hose is being attached to an object
--
-- Copyright (c) Wopster, 2017


HoseSystemAttachEvent = {}

HoseSystemAttachEvent_mt = Class(HoseSystemAttachEvent, Event)
InitEventClass(HoseSystemAttachEvent, 'HoseSystemAttachEvent')

function HoseSystemAttachEvent:emptyNew()
    local event = Event:new(HoseSystemAttachEvent_mt)
    return event
end

function HoseSystemAttachEvent:new(object, index, vehicle, referenceId, isExtendable)
    local event = HoseSystemAttachEvent:emptyNew()

    event.object = object
    event.index = index
    event.vehicle = vehicle
    event.referenceId = referenceId
    event.isExtendable = isExtendable

    return event
end

function HoseSystemAttachEvent:writeStream(streamId, connection)
    writeNetworkNodeObject(streamId, self.object)
    streamWriteUIntN(streamId, self.index - 1, HoseSystemUtil.eventHelper.GRABPOINTS_NUM_SEND_BITS)
    writeNetworkNodeObject(streamId, self.vehicle)
    streamWriteUIntN(streamId, self.referenceId - 1, HoseSystemUtil.eventHelper.REFERENCES_NUM_SEND_BITS)
    streamWriteBool(streamId, self.isExtendable)
end

function HoseSystemAttachEvent:readStream(streamId, connection)
    self.object = readNetworkNodeObject(streamId)
    self.index = streamReadUIntN(streamId, HoseSystemUtil.eventHelper.GRABPOINTS_NUM_SEND_BITS) + 1
    self.vehicle = readNetworkNodeObject(streamId)
    self.referenceId = streamReadUIntN(streamId, HoseSystemUtil.eventHelper.REFERENCES_NUM_SEND_BITS) + 1
    self.isExtendable = streamReadBool(streamId)
    self:run(connection)
end

function HoseSystemAttachEvent:run(connection)
    self.object.poly.interactiveHandling:attach(self.index, self.vehicle, self.referenceId, self.isExtendable, true)

    if not connection:getIsServer() then
        g_server:broadcastEvent(self, false, connection, self.object)
    end
end

function HoseSystemAttachEvent.sendEvent(object, index, vehicle, referenceId, isExtendable, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(HoseSystemAttachEvent:new(object, index, vehicle, referenceId, isExtendable), nil, nil, object)
        else
            g_client:getServerConnection():sendEvent(HoseSystemAttachEvent:new(object, index, vehicle, referenceId, isExtendable))
        end
    end
end