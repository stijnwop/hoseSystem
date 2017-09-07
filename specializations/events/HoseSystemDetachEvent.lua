--
-- Created by IntelliJ IDEA.
-- User: stijn
-- Date: 15-12-2015
-- Time: 13:26
-- To change this template use File | Settings | File Templates.
--

HoseSystemDetachEvent = {}

HoseSystemDetachEvent_mt = Class(HoseSystemDetachEvent, Event)
InitEventClass(HoseSystemDetachEvent, 'HoseSystemDetachEvent')

function HoseSystemDetachEvent:emptyNew()
    local event = Event:new(HoseSystemDetachEvent_mt)
    return event
end

function HoseSystemDetachEvent:new(object, index, vehicle, reference, isExtendable)
    local event = HoseSystemDetachEvent:emptyNew()

    event.object = object
    event.index = index
    event.vehicle = vehicle
    event.reference = reference
    event.isExtendable = isExtendable
	
    return event
end

function HoseSystemDetachEvent:writeStream(streamId, connection)
    writeNetworkNodeObject(streamId, self.object)
    streamWriteInt32(streamId, self.index)
    writeNetworkNodeObject(streamId, self.vehicle)
    streamWriteInt32(streamId, self.reference)
    streamWriteBool(streamId, self.isExtendable)
end

function HoseSystemDetachEvent:readStream(streamId, connection)
    self.object = readNetworkNodeObject(streamId)
    self.index = streamReadInt32(streamId)
	self.vehicle = readNetworkNodeObject(streamId)
    self.reference = streamReadInt32(streamId)
    self.isExtendable = streamReadBool(streamId)
    self:run(connection)
end

function HoseSystemDetachEvent:run(connection)
	self.object.poly.interactiveHandling:detach(self.index, self.vehicle, self.reference, self.isExtendable, true)

	if not connection:getIsServer() then
		g_server:broadcastEvent(self, nil, connection, self.object)
	end
end

function HoseSystemDetachEvent.sendEvent(object, index, vehicle, reference, isExtendable, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(HoseSystemDetachEvent:new(object, index, vehicle, reference, isExtendable), nil, nil, object)
        else
            g_client:getServerConnection():sendEvent(HoseSystemDetachEvent:new(object, index, vehicle, reference, isExtendable))
        end
    end
end