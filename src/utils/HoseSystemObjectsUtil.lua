--
-- HoseSystemObjectsUtil
--
-- Authors: Wopster
-- Description: Utility for map objects
--
-- Copyright (c) Wopster, 2018

HoseSystemObjectsUtil = {}

function HoseSystemObjectsUtil.getIsNodeValid(nodeId)
    -- validate nodeId
    local x, y, z = getScale(nodeId)
    if x ~= 1 or y ~= 1 or z ~= 1 then
        HoseSystemUtil:log(HoseSystemUtil.ERROR, ("Invalid scale on HoseSystemFillTrigger node x y z scale must be 1! Current scale: x = %1.3f y = %1.3f z = %1.3f"):format(x, y, z))
        return false
    end

    local rigidType = getRigidBodyType(nodeId):lower()
    if rigidType == "norigidbody" then
        HoseSystemUtil:log(HoseSystemUtil.ERROR, "HoseSystemFillTrigger must have a rigid body!")
        return false
    end

    if not getHasClassId(nodeId, ClassIds.SHAPE) then
        HoseSystemUtil:log(HoseSystemUtil.ERROR, "HoseSystemFillTrigger must be a shape object and can´t be a transformgroup!")
        return false
    end

    return true
end

