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
    streamWriteUIntN(streamId, self.index, HoseSystemUtil.eventHelper.GRABPOINTS_NUM_SEND_BITS)
    writeNetworkNodeObject(streamId, self.vehicle)
    streamWriteUIntN(streamId, self.referenceId, HoseSystemUtil.eventHelper.REFERENCES_NUM_SEND_BITS)
    streamWriteBool(streamId, self.isExtendable)
end

function HoseSystemDetachEvent:readStream(streamId, connection)
    self.object = readNetworkNodeObject(streamId)
    self.index = streamReadUIntN(streamId, HoseSystemUtil.eventHelper.GRABPOINTS_NUM_SEND_BITS)
	self.vehicle = readNetworkNodeObject(streamId)
    self.referenceId = streamReadUIntN(streamId, HoseSystemUtil.eventHelper.REFERENCES_NUM_SEND_BITS)
    self.isExtendable = streamReadBool(streamId)
    self:run(connection)
end

function HoseSystemDetachEvent:run(connection)
--	self.object.poly.interactiveHandling:detach(self.index, self.vehicle, self.referenceId, self.isExtendable, true)

	if not connection:getIsServer() then
--		g_server:broadcastEvent(self, nil, connection, self.object)
        self.object.poly.interactiveHandling:detach(self.index, self.vehicle, self.referenceId, self.isExtendable)
    else
        self.object.poly.interactiveHandling:detach(self.index, self.vehicle, self.referenceId, self.isExtendable, true)
	end
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