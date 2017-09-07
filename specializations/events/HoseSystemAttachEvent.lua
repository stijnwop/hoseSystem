--
-- Created by IntelliJ IDEA.
-- User: stijn
-- Date: 15-12-2015
-- Time: 13:26
-- To change this template use File | Settings | File Templates.
--

HoseSystemAttachEvent = {}

HoseSystemAttachEvent_mt = Class(HoseSystemAttachEvent, Event)
InitEventClass(HoseSystemAttachEvent, 'HoseSystemAttachEvent')

function HoseSystemAttachEvent:emptyNew()
    local event = Event:new(HoseSystemAttachEvent_mt)
    return event
end

function HoseSystemAttachEvent:new(object, index, vehicle, reference, isExtendable)
    local event = HoseSystemAttachEvent:emptyNew()

    event.object = object
    event.index = index
    event.vehicle = vehicle
    event.reference = reference
    event.isExtendable = isExtendable
	
    return event
end

function HoseSystemAttachEvent:writeStream(streamId, connection)
    writeNetworkNodeObject(streamId, self.object)
    streamWriteInt32(streamId, self.index)
    writeNetworkNodeObject(streamId, self.vehicle)
    streamWriteInt32(streamId, self.reference)
    streamWriteBool(streamId, self.isExtendable)
end

function HoseSystemAttachEvent:readStream(streamId, connection)
    self.object = readNetworkNodeObject(streamId)
    self.index = streamReadInt32(streamId)
    self.vehicle = readNetworkNodeObject(streamId)
    self.reference = streamReadInt32(streamId)
    self.isExtendable = streamReadBool(streamId)
    self:run(connection)
end

function HoseSystemAttachEvent:run(connection)
	self.object.poly.interactiveHandling:attach(self.index, self.vehicle, self.reference, self.isExtendable, true)

	if not connection:getIsServer() then
		g_server:broadcastEvent(self, nil, connection, self.object)
	end
end

function HoseSystemAttachEvent.sendEvent(object, index, vehicle, reference, isExtendable, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(HoseSystemAttachEvent:new(object, index, vehicle, reference, isExtendable), nil, nil, object)
        else
            g_client:getServerConnection():sendEvent(HoseSystemAttachEvent:new(object, index, vehicle, reference, isExtendable))
        end
    end
end