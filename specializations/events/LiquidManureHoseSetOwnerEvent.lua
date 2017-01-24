--
--	Manual Hose Event: liquidManureHoseSetOwnerEvent
--
--	@author: 	 Wopster
--	@descripion:
--	@website:
--	@history:	 v1.0 - 2016-02-21 - Initial implementation
--

liquidManureHoseSetOwnerEvent = {}
liquidManureHoseSetOwnerEvent_mt = Class(liquidManureHoseSetOwnerEvent, Event)
InitEventClass(liquidManureHoseSetOwnerEvent, 'liquidManureHoseSetOwnerEvent')

function liquidManureHoseSetOwnerEvent:emptyNew()
    local self = Event:new(liquidManureHoseSetOwnerEvent_mt)
    self.className = 'liquidManureHoseSetOwnerEvent'

    return self
end

function liquidManureHoseSetOwnerEvent:new(liquidManureHose, index, state, player)
    local self = liquidManureHoseSetOwnerEvent:emptyNew()
    self.liquidManureHose = liquidManureHose
    self.index = index
    self.state = state
    self.player = player

    return self
end

function liquidManureHoseSetOwnerEvent:writeStream(streamId, connection)
    streamWriteInt32(streamId, networkGetObjectId(self.liquidManureHose))
    streamWriteInt32(streamId, self.index)
    streamWriteBool(streamId, self.state)
    streamWriteInt32(streamId, networkGetObjectId(self.player))
end

function liquidManureHoseSetOwnerEvent:readStream(streamId, connection)
    self.liquidManureHose = networkGetObject(streamReadInt32(streamId))
    self.index = streamReadInt32(streamId)
    self.state = streamReadBool(streamId)
    self.player = networkGetObject(streamReadInt32(streamId))
    self:run(connection)
end

function liquidManureHoseSetOwnerEvent:run(connection)
    self.liquidManureHose:setOwner(self.index, self.state, self.player, true)

    if not connection:getIsServer() then
        g_server:broadcastEvent(liquidManureHoseSetOwnerEvent:new(self.liquidManureHose, self.index, self.state, self.player), nil, connection, self.liquidManureHose)
    end
end

function liquidManureHoseSetOwnerEvent.sendEvent(liquidManureHose, index, state, player, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(liquidManureHoseSetOwnerEvent:new(liquidManureHose, index, state, player), nil, nil, liquidManureHose)
        else
            g_client:getServerConnection():sendEvent(liquidManureHoseSetOwnerEvent:new(liquidManureHose, index, state, player))
        end
    end
end