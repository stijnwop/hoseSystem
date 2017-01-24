---
-- Created by IntelliJ IDEA.
-- Author: Wopster
-- Date: 28-7-2016
-- Time: 21:09
--
--
--

liquidManureHoseIsUsedEvent = {}
liquidManureHoseIsUsedEvent_mt = Class(liquidManureHoseIsUsedEvent, Event)
InitEventClass(liquidManureHoseIsUsedEvent, 'liquidManureHoseIsUsedEvent')

function liquidManureHoseIsUsedEvent:emptyNew()
    local self = Event:new(liquidManureHoseIsUsedEvent_mt)
    self.className = 'liquidManureHoseIsUsedEvent'

    return self
end

function liquidManureHoseIsUsedEvent:new(liquidManureHose, index, isConnected, hasJointIndex, hasExtenableJointIndex)
    local self = liquidManureHoseIsUsedEvent:emptyNew()
    self.liquidManureHose = liquidManureHose
    self.index = index
    self.isConnected = isConnected
    self.hasJointIndex = hasJointIndex
    self.hasExtenableJointIndex = hasExtenableJointIndex

    return self
end

function liquidManureHoseIsUsedEvent:writeStream(streamId, connection)
    writeNetworkNodeObject(streamId, self.liquidManureHose)
    streamWriteInt32(streamId, self.index)
    streamWriteBool(streamId, self.isConnected)
    streamWriteBool(streamId, self.hasJointIndex)
    streamWriteBool(streamId, self.hasExtenableJointIndex)
end

function liquidManureHoseIsUsedEvent:readStream(streamId, connection)
    self.liquidManureHose = readNetworkNodeObject(streamId)
    self.index = streamReadInt32(streamId)
    self.isConnected = streamReadBool(streamId)
    self.hasJointIndex = streamReadBool(streamId)
    self.hasExtenableJointIndex = streamReadBool(streamId)
    self:run(connection)
end

function liquidManureHoseIsUsedEvent:run(connection)
	self.liquidManureHose:setIsUsed(self.index, self.isConnected, self.hasJointIndex, self.hasExtenableJointIndex, true)

    if not connection:getIsServer() then
        g_server:broadcastEvent(liquidManureHoseIsUsedEvent:new(self.liquidManureHose, self.index, self.isConnected, self.hasJointIndex, self.hasExtenableJointIndex), nil, connection, self.liquidManureHose)
    end
end

function liquidManureHoseIsUsedEvent.sendEvent(liquidManureHose, index, isConnected, hasJointIndex, hasExtenableJointIndex, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(liquidManureHoseIsUsedEvent:new(liquidManureHose, index, isConnected, hasJointIndex, hasExtenableJointIndex), nil, nil, liquidManureHose)
        else
            g_client:getServerConnection():sendEvent(liquidManureHoseIsUsedEvent:new(liquidManureHose, index, isConnected, hasJointIndex, hasExtenableJointIndex))
        end
    end
end