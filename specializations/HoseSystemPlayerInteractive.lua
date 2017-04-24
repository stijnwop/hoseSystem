--
-- Created by IntelliJ IDEA.
-- User: stijn
-- Date: 14-4-2017
-- Time: 00:09
-- To change this template use File | Settings | File Templates.
--

HoseSystemPlayerInteractive = {}
local HoseSystemPlayerInteractive_mt = Class(HoseSystemPlayerInteractive)

function HoseSystemPlayerInteractive:new(object, mt)
    local playerInteractive = {
        object = object
    }

    setmetatable(playerInteractive, mt == nil and HoseSystemPlayerInteractive_mt or mt)

    playerInteractive.minDistance = 2

    return playerInteractive
end

function HoseSystemPlayerInteractive:delete()
end

function HoseSystemPlayerInteractive:update(dt)
end

function HoseSystemPlayerInteractive:draw()
end

function HoseSystemPlayerInteractive:getIsPlayerInGrabPointRange()
    if not self:getIsPlayerValid() then
        return false, nil
    end

    local closestIndex

    if self.object.grabPoints ~= nil then
        local distance = math.huge
        local playerTrans = {getWorldTranslation(g_currentMission.player.rootNode)}
        local playerDistance = self.minDistance

        for index, grabPoint in pairs(self.object.grabPoints) do
            if grabPoint.node ~= nil then
                local trans = {getWorldTranslation(grabPoint.node)}
                local gpDistance = Utils.vector3Length(trans[1] - playerTrans[1], trans[2] - playerTrans[2], trans[3] - playerTrans[3])

                playerDistance = Utils.getNoNil(grabPoint.playerDistance, self.minDistance)

                if gpDistance < distance and gpDistance < playerDistance then
                    closestIndex = index
                    distance = gpDistance
                end
            end
        end

        if distance < playerDistance then
            return true, closestIndex
        end
    end

    return false, nil
end

function HoseSystemPlayerInteractive:getIsPlayerValid()
    return g_currentMission.controlPlayer and
            g_currentMission.player ~= nil and
            g_gui.currentGui == nil and
            not g_currentMission.isPlayerFrozen and
            not g_currentMission.player.hasHPWLance and
            g_currentMission.player.currentTool == nil and
            not g_currentMission.player.isCarryingObject
end

function HoseSystemPlayerInteractive:renderHelpTextOnNode(node, actionText, inputBinding)
    if node ~= nil then
        local worldX, worldY, worldZ = localToWorld(node, 0, 0.1, 0)
        local x, y, z = project(worldX, worldY, worldZ)

        if x < 0.95 and y < 0.95 and z < 1 and x > 0.05 and y > 0.05 and z > 0 then
            setTextAlignment(RenderText.ALIGN_CENTER)
            setTextColor(1, 1, 1, 1)
            renderText(x, y + 0.01, 0.017, inputBinding)
            renderText(x, y - 0.02, 0.017, actionText)
            setTextAlignment(RenderText.ALIGN_LEFT)
        end
    end
end

-- Todo: refactor below to new format

function HoseSystemPlayerInteractive:playerDelete(superFunc)
    if self.hose ~= nil then -- only server knows this
        if self.activeTool ~= nil and self.activeTool.drop ~= nil then
            self.activeTool:drop(self.activeToolLocationId, self)
        end
    end

    if superFunc ~= nil then
        superFunc(self)
    end
end

function HoseSystemPlayerInteractive:playerOnLeave(superFunc)
    if superFunc ~= nil then
        superFunc(self)
    end

    if self.hose ~= nil and self.hose.node ~= nil then -- only server knows this
        if self.activeTool ~= nil and self.activeTool.drop ~= nil then
            self.activeTool:drop(self.activeToolLocationId, self)
        end
    end
end

function HoseSystemPlayerInteractive:setPlayerTool(superFunc, tool)
    if self.activeTool ~= nil and self.activeToolLocationId ~= nil or self.hose ~= nil and self.hose.node ~= nil then
        return -- cancel
    end

    if superFunc ~= nil then
        superFunc(self, tool)
    end
end

function HoseSystemPlayerInteractive:setPlayerToolById(superFunc, toolId, noEventSend)
    if self.activeTool ~= nil and self.activeToolLocationId ~= nil or self.hose ~= nil and self.hose.node ~= nil then
        return -- cancel
    end

    if superFunc ~= nil then
        superFunc(self, toolId, noEventSend)
    end
end

function HoseSystemPlayerInteractive:highPressureWasherSetIsTurnedOn(superFunc, isTurnedOn, player, noEventSend)
    if player ~= nil then
        if player.activeTool ~= nil and player.activeToolLocationId ~= nil or player.hose ~= nil and player.hose.node ~= nil then
            return -- cancel
        end
    end

    if superFunc ~= nil then
        superFunc(self, isTurnedOn, player, noEventSend)
    end
end

---
-- Override
--

Player.delete = Utils.overwrittenFunction(Player.delete, HoseSystemPlayerInteractive.playerDelete)
Player.onLeave = Utils.overwrittenFunction(Player.onLeave, HoseSystemPlayerInteractive.playerOnLeave)
Player.setTool = Utils.overwrittenFunction(Player.setTool, HoseSystemPlayerInteractive.setPlayerTool)
Player.setToolById = Utils.overwrittenFunction(Player.setToolById, HoseSystemPlayerInteractive.setPlayerToolById)
HighPressureWasher.setIsTurnedOn = Utils.overwrittenFunction(HighPressureWasher.setIsTurnedOn, HoseSystemPlayerInteractive.highPressureWasherSetIsTurnedOn)