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

function HoseSystemLoadFillableObjectAndReferenceEvent:new(liquidManureHose, vehicle, reference, isExtendable)
    local self = HoseSystemLoadFillableObjectAndReferenceEvent:emptyNew()
    self.liquidManureHose = liquidManureHose
    self.vehicle = vehicle
    self.reference = reference
    self.isExtendable = isExtendable

    return self
end

function HoseSystemLoadFillableObjectAndReferenceEvent:readStream(streamId, connection)
    self.liquidManureHose = readNetworkNodeObject(streamId)
    self.vehicle = readNetworkNodeObjectId(streamId)
    self.reference = streamReadInt32(streamId)
    self.isExtendable = streamReadBool(streamId)
    self:run(connection)
end

function HoseSystemLoadFillableObjectAndReferenceEvent:writeStream(streamId, connection)
    writeNetworkNodeObject(streamId, self.liquidManureHose)
    writeNetworkNodeObjectId(streamId, self.vehicle)
    streamWriteInt32(streamId, self.reference)
    streamWriteBool(streamId, self.isExtendable)
end

function HoseSystemLoadFillableObjectAndReferenceEvent:run(connection)
	if not connection:getIsServer() then
		g_server:broadcastEvent(self, false, connection, self.liquidManureHose)
	end
	
	-- if not connection:getIsServer() then
        -- g_server:broadcastEvent(HoseSystemLoadFillableObjectAndReferenceEvent:new(self.liquidManureHose, self.vehicle, self.reference, self.isExtendable), nil, connection, self.liquidManureHose)
    -- end
	
	if self.liquidManureHose ~= nil then
		self.liquidManureHose:loadFillableObjectAndReference(self.vehicle, self.reference, self.isExtendable, true)
	end
end

function HoseSystemLoadFillableObjectAndReferenceEvent.sendEvent(liquidManureHose, vehicle, reference, isExtendable, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(HoseSystemLoadFillableObjectAndReferenceEvent:new(liquidManureHose, vehicle, reference, isExtendable), nil, nil, liquidManureHose)
        else
            g_client:getServerConnection():sendEvent(HoseSystemLoadFillableObjectAndReferenceEvent:new(liquidManureHose, vehicle, reference, isExtendable))
        end
    end
end