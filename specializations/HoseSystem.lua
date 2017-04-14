--
-- Created by IntelliJ IDEA.
-- User: stijn
-- Date: 13-4-2017
-- Time: 18:36
-- To change this template use File | Settings | File Templates.
--

--source()

HoseSystem = {
    debug = false,
    modDir = g_currentModDirectory,
    eventsDir = g_currentModDirectory .. "specializations/events"
}

HoseSystem.STATE_ATTACHED = 0
HoseSystem.STATE_DETACHED = 1
HoseSystem.STATE_CONNECTED = 2
HoseSystem.STATE_PARKED = 3

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

    self.loadObjectChangeValuesFromXML = Utils.overwrittenFunction(self.loadObjectChangeValuesFromXML, HoseSystem.loadObjectChangeValuesFromXML)
    self.setObjectChangeValues = Utils.overwrittenFunction(self.setObjectChangeValues, HoseSystem.setObjectChangeValues)
end

---
-- @param savegame
--
function HoseSystem:load(savegame)
    self.jointSpline = {}
    self.grabPoints = {}
    self.nodesToGrabPoints = {}

    self.hoseSystemActivatable = HoseSystemActivatable:new(self)

    self:loadHoseJoints(self.jointSpline, self.xmlFile, 'vehicle.hoseSystem.jointSpline')
    self:loadGrabPoints(self.grabPoints, self.xmlFile, 'vehicle.hoseSystem.grabPoints')

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
end

function HoseSystem:loadHoseJoints(entry, xmlFile, baseString)
    local rootJointNode = Utils.indexToObject(self.components, getXMLString(xmlFile, ('%s.#rootJointNode'):format(baseString)))
    local jointCount = getXMLInt(xmlFile, ('%s.#numJoints'):format(baseString))

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

    entry.curveControllerTrans = Utils.getNoNil(Utils.getVectorNFromString(getXMLString(xmlFile, ('%s.#curveControllerTrans'):format(baseString)), 3), { 0, 0, 7.5 }) -- set curve "controller" trans relative to grabPoints
    entry.numJoints = #entry.hoseJoints
    entry.endComponentId = #self.components
    entry.lastPosition = {{ 0, 0, 0 }, { 0, 0, 0 }}
    entry.firstRunUpdates = 0
    entry.firstNumRunUpdates = Utils.getNoNil(getXMLInt(xmlFile, ('%s.#firstNumRunUpdates'):format(baseString)), 7)
    entry.length = getXMLFloat(xmlFile, 'vehicle.size#length')

    if entry.numJoints > 0 then -- we should confirm that 1 or 2 attacherJoints are in place too.
        -- store "hose" in an global table for faster distance check later on
        if g_currentMission.liquidManureHoses == nil then
            g_currentMission.liquidManureHoses = {}
        end

        table.insert(g_currentMission.liquidManureHoses, self)
    end
end

function HoseSystem:loadGrabPoints(grabPoints, xmlFile, baseString)
    local i = 0

    while true do
        local key = ('%s.grabPoint(%d'):format(baseString, i)

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
                attachState = HoseSystem.STATE_DETACHED,
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

            table.insert(grabPoints, entry)
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
end

function HoseSystem:grab(index, player, noEventSend)
    if self.grabPoints ~= nil then
        HoseSystemGrabEvent.sendEvent(self, index, player, noEventSend)

        local grabPoint = self.grabPoints[index]

        if grabPoint == nil then
            return
        end

        if player ~= nil then
            grabPoint.state = HoseSystem.STATE_ATTACHED

            -- Todo: we call the function set owner
            -- But do not event it again since we already getting reloaded by the grab event
            -- self:setGrabPointOwner()

            -- Todo: update visuals like gloves etc..
            -- But do not event it again since we already getting reloaded by the grab event

            self.walkingSpeed = player.walkingSpeed
            self.runningFactor = player.runningFactor

            if self.isServer then
                -- Todo: calculate mass of hose components.. save it in self on game load.
                -- For now just set 4kg for every meter.
                player.hoseSystem = {
                    mass = (0.004 * self.hose.length) * 100,
                }

                -- Todo: check if we still have to set the joint orientation?
                HoseSystem:constructPlayerJoint({
                    actor1 = player.pickUpKinematicHelper.node,
                    actor2 = self.components[grabPoint.componentIndex].node,
                    anchor1 = player.pickUpKinematicHelper.node,
                    anchor2 = grabPoint.node
                }, player.hoseSystem)

                -- Set collision mask on hose components to disable collision with CCT
                if grabPoint.componentIndex ~= nil then
                    setCollisionMask(self.components[grabPoint.componentIndex].node, 32) -- 00000000000000000000000000110010
                end

--                for i, component in pairs(self.components) do
--                    if i ~= grabPoint.componentIndex then
--                        setPairCollision(player.pickUpKinematicHelper.node, component.node, false)
--                    end
--                end

            end
        end
    end
end

---
-- @param jointDesc
-- @param playerHoseDesc
--
function HoseSystem:constructPlayerJoint(jointDesc, playerHoseDesc)
    local constructor = JointConstructor:new()

    constructor:setActors(jointDesc.actor1, jointDesc.actor2)
    constructor:setJointTransforms(jointDesc.anchor1, jointDesc.anchor2)

    -- Todo: cleaup below
    local position = getWorldTranslation(jointDesc.actor2)
    constr:setJointWorldPositions(position[1], position[2], position[3], position[1], position[2], position[3])

    local nx,ny,nz = localDirectionToWorld(jointDesc.actor2, 1,0,0)
    constr:setJointWorldAxes(nx, ny, nz, nx, ny, nz)

    local yx,yy,yz = localDirectionToWorld(jointDesc.actor2, 0,1,0)
    constr:setJointWorldNormals(yx, yy, yz, yx, yy, yz)

    constructor:setEnableCollision(false)

    local rotLimitSpring = {}
    local rotLimitDamping = {}
    local transLimitSpring = {}
    local translimitDamping = {}
    local springMass = playerHoseDesc.mass * 60

    for i = 1, 3 do
        rotLimitSpring[i] = springMass
        rotLimitDamping[i] = math.sqrt(playerHoseDesc.mass * rotLimitSpring[i]) * 2
        transLimitSpring[i] = springMass
        translimitDamping[i] = math.sqrt(playerHoseDesc.mass * transLimitSpring[i]) * 2
    end

    constructor:setRotationLimitSpring(rotLimitSpring[1], rotLimitDamping[1], rotLimitSpring[2], rotLimitDamping[2], rotLimitSpring[3], rotLimitDamping[3])
    constructor:setTranslationLimitSpring(transLimitSpring[1], translimitDamping[1], transLimitSpring[2], translimitDamping[1], transLimitSpring[3], translimitDamping[3])

    for i = 0, 2 do
        constructor:setRotationLimit(i, 0, 0)
        constructor:setTranslationLimit(i, true, 0, 0)
    end

    local forceLimit = playerHoseDesc.mass * 25 -- only when stucked behind object
    constructor:setBreakable(forceLimit, forceLimit)

    playerHoseDesc.jointIndex = constructor:finalize()

    addJointBreakReport(playerHoseDesc.jointIndex, 'onGrabJointBreak', self)
end

---
-- @param jointIndex
-- @param breakingImpulse
--
function HoseSystem:onGrabJointBreak(jointIndex, breakingImpulse)
    --if self.isServer then
    if jointIndex == g_currentMission.player.hose.jointIndex then
        g_currentMission.player.activeTool:drop(g_currentMission.player.activeToolLocationId, g_currentMission.player)
    end
    --end

    return false
end