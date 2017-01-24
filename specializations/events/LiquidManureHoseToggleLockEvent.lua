---
-- Created by IntelliJ IDEA.
-- Author: Wopster
-- Date: 28-7-2016
-- Time: 21:09
--
--
--

liquidManureHoseToggleLockEvent = {}
liquidManureHoseToggleLockEvent_mt = Class(liquidManureHoseToggleLockEvent, Event)
InitEventClass(liquidManureHoseToggleLockEvent, 'liquidManureHoseToggleLockEvent')

function liquidManureHoseToggleLockEvent:emptyNew()
    local self = Event:new(liquidManureHoseToggleLockEvent_mt)
    self.className = 'liquidManureHoseToggleLockEvent'

    return self
end

function liquidManureHoseToggleLockEvent:new(liquidManureHose, bool)
    local self = liquidManureHoseToggleLockEvent:emptyNew()
    self.liquidManureHose = liquidManureHose
    self.bool = bool

    return self
end

function liquidManureHoseToggleLockEvent:writeStream(streamId, connection)
    streamWriteInt32(streamId, networkGetObjectId(self.liquidManureHose))
    streamWriteBool(streamId, self.bool)
end

function liquidManureHoseToggleLockEvent:readStream(streamId, connection)
    self.liquidManureHose = networkGetObject(streamReadInt32(streamId))
    self.bool = streamReadBool(streamId)
    self:run(connection)
end

function liquidManureHoseToggleLockEvent:run(connection)
	self.liquidManureHose:toggleLock(self.bool, true)

    if not connection:getIsServer() then
        g_server:broadcastEvent(liquidManureHoseToggleLockEvent:new(self.liquidManureHose, self.bool), nil, connection, self.liquidManureHose)
    end
end

function liquidManureHoseToggleLockEvent.sendEvent(liquidManureHose, bool, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(liquidManureHoseToggleLockEvent:new(liquidManureHose, bool), nil, nil, liquidManureHose)
        else
            g_client:getServerConnection():sendEvent(liquidManureHoseToggleLockEvent:new(liquidManureHose, bool))
        end
    end
end