--
--	Manual Hose Event: liquidManureHoseSetOwnerEvent
--
--	@author: 	 Wopster
--	@descripion:
--	@website:
--	@history:	 v1.0 - 2016-02-21 - Initial implementation
--

HoseSystemSetOwnerEvent = {}
HoseSystemSetOwnerEvent_mt = Class(HoseSystemSetOwnerEvent, Event)
InitEventClass(HoseSystemSetOwnerEvent, 'HoseSystemSetOwnerEvent')

function HoseSystemSetOwnerEvent:emptyNew()
    local event = Event:new(HoseSystemSetOwnerEvent_mt)

    return event
end

function HoseSystemSetOwnerEvent:new(object, index, state, player)
    local event = HoseSystemSetOwnerEvent:emptyNew()

    event.object = object
    event.index = index
    event.state = state
    event.player = player

    return event
end

function HoseSystemSetOwnerEvent:writeStream(streamId, connection)
    streamWriteInt32(streamId, networkGetObjectId(self.object))
    streamWriteInt32(streamId, self.index)
    streamWriteBool(streamId, self.state)
    streamWriteInt32(streamId, networkGetObjectId(self.player))
end

function HoseSystemSetOwnerEvent:readStream(streamId, connection)
    self.object = networkGetObject(streamReadInt32(streamId))
    self.index = streamReadInt32(streamId)
    self.state = streamReadBool(streamId)
    self.player = networkGetObject(streamReadInt32(streamId))
    self:run(connection)
end

function HoseSystemSetOwnerEvent:run(connection)
    self.object.poly.interactiveHandling:setGrabPointOwner(self.index, self.state, self.player, true)

    if not connection:getIsServer() then
        g_server:broadcastEvent(HoseSystemSetOwnerEvent:new(self.object, self.index, self.state, self.player), nil, connection, self.object)
    end
end

function HoseSystemSetOwnerEvent.sendEvent(object, index, state, player, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(HoseSystemSetOwnerEvent:new(object, index, state, player), nil, nil, object)
        else
            g_client:getServerConnection():sendEvent(HoseSystemSetOwnerEvent:new(object, index, state, player))
        end
    end
end