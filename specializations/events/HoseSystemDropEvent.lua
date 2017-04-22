--
-- Created by IntelliJ IDEA.
-- User: stijn
-- Date: 15-12-2015
-- Time: 13:26
-- To change this template use File | Settings | File Templates.
--

HoseSystemDropEvent = {}

HoseSystemDropEvent_mt = Class(HoseSystemDropEvent, Event)
InitEventClass(HoseSystemDropEvent, 'HoseSystemDropEvent')

function HoseSystemDropEvent:emptyNew()
    local event = Event:new(HoseSystemDropEvent_mt)
    return event
end

function HoseSystemDropEvent:new(object, index, player)
    local event = HoseSystemDropEvent:emptyNew()

    event.object = object
    event.index = index
    event.player = player
	
    return event
end

function HoseSystemDropEvent:writeStream(streamId, connection)
    writeNetworkNodeObject(streamId, self.object)
    streamWriteInt32(streamId, self.index)
    writeNetworkNodeObject(streamId, self.player)
end

function HoseSystemDropEvent:readStream(streamId, connection)
    self.object = readNetworkNodeObject(streamId)
    self.index = streamReadInt32(streamId)
    self.player = readNetworkNodeObject(streamId)
    self:run(connection)
end

function HoseSystemDropEvent:run(connection)
	if not connection:getIsServer() then
		g_server:broadcastEvent(self, false, connection, self.object)
	end

	self.object:drop(self.index, self.player, true)
end

function HoseSystemDropEvent.sendEvent(object, index, player, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(HoseSystemDropEvent:new(object, index, player), nil, nil, object)
        else
            g_client:getServerConnection():sendEvent(HoseSystemDropEvent:new(object, index, player))
        end
    end
end