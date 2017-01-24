---
-- Created by IntelliJ IDEA.
-- Author: Wopster
-- Date: 28-7-2016
-- Time: 21:09
--
--
--

liquidManureHoseGrabEvent = {
	initialise = 1,
	server = 2,
	client = 3
}

liquidManureHoseGrabEvent_mt = Class(liquidManureHoseGrabEvent, Event)
InitEventClass(liquidManureHoseGrabEvent, 'liquidManureHoseGrabEvent')

function liquidManureHoseGrabEvent:emptyNew()
    local self = Event:new(liquidManureHoseGrabEvent_mt)
    self.className = 'liquidManureHoseGrabEvent'

    return self
end

function liquidManureHoseGrabEvent:new(liquidManureHose, index, player, state)
    local self = liquidManureHoseGrabEvent:emptyNew()
    self.liquidManureHose = liquidManureHose
    self.index = index
    self.player = player
    self.state = state
	
    return self
end

function liquidManureHoseGrabEvent:writeStream(streamId, connection)
    writeNetworkNodeObject(streamId, self.liquidManureHose)
    streamWriteInt32(streamId, self.index)
    writeNetworkNodeObject(streamId, self.player)
    streamWriteInt32(streamId, self.state)
end

function liquidManureHoseGrabEvent:readStream(streamId, connection)
    self.liquidManureHose = readNetworkNodeObject(streamId)
    self.index = streamReadInt32(streamId)
    self.player = readNetworkNodeObject(streamId)
    self.state = streamReadInt32(streamId)
    self:run(connection)
end

function liquidManureHoseGrabEvent:run(connection)
	if not connection:getIsServer() then
		g_server:broadcastEvent(self, false, connection, self.liquidManureHose)
	end
	
	self.liquidManureHose:grab(self.index, self.player, self.state, true)
	
	-- if self.state == liquidManureHoseGrabEvent.server then
		-- self.liquidManureHose:grab(self.index, self.player, self.state, true)
	-- elseif self.state == liquidManureHoseGrabEvent.client then
		-- self.liquidManureHose:grab(self.index, self.player, self.state, true)
	-- end

    -- if not connection:getIsServer() then
        -- g_server:broadcastEvent(liquidManureHoseGrabEvent:new(self.liquidManureHose, self.index, self.player, self.state), nil, connection, self.liquidManureHose)
    -- end
end

function liquidManureHoseGrabEvent.sendEvent(liquidManureHose, index, player, state, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(liquidManureHoseGrabEvent:new(liquidManureHose, index, player, state), nil, nil, liquidManureHose)
        else
            g_client:getServerConnection():sendEvent(liquidManureHoseGrabEvent:new(liquidManureHose, index, player, state))
        end
    end
end