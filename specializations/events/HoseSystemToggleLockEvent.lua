--
-- Lock event
--
-- Authors: Wopster
-- Description: Event the current lock state of the extendable grabpoint
--
-- Copyright (c) Wopster, 2017


HoseSystemToggleLockEvent = {}
HoseSystemToggleLockEvent_mt = Class(HoseSystemToggleLockEvent, Event)
InitEventClass(HoseSystemToggleLockEvent, 'HoseSystemToggleLockEvent')

function HoseSystemToggleLockEvent:emptyNew()
    local event = Event:new(HoseSystemToggleLockEvent_mt)
    return event
end

function HoseSystemToggleLockEvent:new(object, index, bool)
    local event = HoseSystemToggleLockEvent:emptyNew()

    event.object = object
    event.index = index
    event.bool = bool

    return event
end

function HoseSystemToggleLockEvent:writeStream(streamId, connection)
    streamWriteInt32(streamId, networkGetObjectId(self.object))
    streamWriteUIntN(streamId, self.index - 1, HoseSystemUtil.eventHelper.GRABPOINTS_NUM_SEND_BITS)
    streamWriteBool(streamId, self.bool)
end

function HoseSystemToggleLockEvent:readStream(streamId, connection)
    self.object = networkGetObject(streamReadInt32(streamId))
    self.index = streamReadUIntN(streamId, HoseSystemUtil.eventHelper.GRABPOINTS_NUM_SEND_BITS) + 1
    self.bool = streamReadBool(streamId)
    self:run(connection)
end

function HoseSystemToggleLockEvent:run(connection)
    self.object:toggleLock(self.index, self.bool, true)

    if not connection:getIsServer() then
        g_server:broadcastEvent(self, false, connection, self.object)
    end
end

function HoseSystemToggleLockEvent.sendEvent(object, index, bool, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(HoseSystemToggleLockEvent:new(object, index, bool), nil, nil, object)
        else
            g_client:getServerConnection():sendEvent(HoseSystemToggleLockEvent:new(object, index, bool))
        end
    end
end