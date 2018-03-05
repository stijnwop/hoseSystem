--
-- HoseSystemObjectsUtil
--
-- Authors: Wopster
-- Description: Utility for map objects
--
-- Copyright (c) Wopster, 2018

HoseSystemObjectsUtil = {}

---
-- Local validation functions
--

---
-- @param node
--
local function hasValidScale(node)
    local x, y, z = getScale(node)

    if x ~= 1 or y ~= 1 or z ~= 1 then
        return false
    end

    return true
end

---
-- @param node
--
local function hasRigidBody(node)
    local rigidType = getRigidBodyType(node):lower()

    return rigidType ~= "norigidbody"
end

---
-- @param node
--
local function isShapeObject(node)
    return getHasClassId(node, ClassIds.SHAPE)
end

---
-- @param triggerId
--
function HoseSystemObjectsUtil.getIsValidTrigger(triggerId)
    if not hasValidScale(triggerId) then
        HoseSystemUtil:log(HoseSystemUtil.ERROR, ("Invalid scale on trigger node: %s. Scale on axis xyz must be 1:1!"):format(getName(triggerId)))

        return false
    end

    return true
end

---
-- @param nodeId
--
function HoseSystemObjectsUtil.getIsNodeValid(nodeId)
    -- validate nodeId
    if not hasValidScale(nodeId) then
        HoseSystemUtil:log(HoseSystemUtil.ERROR, ("Invalid scale on node: %s. Scale on axis xyz must be 1:1!"):format(getName(nodeId)))

        return false
    end

    if not hasRigidBody(nodeId) then
        HoseSystemUtil:log(HoseSystemUtil.ERROR, ("Node %s must have a rigid body!"):format(getName(nodeId)))

        return false
    end

    if not isShapeObject(nodeId) then
        HoseSystemUtil:log(HoseSystemUtil.ERROR, ("Node %s must be a shape object and can´t be a transformgroup!"):format(getName(nodeId)))
        return false
    end

    return true
end