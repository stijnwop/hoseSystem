--
-- In range vehicle event
--
-- Authors: Wopster
-- Description: Event when an object and reference are in range
--
-- Copyright (c) Wopster, 2017

HoseSystemLoadFillableObjectAndReferenceEvent = {}

HoseSystemLoadFillableObjectAndReferenceEvent_mt = Class(HoseSystemLoadFillableObjectAndReferenceEvent, Event)
InitEventClass(HoseSystemLoadFillableObjectAndReferenceEvent, 'HoseSystemLoadFillableObjectAndReferenceEvent')

function HoseSystemLoadFillableObjectAndReferenceEvent:emptyNew()
    local event = Event:new(HoseSystemLoadFillableObjectAndReferenceEvent_mt)
    return event
end

function HoseSystemLoadFillableObjectAndReferenceEvent:new(object, vehicle, referenceId, isExtendable)
    local event = HoseSystemLoadFillableObjectAndReferenceEvent:emptyNew()

    event.object = object
    event.vehicle = vehicle
    event.referenceId = referenceId
    event.isExtendable = isExtendable

    return event
end

function HoseSystemLoadFillableObjectAndReferenceEvent:writeStream(streamId, connection)
    writeNetworkNodeObject(streamId, self.object)
    writeNetworkNodeObjectId(streamId, self.vehicle)
    streamWriteUIntN(streamId, self.referenceId - 1, HoseSystemUtil.eventHelper.REFERENCES_NUM_SEND_BITS)
    streamWriteBool(streamId, self.isExtendable)
end

function HoseSystemLoadFillableObjectAndReferenceEvent:readStream(streamId, connection)
    self.object = readNetworkNodeObject(streamId)
    self.vehicle = readNetworkNodeObjectId(streamId)
    self.referenceId = streamReadUIntN(streamId, HoseSystemUtil.eventHelper.REFERENCES_NUM_SEND_BITS) + 1
    self.isExtendable = streamReadBool(streamId)
    self:run(connection)
end

function HoseSystemLoadFillableObjectAndReferenceEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(self, false, connection, self.object)
    end

    -- if not connection:getIsServer() then
    -- g_server:broadcastEvent(HoseSystemLoadFillableObjectAndReferenceEvent:new(self.object, self.vehicle, self.reference, self.isExtendable), nil, connection, self.object)
    -- end

    if self.object ~= nil then
        self.object.poly.references:loadFillableObjectAndReference(self.vehicle, self.referenceId, self.isExtendable, true)
    end
end

function HoseSystemLoadFillableObjectAndReferenceEvent.sendEvent(object, vehicle, referenceId, isExtendable, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(HoseSystemLoadFillableObjectAndReferenceEvent:new(object, vehicle, referenceId, isExtendable), nil, nil, object)
        else
            g_client:getServerConnection():sendEvent(HoseSystemLoadFillableObjectAndReferenceEvent:new(object, vehicle, referenceId, isExtendable))
        end
    end
end