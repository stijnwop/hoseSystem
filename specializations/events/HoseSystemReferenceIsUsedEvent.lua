--
-- Set is used event
--
-- Authors: Wopster
-- Description: Event when the reference is being used by a use to trigger actions
--
-- Copyright (c) Wopster, 2017

HoseSystemReferenceIsUsedEvent = {}
HoseSystemReferenceIsUsedEvent_mt = Class(HoseSystemReferenceIsUsedEvent, Event)

InitEventClass(HoseSystemReferenceIsUsedEvent, 'HoseSystemReferenceIsUsedEvent')

function HoseSystemReferenceIsUsedEvent:emptyNew()
    local event = Event:new(HoseSystemReferenceIsUsedEvent_mt)
    return event
end

function HoseSystemReferenceIsUsedEvent:new(object, referenceId, state)
    local event = HoseSystemReferenceIsUsedEvent:emptyNew()

    event.object = object
    event.referenceId = referenceId
    event.state = state

    return event
end

function HoseSystemReferenceIsUsedEvent:writeStream(streamId, connection)
    streamWriteInt32(streamId, networkGetObjectId(self.object))
    streamWriteUIntN(streamId, self.referenceId - 1, HoseSystemUtil.eventHelper.REFERENCES_NUM_SEND_BITS)
    streamWriteBool(streamId, self.state)
end

function HoseSystemReferenceIsUsedEvent:readStream(streamId, connection)
    self.object = networkGetObject(streamReadInt32(streamId))
    self.referenceId = streamReadUIntN(streamId, HoseSystemUtil.eventHelper.REFERENCES_NUM_SEND_BITS) + 1
    self.state = streamReadBool(streamId)
    self:run(connection)
end

function HoseSystemReferenceIsUsedEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(self, false, connection, self.object)
    end

    self.object:setIsUsed(self.referenceId, self.state, true)
end

function HoseSystemReferenceIsUsedEvent.sendEvent(object, referenceId, state, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(HoseSystemReferenceIsUsedEvent:new(object, referenceId, state), nil, nil, object)
        else
            g_client:getServerConnection():sendEvent(HoseSystemReferenceIsUsedEvent:new(object, referenceId, state))
        end
    end
end