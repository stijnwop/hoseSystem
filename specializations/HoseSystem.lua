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
    self.hoseJoints = {}
    self.grabPoints = {}
    self.nodesToGrabPoints = {}

    self.hoseSystemActivatable = HoseSystemActivatable:new(self)

    self:loadHoseJoints(self.jointSpline, self.xmlFile, 'vehicle.hoseSystem.jointSpline')
    self:loadGrabPoints(self.grabPoints, self.xmlFile, 'vehicle.hoseSystem.grabPoints')
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
