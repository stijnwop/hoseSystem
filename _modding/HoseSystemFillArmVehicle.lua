--
-- HoseSystemFillArmVehicle
--
-- Authors: Wopster
-- Description: Enables you to let fillArm vehicles pump from your vehicle based on fillvolume
--
-- Copyright (c) Wopster, 2018

HoseSystemFillArmVehicle = {}

---
-- @param specializations
--
function HoseSystemFillArmVehicle.prerequisitesPresent(specializations)
    if not SpecializationUtil.hasSpecialization(Fillable, specializations) or not SpecializationUtil.hasSpecialization(FillVolume, specializations) then
        print("Warning - Specialization HoseSystemFillArmVehicle needs the specializations Fillable and FillVolume.")
        return false
    end

    return true
end

function HoseSystemFillArmVehicle:preLoad(savegame)
    self.checkPlaneY = HoseSystemFillArmVehicle.checkPlaneY
end

function HoseSystemFillArmVehicle:load(savegame)
    local index = Utils.getNoNil(getXMLInt(self.xmlFile, "vehicle.hoseSystemFillArmVehicle#fillVolumeIndex"), 1)
    assert(self.fillVolumes[index] ~= nil, "Error - HoseSystemFillArmVehicle has invalid fillVolume index")

    self.fillArmOffset = Utils.getNoNil(getXMLFloat(self.xmlFile, "vehicle.hoseSystemFillArmVehicle#fillArmOffset"), 0)
    self.fillArmFillVolumeIndex = index
    self.supportsHoseSystem = self.fillArmFillVolumeIndex ~= nil
end

function HoseSystemFillArmVehicle:delete()
end

function HoseSystemFillArmVehicle:mouseEvent(...)
end

function HoseSystemFillArmVehicle:keyEvent(...)
end

function HoseSystemFillArmVehicle:update(dt)
end

function HoseSystemFillArmVehicle:draw()
end

function HoseSystemFillArmVehicle:checkPlaneY(y, trans)
    local index = self.fillArmFillVolumeIndex

    if self.fillVolumes[index].volume ~= nil then
        local volume = self.fillVolumes[index].volume

        local x,_,z  = worldToLocal(volume, trans[1], y, trans[3])
        local height = getFillPlaneHeightAtLocalPos(volume, x, z)
        local _, volumeWorldY, _ = localToWorld(volume, x, height, z)

        volumeWorldY = volumeWorldY + self.fillArmOffset

        return volumeWorldY >= y, volumeWorldY
    end

    return false, 0
end