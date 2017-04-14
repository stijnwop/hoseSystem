--
-- Created by IntelliJ IDEA.
-- User: stijn
-- Date: 13-4-2017
-- Time: 18:36
-- To change this template use File | Settings | File Templates.
--

HoseSystem = {
    debugRendering = true,
    modDir = g_currentModDirectory,
    eventsDir = g_currentModDirectory .. "specializations/events"
}

source(('%sspecializations/%s'):format(HoseSystem.modDir, 'HoseSystemPlayerInteractive.lua'))
source(('%sspecializations/%s'):format(HoseSystem.modDir, 'HoseSystemPlayerInteractiveHandling.lua'))

HoseSystem.STATE_ATTACHED = 0
HoseSystem.STATE_DETACHED = 1
HoseSystem.STATE_CONNECTED = 2
HoseSystem.STATE_PARKED = 3

HoseSystem.cctCollisionMask = 32  -- bit 00000000000000000000000000110010
HoseSystem.hoseCollisionMask = 8194

---
-- @param specializations
--
function HoseSystem.prerequisitesPresent(specializations)
    return true
end

---
-- @param savegame
--
function HoseSystem:preLoad(savegame)
    self.loadHoseJoints = HoseSystem.loadHoseJoints
    self.loadGrabPoints = HoseSystem.loadGrabPoints
    self.updateMesh = HoseSystem.updateMesh

--    self.loadObjectChangeValuesFromXML = Utils.overwrittenFunction(self.loadObjectChangeValuesFromXML, HoseSystem.loadObjectChangeValuesFromXML)
--    self.setObjectChangeValues = Utils.overwrittenFunction(self.setObjectChangeValues, HoseSystem.setObjectChangeValues)
end

---
-- @param savegame
--
function HoseSystem:load(savegame)
    self.jointSpline = {}
    self.grabPoints = {}
    self.nodesToGrabPoints = {}

--    self.hoseSystemActivatable = HoseSystemActivatable:new(self)

    self:loadHoseJoints(self.xmlFile, 'vehicle.hoseSystem.jointSpline')
    self:loadGrabPoints(self.xmlFile, 'vehicle.hoseSystem.grabPoints')

--    print(HoseSystem:print_r(self.grabPoints))

    local startTrans = {getWorldTranslation(self.components[1].node)}
    local endTrans = {getWorldTranslation(self.components[self.jointSpline.endComponentId].node)}

    self.data = {
        length = Utils.vector3Length(endTrans[1] - startTrans[1], endTrans[2] - startTrans[2], endTrans[3] - startTrans[3]),
        lastInRangePosition = { 0, 0, 0 },
        rangeRestrictionMessageShown = false
    }

    self.supportedFillTypes = {}

    local fillTypeCategories = getXMLString(self.xmlFile, 'vehicle.hoseSystem#supportedFillTypeCategories')

    if fillTypeCategories ~= nil then
        local fillTypes = FillUtil.getFillTypeByCategoryName(fillTypeCategories, "Warning: '" .. self.configFileName .. "' has invalid fillTypeCategory '%s'.")

        if fillTypes ~= nil then
            for _, fillType in pairs(fillTypes) do
                self.supportedFillTypes[fillType] = true
            end
        end
    end

    self.polymorphismClasses = {}

    table.insert(self.polymorphismClasses, HoseSystemPlayerInteractiveHandling:new(self))
end

function HoseSystem:loadHoseJoints(xmlFile, baseString)
    local entry = {}
    local rootJointNode = Utils.indexToObject(self.components, getXMLString(xmlFile, ('%s#rootJointNode'):format(baseString)))
    local jointCount = getXMLInt(xmlFile, ('%s#numJoints'):format(baseString))

    entry.hoseJoints = {}

    if rootJointNode ~= nil and jointCount ~= nil then
        for i = 1, jointCount do
            local count = table.getn(entry.hoseJoints)
            local jointNode = count > 0 and getChildAt(entry.hoseJoints[count].node, 0) or rootJointNode

            if jointNode ~= nil then
                table.insert(entry.hoseJoints, {
                    node = jointNode,
                    parent = getParent(jointNode)
                })
            end
        end
    end

    entry.curveControllerTrans = Utils.getNoNil(Utils.getVectorNFromString(getXMLString(xmlFile, ('%s#curveControllerTrans'):format(baseString)), 3), { 0, 0, 7.5 }) -- set curve "controller" trans relative to grabPoints
    entry.numJoints = #entry.hoseJoints
    entry.endComponentId = #self.components
    entry.lastPosition = {{ 0, 0, 0 }, { 0, 0, 0 }}
    entry.firstRunUpdates = 0
    entry.firstNumRunUpdates = Utils.getNoNil(getXMLInt(xmlFile, ('%s#firstNumRunUpdates'):format(baseString)), 7)
    entry.length = getXMLFloat(xmlFile, 'vehicle.size#length')

    if entry.numJoints > 0 then -- we should confirm that 1 or 2 attacherJoints are in place too.
        -- store "hose" in an global table for faster distance check later on
        if g_currentMission.liquidManureHoses == nil then
            g_currentMission.liquidManureHoses = {}
        end

        table.insert(g_currentMission.liquidManureHoses, self)
    end

    self.jointSpline = entry
