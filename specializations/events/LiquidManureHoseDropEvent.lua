--
-- Created by IntelliJ IDEA.
-- User: stijn
-- Date: 15-12-2015
-- Time: 13:26
-- To change this template use File | Settings | File Templates.
--

liquidManureHoseDropEvent = {
	initialise = 1,
	server = 2,
	client = 3
}

liquidManureHoseDropEvent_mt = Class(liquidManureHoseDropEvent, Event)
InitEventClass(liquidManureHoseDropEvent, 'liquidManureHoseDropEvent')

function liquidManureHoseDropEvent:emptyNew()
    local self = Event:new(liquidManureHoseDropEvent_mt)
    self.className = 'liquidManureHoseDropEvent'

    return self
end

function liquidManureHoseDropEvent:new(liquidManureHose, index, player, state)
    local self = liquidManureHoseDropEvent:emptyNew()
    self.liquidManureHose = liquidManureHose
    self.index = index
    self.player = player
	self.state = state
	
    return self
end

function liquidManureHoseDropEvent:writeStream(streamId, connection)
    writeNetworkNodeObject(streamId, self.liquidManureHose)
    streamWriteInt32(streamId, self.index)
    writeNetworkNodeObject(streamId, self.player)
	streamWriteInt32(streamId, self.state)
end

function liquidManureHoseDropEvent:readStream(streamId, connection)
    self.liquidManureHose = readNetworkNodeObject(streamId)
    self.index = streamReadInt32(streamId)
    self.player = readNetworkNodeObject(streamId)
	self.state = streamReadInt32(streamId)
    self:run(connection)
end

function liquidManureHoseDropEvent:run(connection)
	if not connection:getIsServer() then
		g_server:broadcastEvent(self, false, connection, self.liquidManureHose)
	end

	self.liquidManureHose:drop(self.index, self.player, self.state, true)
	
	-- if self.state == liquidManureHoseDropEvent.server then
		-- self.liquidManureHose:drop(self.index, self.player, self.state, true)
	-- elseif self.state == liquidManureHoseDropEvent.client then
		-- self.liquidManureHose:drop(self.index, self.player, self.state, true)
	-- end

    -- if not connection:getIsServer() then
        -- g_server:broadcastEvent(liquidManureHoseDropEvent:new(self.liquidManureHose, self.index, self.player, self.state), nil, connection, self.liquidManureHose)
    -- end
end

function liquidManureHoseDropEvent.sendEvent(liquidManureHose, index, player, state, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(liquidManureHoseDropEvent:new(liquidManureHose, index, player, state), nil, nil, liquidManureHose)
        else
            g_client:getServerConnection():sendEvent(liquidManureHoseDropEvent:new(liquidManureHose, index, player, state))
        end
    end
end