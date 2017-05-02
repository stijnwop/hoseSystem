---
-- Created by IntelliJ IDEA.
-- Author: Wopster
-- Date: 28-7-2016
-- Time: 21:09
--
--
--

HoseSystemIsUsedEvent = {}
HoseSystemIsUsedEvent_mt = Class(HoseSystemIsUsedEvent, Event)
InitEventClass(HoseSystemIsUsedEvent, 'HoseSystemIsUsedEvent')

function HoseSystemIsUsedEvent:emptyNew()
    local event = Event:new(HoseSystemIsUsedEvent_mt)
    return event
end

function HoseSystemIsUsedEvent:new(object, index, isConnected, isCalledFromReference)
    local event = HoseSystemIsUsedEvent:emptyNew()

    event.object = object
    event.index = index
    event.isConnected = isConnected
    event.isCalledFromReference = isCalledFromReference

    return self
end

function HoseSystemIsUsedEvent:writeStream(streamId, connection)
    writeNetworkNodeObject(streamId, self.object)
    streamWriteInt32(streamId, self.index)
    streamWriteBool(streamId, self.isConnected)
    streamWriteBool(streamId, self.isCalledFromReference)
end

function HoseSystemIsUsedEvent:readStream(streamId, connection)
    self.object = readNetworkNodeObject(streamId)
    self.index = streamReadInt32(streamId)
    self.isConnected = streamReadBool(streamId)
    self.isCalledFromReference = streamReadBool(streamId)
    self:run(connection)
end

function HoseSystemIsUsedEvent:run(connection)
	self.object:setIsUsed(self.index, self.isConnected, self.isCalledFromReference, true)

    if not connection:getIsServer() then
        g_server:broadcastEvent(self, false, connection, self.object)
    end
end

function HoseSystemIsUsedEvent.sendEvent(object, index, isConnected, isCalledFromReference, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(HoseSystemIsUsedEvent:new(object, index, isConnected, isCalledFromReference), nil, nil, object)
        else
            g_client:getServerConnection():sendEvent(HoseSystemIsUsedEvent:new(object, index, isConnected, isCalledFromReference))
        end
    end
end