end

function HoseSystem:loadGrabPoints(xmlFile, baseString)
    local i = 0

    while true do
        local key = ('%s.grabPoint(%d)'):format(baseString, i)

        if not hasXMLProperty(xmlFile, key) then
            break
        end

        local node = Utils.indexToObject(self.components, getXMLString(xmlFile, key .. '#node'))

        if node ~= nil then
            local entry = {
                id = i + 1, -- Table index
                node = node,
                nodeOrgTrans = { getRotation(node) },
                nodeOrgRot = { getRotation(node) },
                jointIndex = 0,
                centerJointIndex = 0,
                hasJointIndex = false, -- We don't sync the actual JointIndex it's server sided
                hasExtenableJointIndex = false, -- We don't sync the actual JointIndex it's server sided
                componentIndex = Utils.getNoNil(getXMLFloat(xmlFile, key .. '#componentIndex'), 0) + 1,
                componentChildNode = Utils.indexToObject(self.components, getXMLString(xmlFile, key .. '#componentChildNode')),
                connectable = Utils.getNoNil(getXMLBool(xmlFile, key .. '#connectable'), false),
                state = HoseSystem.STATE_DETACHED,
                connectorRef = nil,
                connectorRefId = 0,
                connectorRefConnectable = false,
                connectorVehicle = nil,
                connectorVehicleId = 0,
                currentOwner = nil,
                isOwned = false
            }

--            table.insert(self.playerInRangeTool, {
--                node = node,
--                playerDistance = 2
--            })

            table.insert(self.grabPoints, entry)
            self.nodesToGrabPoints[entry.node] = entry
        else
            print('HoseSystem error - Invalid grabPoint node, please check your XML!')
            break
        end

        i = i + 1 -- i++
    end
end

function HoseSystem:mouseEvent(posX, posY, isDown, isUp, button)
end

function HoseSystem:keyEvent(unicode, sym, modifier, isDown)
end

function HoseSystem:update(dt)
    if self.polymorphismClasses ~= nil and #self.polymorphismClasses > 0 then
        for _, class in pairs(self.polymorphismClasses) do
            if class.update ~= nil then
                class:update(dt)
            end
        end
    end

    if self.isClient then
        if self.jointSpline.firstRunUpdates < self.jointSpline.firstNumRunUpdates then
            self.jointSpline.firstRunUpdates = self.jointSpline.firstRunUpdates + 1
            self:updateMesh(true) -- force firstNumRunUpdates frame updates to give hose time to move.
        else
            self:updateMesh(false)
        end
    end
end

function HoseSystem:draw()
end

