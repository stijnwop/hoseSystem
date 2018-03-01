HoseSystemObjectsUtil = {}

function HoseSystemObjectsUtil.getIsNodeValid(nodeId)
    -- validate nodeId
    local x, y, z = getScale(nodeId)
    if x ~= 1 or y ~= 1 or z ~= 1 then
        HoseSystemUtil:log(HoseSystemUtil.ERROR, ("Invalid scale on HoseSystemFillTrigger node x y z scale must be 1! Current scale: x = %1.3f y = %1.3f z = %1.3f"):format(x, y, z))
        return false
    end

    local rigidType = getRigidBodyType(getParent(nodeId)):lower()
    if rigidType == "norigidbody" then
        HoseSystemUtil:log(HoseSystemUtil.ERROR, "HoseSystemFillTrigger must have a rigid body!")
        return false
    end

    return true
end

