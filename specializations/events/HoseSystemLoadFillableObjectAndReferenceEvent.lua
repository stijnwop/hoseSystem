---
-- Created by IntelliJ IDEA.
-- Author: Wopster
-- Date: 28-7-2016
-- Time: 21:09
--
--
--

HoseSystemLoadFillableObjectAndReferenceEvent = {}

HoseSystemLoadFillableObjectAndReferenceEvent_mt = Class(HoseSystemLoadFillableObjectAndReferenceEvent, Event)
InitEventClass(HoseSystemLoadFillableObjectAndReferenceEvent, 'HoseSystemLoadFillableObjectAndReferenceEvent')

function HoseSystemLoadFillableObjectAndReferenceEvent:emptyNew()
    local event = Event:new(HoseSystemLoadFillableObjectAndReferenceEvent_mt)
    return event
end

function HoseSystemLoadFillableObjectAndReferenceEvent:new(object, vehicle, reference, isExtendable)
    local event = HoseSystemLoadFillableObjectAndReferenceEvent:emptyNew()

    event.object = object
    event.vehicle = vehicle
    event.reference = reference
    event.isExtendable = isExtendable

    return event
end

function HoseSystemLoadFillableObjectAndReferenceEvent:readStream(streamId, connection)
    self.object = readNetworkNodeObject(streamId)
    self.vehicle = readNetworkNodeObjectId(streamId)
    self.reference = streamReadInt32(streamId)
    self.isExtendable = streamReadBool(streamId)
    self:run(connection)
end

function HoseSystemLoadFillableObjectAndReferenceEvent:writeStream(streamId, connection)
    writeNetworkNodeObject(streamId, self.object)
    writeNetworkNodeObjectId(streamId, self.vehicle)
    streamWriteInt32(streamId, self.reference)
    streamWriteBool(streamId, self.isExtendable)
end

function HoseSystemLoadFillableObjectAndReferenceEvent:run(connection)
	if not connection:getIsServer() then
		g_server:broadcastEvent(self, false, connection, self.object)
	end
	
	-- if not connection:getIsServer() then
        -- g_server:broadcastEvent(HoseSystemLoadFillableObjectAndReferenceEvent:new(self.object, self.vehicle, self.reference, self.isExtendable), nil, connection, self.object)
    -- end
	
	if self.object ~= nil then
		self.object:loadFillableObjectAndReference(self.vehicle, self.reference, self.isExtendable, true)
	end
end

function HoseSystemLoadFillableObjectAndReferenceEvent.sendEvent(object, vehicle, reference, isExtendable, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(HoseSystemLoadFillableObjectAndReferenceEvent:new(object, vehicle, reference, isExtendable), nil, nil, object)
        else
            g_client:getServerConnection():sendEvent(HoseSystemLoadFillableObjectAndReferenceEvent:new(object, vehicle, reference, isExtendable))
        end
    end
end