---
-- @param force
--
function HoseSystem:updateMesh(force)
    local js = self.jointSpline

    -- controllers
    local p0 = { localToWorld(self.components[1].node, -js.curveControllerTrans[1], -js.curveControllerTrans[2], -js.curveControllerTrans[3]) } -- controller 1
    local p1 = { getWorldTranslation(self.components[1].node) } -- start
    local p2 = { getWorldTranslation(self.components[js.endComponentId].node) } -- end
    local p3 = { localToWorld(self.components[js.endComponentId].node, js.curveControllerTrans[1], js.curveControllerTrans[2], js.curveControllerTrans[3]) } -- controller 2

    local movedDistance1 = Utils.vector3Length(p1[1] - js.lastPosition[1][1], p1[2] - js.lastPosition[1][2], p1[3] - js.lastPosition[1][3])
    local movedDistance2 = Utils.vector3Length(p2[1] - js.lastPosition[2][1], p2[2] - js.lastPosition[2][2], p2[3] - js.lastPosition[2][3])

    if movedDistance1 > 0.001 or movedDistance2 > 0.001 or force then
        -- print("force " .. tostring(force) .. " distance " .. movedDistance1 .. " - " .. movedDistance2)

        js.lastPosition[1] = p1
        js.lastPosition[2] = p2

        for i = 1, js.numJoints do
            if i <= js.numJoints then
                local t = (i - 1) / (js.numJoints - 1)
                local x = HoseSystem:catmullRomSpline(t, p0[1], p1[1], p2[1], p3[1])
                local y = HoseSystem:catmullRomSpline(t, p0[2], p1[2], p2[2], p3[2])
                local z = HoseSystem:catmullRomSpline(t, p0[3], p1[3], p2[3], p3[3])
                local trans = { worldToLocal(js.hoseJoints[i].parent, x, y, z) }

                setTranslation(js.hoseJoints[i].node, unpack(trans))

                local target = i < js.numJoints and { getWorldTranslation(js.hoseJoints[i + 1].node) } or { localToWorld(self.components[js.endComponentId].node, 0, 0, 1) } -- if true -> target is 1 "trans" in Z axis infront of component.

                if target ~= nil then
                    local base = { getWorldTranslation(js.hoseJoints[i].node) }
                    local direction = { target[1] - base[1], target[2] - base[2], target[3] - base[3] }

                    if (direction[1] ~= 0 or direction[2] ~= 0 or direction[3] ~= 0) then
                        local upVector = { localDirectionToWorld(js.hoseJoints[i].parent, 0, 1, 0) }
                        Utils.setWorldDirection(js.hoseJoints[i].node, direction[1], direction[2], direction[3], upVector[1], upVector[2], upVector[3])
                    end
                end
            end
        end
    end

    if HoseSystem.debugRendering then
        -- debug curve line
        local tableNum = 150 -- more = closer between dots

        for i = 1, tableNum do
            local t = (i - 1) / tableNum
            local x = HoseSystem:catmullRomSpline(t, p0[1], p1[1], p2[1], p3[1])
            local y = HoseSystem:catmullRomSpline(t, p0[2], p1[2], p2[2], p3[2])
            local z = HoseSystem:catmullRomSpline(t, p0[3], p1[3], p2[3], p3[3])

            drawDebugPoint(x, y, z, 0, 1, 1, 1)
        end

        -- draw line to target joint, to show what angle we have.
        for i = 1, js.numJoints do
            local distance = js.length / js.numJoints
            local dot = { localToWorld(js.hoseJoints[i].node, 0, 0, distance) }
            local dot2 = { localToWorld(js.hoseJoints[i].node, 0, 0, 0) }
            drawDebugLine(dot[1], dot[2], dot[3], 1, 0, 0, dot2[1], dot2[2], dot2[3], 0, 1, 0)
            drawDebugPoint(dot[1], dot[2], dot[3], 1, 0, 0, 1)
            drawDebugPoint(dot2[1], dot2[2], dot2[3], 0, 1, 0, 1)
        end
    end
end

---
-- @param t
-- @param p0
-- @param p1
-- @param p2
-- @param p3
--
function HoseSystem:catmullRomSpline(t, p0, p1, p2, p3)
    return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t ^ 2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t ^ 3)
end

---
-- @param state
-- @return bool
--
function HoseSystem:getIsDetached(state)
    return state == HoseSystem.STATE_DETACHED
end

---
-- @param state
-- @return bool
--
function HoseSystem:getIsAttached(state)
    return state == HoseSystem.STATE_ATTACHED
end

---
-- @param state
-- @return bool
--
function HoseSystem:getIsParked(state)
    return state == HoseSystem.STATE_PARKED
end

---
-- @param state
-- @return bool
--
function HoseSystem:getIsConnected(state)
    return state == HoseSystem.STATE_CONNECTED
end

function HoseSystem:print_r(t, name, indent)
    local tableList = {}

    local table_r = function(t, name, indent, full)
        local id = not full and name or type(name) ~= "number" and tostring(name) or '[' .. name .. ']'
        local tag = indent .. id .. ' : '
        local out = {}

        if type(t) == "table" then
            if tableList[t] ~= nil then
                table.insert(out, tag .. '{} -- ' .. tableList[t] .. ' (self reference)')
            else
                tableList[t] = full and (full .. '.' .. id) or id

                if next(t) then -- If table not empty.. fill it further
                    table.insert(out, tag .. '{')

                    for key, value in pairs(t) do
                        table.insert(out, table_r(value, key, indent .. '|  ', tableList[t]))
                    end

                    table.insert(out, indent .. '}')
                else
                    table.insert(out, tag .. '{}')
                end
            end
        else
            local val = type(t) ~= "number" and type(t) ~= "boolean" and '"' .. tostring(t) .. '"' or tostring(t)
            table.insert(out, tag .. val)
        end

        return table.concat(out, '\n')
    end

    return table_r(t, name or 'Value', indent or '')
end

function HoseSystem.consoleCommandToggleHoseSystemDebugRendering(unusedSelf)
    HoseSystem.debugRendering = not HoseSystem.debugRendering
    return "HoseSystemDebugRendering = "..tostring(HoseSystem.debugRendering)
end

addConsoleCommand("gsToggleHoseSystemDebugRendering", "Toggles the debug rendering of the HoseSystem", "HoseSystem.consoleCommandToggleHoseSystemDebugRendering", nil)