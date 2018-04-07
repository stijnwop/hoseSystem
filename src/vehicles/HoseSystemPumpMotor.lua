--
-- HoseSystemPumpMotor
--
-- Authors:    	Wopster and Xentro (Marcus@Xentro.se)
-- Description: Pumpmotor to pump fillTypes
--
-- Copyright (c) Wopster and Xentro, 2017

HoseSystemPumpMotor = {
    sendNumBits = 3, -- max 8 fill modes.. 2^8
}

HoseSystemPumpMotor.IN = 0
HoseSystemPumpMotor.IN_STRING = 'in'
HoseSystemPumpMotor.OUT = 1
HoseSystemPumpMotor.OUT_STRING = 'out'

HoseSystemPumpMotor.NONE = 0
HoseSystemPumpMotor.TURN_OFF = 1
HoseSystemPumpMotor.UNIT_EMPTY = 2
HoseSystemPumpMotor.OBJECT_EMPTY = 3
HoseSystemPumpMotor.INVALID_FILLTYPE = 4
HoseSystemPumpMotor.OBJECT_FULL = 5

HoseSystemPumpMotor.DEFAULT_LITERS_PER_SECOND = 100

HoseSystemPumpMotor.AUTO_STOP_MULTIPLIER_IN = 0.99
HoseSystemPumpMotor.AUTO_STOP_MULTIPLIER_OUT = 0.98

HoseSystemPumpMotor.WARNING_TIME = 1500
HoseSystemPumpMotor.STARTUP_TIME = 1500
HoseSystemPumpMotor.MAX_EFFICIENCY_TIME = 1500
HoseSystemPumpMotor.RPM_INCREASE = 5

---
-- @param specializations
--
function HoseSystemPumpMotor.prerequisitesPresent(specializations)
    if not SpecializationUtil.hasSpecialization(PowerConsumer, specializations) then
        HoseSystemUtil:log(HoseSystemUtil.ERROR, "Specialization HoseSystemPumpMotor needs the specialization PowerConsumer")
        return false
    end

    return true
end

---
-- @param savegame
--
function HoseSystemPumpMotor:preLoad(savegame)
    self.getFillMode = HoseSystemPumpMotor.getFillMode
    self.setFillMode = HoseSystemPumpMotor.setFillMode
    self.getFillDirection = HoseSystemPumpMotor.getFillDirection
    self.setFillDirection = HoseSystemPumpMotor.setFillDirection
    self.allowPumpStarted = HoseSystemPumpMotor.allowPumpStarted
    self.setPumpStarted = HoseSystemPumpMotor.setPumpStarted
    self.handlePump = HoseSystemPumpMotor.handlePump
    self.pumpIn = HoseSystemPumpMotor.pumpIn
    self.pumpOut = HoseSystemPumpMotor.pumpOut
    self.doPump = HoseSystemPumpMotor.doPump
    self.doFakePump = HoseSystemPumpMotor.doFakePump
    self.getIsTurnedOn = Utils.overwrittenFunction(self.getIsTurnedOn, HoseSystemPumpMotor.getIsTurnedOn)
    self.getIsTurnedOnAllowed = Utils.overwrittenFunction(self.getIsTurnedOnAllowed, HoseSystemPumpMotor.getIsTurnedOnAllowed)
    self.getConsumedPtoTorque = Utils.overwrittenFunction(self.getConsumedPtoTorque, HoseSystemPumpMotor.getConsumedPtoTorque)
    -- self.setIsTurnedOn = Utils.overwrittenFunction(self.setIsTurnedOn, HoseSystemPumpMotor.setIsTurnedOn)
    self.setWarningMessage = HoseSystemPumpMotor.setWarningMessage
    self.getAllowedFillUnitIndex = HoseSystemPumpMotor.getAllowedFillUnitIndex
    self.addFillObject = HoseSystemPumpMotor.addFillObject
    self.removeFillObject = HoseSystemPumpMotor.removeFillObject
    self.updateFillObject = HoseSystemPumpMotor.updateFillObject
end

---
-- @param savegame
--
function HoseSystemPumpMotor:load(savegame)
    self.attacherMotor = {
        check = false,
        isStarted = false
    }

    self.pumpIsStarted = false
    self.fillMode = 0 -- 0 is nothing
    self.fillDirection = HoseSystemPumpMotor.IN

    local limit = getXMLString(self.xmlFile, "vehicle.pumpMotor#limitedFillDirection")
    self.limitedFillDirection = nil

    if limit ~= nil then
        self.limitedFillDirection = limit:lower() == HoseSystemPumpMotor.IN_STRING and HoseSystemPumpMotor.IN or HoseSystemPumpMotor.OUT
    end

    self.limitFillDirection = self.limitedFillDirection ~= nil

    self.pumpEfficiency = {
        currentScale = 0,
        scaleLimit = 0.1, -- when we can change fill direction
        currentStartUpTime = 0,
        startUpTime = Utils.getNoNil(getXMLFloat(self.xmlFile, "vehicle.pumpMotor#startUpTime"), HoseSystemPumpMotor.STARTUP_TIME)
    }

    local maxTime = Utils.getNoNil(getXMLFloat(self.xmlFile, "vehicle.pumpMotor#toReachMaxEfficiencyTime"), HoseSystemPumpMotor.MAX_EFFICIENCY_TIME)
    self.pumpFillEfficiency = {
        currentScale = 0,
        currentTime = 0,
        maxTimeStatic = maxTime,
        maxTime = maxTime,
        litersPerSecond = Utils.getNoNil(getXMLFloat(self.xmlFile, "vehicle.pumpMotor#litersPerSecond"), HoseSystemPumpMotor.DEFAULT_LITERS_PER_SECOND)
    }

    self.autoStopPercentage = {
        inDirection = Utils.getNoNil(getXMLFloat(self.xmlFile, "vehicle.pumpMotor#autoStopPercentageIn"), HoseSystemPumpMotor.AUTO_STOP_MULTIPLIER_IN),
        outDirection = Utils.getNoNil(getXMLFloat(self.xmlFile, "vehicle.pumpMotor#autoStopPercentageOut"), HoseSystemPumpMotor.AUTO_STOP_MULTIPLIER_OUT)
    }

    if self.isClient then
        local linkNode = Utils.indexToObject(self.components, Utils.getNoNil(getXMLString(self.xmlFile, "vehicle.pumpMotor#linkNode"), "0>"))
        self.samplePump = SoundUtil.loadSample(self.xmlFile, {}, "vehicle.pumpSound", nil, self.baseDirectory, linkNode)
    end

    self.warningMessage = {
        currentId = HoseSystemPumpMotor.NONE,
        currentTime = 0,
        howLongToShow = Utils.getNoNil(getXMLFloat(self.xmlFile, "vehicle.pumpMotor#warningTime"), HoseSystemPumpMotor.WARNING_TIME),
        messages = {}
    }

    self.warningMessage.messages[HoseSystemPumpMotor.TURN_OFF] = g_i18n:getText('pumpMotor_warningTurnOffFirst')
    self.warningMessage.messages[HoseSystemPumpMotor.UNIT_EMPTY] = g_i18n:getText('pumpMotor_warningUnitEmpty')
    self.warningMessage.messages[HoseSystemPumpMotor.OBJECT_EMPTY] = g_i18n:getText('pumpMotor_warningObjectEmpty')
    self.warningMessage.messages[HoseSystemPumpMotor.OBJECT_FULL] = g_i18n:getText('pumpMotor_warningObjectFull')
    self.warningMessage.messages[HoseSystemPumpMotor.INVALID_FILLTYPE] = g_i18n:getText('pumpMotor_warningInvalidFilltype')

    local isStandalone = Utils.getNoNil(getXMLBool(self.xmlFile, "vehicle.pumpMotor#isStandalone"), false)

    self.pumpMotor = {
        isStandalone = isStandalone,
        unloadInfoIndex = Utils.getNoNil(getXMLInt(self.xmlFile, "vehicle.pumpMotor#unloadInfoIndex"), 1),
        dischargeInfoIndex = Utils.getNoNil(getXMLInt(self.xmlFile, "vehicle.pumpMotor#dischargeInfoIndex"), 1)
    }

    self.pumpStrategies = {}

    if isStandalone then
        local strategy = HoseSystemPumpMotorFactory.getPumpStrategy(HoseSystemPumpMotorFactory.TYPE_STANDALONE, self)

        if strategy:prerequisitesPresent(self) then
            self.pumpStrategies = HoseSystemUtil.insertStrategy(HoseSystemPumpMotorFactory.getPumpStrategy(HoseSystemPumpMotorFactory.TYPE_STANDALONE, self), self.pumpStrategies)
        end
    end

    HoseSystemUtil.callStrategyFunction(self.pumpStrategies, 'load', { self.xmlFile, "vehicle.pumpMotor" })

    self.sourceObject = nil
    self.fillObject = nil
    self.fillObjectFound = false
    self.fillObjectHasPlane = false
    self.fillFromFillVolume = false
    self.fillUnitIndex = 0
    self.isSucking = false

    if self.isServer then
        self.lastFillObjectFound = false
        self.lastFillObjectHasPlane = false
        self.lastFillFromFillVolume = false
        self.lastFillUnitIndex = 0 -- stream?
        self.lastSourceObject = nil
    end

    self.pumpEfficiencyDirtyFlag = self:getNextDirtyFlag()
    self.updateNetworkSourceObject = false
end

---
--
function HoseSystemPumpMotor:delete()
    if self.isClient then
        SoundUtil.deleteSample(self.samplePump)
    end

    self:removeFillObject(nil, self:getFillMode())
end

---
-- @param streamId
-- @param connection
--
function HoseSystemPumpMotor:readStream(streamId, connection)
    if connection:getIsServer() then
        self:setPumpStarted(streamReadBool(streamId), nil, true)
        self:setFillDirection(streamReadUIntN(streamId, HoseSystemPumpMotor.sendNumBits), true)
        self:setFillMode(streamReadUIntN(streamId, HoseSystemPumpMotor.sendNumBits), true)

        self.fillObjectFound = streamReadBool(streamId)
        self.fillFromFillVolume = streamReadBool(streamId)
        self.fillUnitIndex = streamReadInt32(streamId)
        self.fillObjectHasPlane = streamReadBool(streamId)

        if streamReadBool(streamId) then
            self.sourceObjectNetworkId = readNetworkNodeObjectId(streamId)
        end

        self.updateNetworkSourceObject = true
    end
end

---
-- @param streamId
-- @param connection
--
function HoseSystemPumpMotor:writeStream(streamId, connection)
    if not connection:getIsServer() then
        streamWriteBool(streamId, self.pumpIsStarted)
        streamWriteUIntN(streamId, self.fillDirection, HoseSystemPumpMotor.sendNumBits)
        streamWriteUIntN(streamId, self.fillMode, HoseSystemPumpMotor.sendNumBits)

        streamWriteBool(streamId, self.fillObjectFound)
        streamWriteBool(streamId, self.fillFromFillVolume)
        streamWriteInt32(streamId, self.fillUnitIndex)
        streamWriteBool(streamId, self.fillObjectHasPlane)

        local writeNetworkSourceObject = self.sourceObject ~= nil and self.sourceObject ~= self
        streamWriteBool(streamId, writeNetworkSourceObject)

        -- Only write source object when we have a different source than ourselves
        if writeNetworkSourceObject then
            writeNetworkNodeObjectId(streamId, networkGetObjectId(self.sourceObject))
        end
    end
end

---
-- @param streamId
-- @param timestamp
-- @param connection
--
function HoseSystemPumpMotor:readUpdateStream(streamId, timestamp, connection)
    if connection:getIsServer() then
        local isDirty = streamReadBool(streamId)

        if isDirty then
            self.pumpEfficiency.currentScale = streamReadFloat32(streamId)
            self.pumpFillEfficiency.currentScale = streamReadFloat32(streamId)
        end
    end
end

---
-- @param streamId
-- @param connection
-- @param dirtyMask
--
function HoseSystemPumpMotor:writeUpdateStream(streamId, connection, dirtyMask)
    if not connection:getIsServer() then
        if streamWriteBool(streamId, bitAND(dirtyMask, self.pumpEfficiencyDirtyFlag) ~= 0) then
            streamWriteFloat32(streamId, self.pumpEfficiency.currentScale)
            streamWriteFloat32(streamId, self.pumpFillEfficiency.currentScale)
        end
    end
end

function HoseSystemPumpMotor:mouseEvent(...)
end

function HoseSystemPumpMotor:keyEvent(...)
end

---
-- @param dt
--
function HoseSystemPumpMotor:update(dt)
    if self.updateNetworkSourceObject and self.fillObjectFound then
        if self.sourceObjectNetworkId ~= nil then
            local networkSourceObject = networkGetObject(self.sourceObjectNetworkId)

            if networkSourceObject ~= nil then
                self.sourceObject = networkSourceObject
                self.sourceObjectNetworkId = nil
            end
        else
            -- we are the source
            self.sourceObject = self
        end

        self.updateNetworkSourceObject = false
    end

    HoseSystemUtil.callStrategyFunction(self.pumpStrategies, 'update', { dt })

    if self:getIsActive() then
        if self:getIsActiveForInput() and not self:hasInputConflictWithSelection() then
            if InputBinding.hasEvent(InputBinding.ACTIVATE_OBJECT) then
                if self.attacherMotor.isStarted then
                    if self:allowPumpStarted() then
                        self:setPumpStarted(not self.pumpIsStarted)
                    end
                end
            end

            if InputBinding.hasEvent(InputBinding.IMPLEMENT_EXTRA4) then
                if self.attacherMotor.isStarted then
                    if not self.pumpIsStarted then
                        if self.pumpEfficiency.currentScale < self.pumpEfficiency.scaleLimit then
                            self:setFillDirection(self:getFillDirection() + 1)
                        end
                    else
                        self:setWarningMessage(HoseSystemPumpMotor.TURN_OFF)
                    end
                end
            end
        end
    end
end

---
-- @param dt
--
function HoseSystemPumpMotor:updateTick(dt)
    HoseSystemUtil.callStrategyFunction(self.pumpStrategies, 'updateTick', { dt })

    if self.isClient then
        if self.pumpIsStarted then
            if self.pumpEfficiency.currentScale ~= 0 then
                SoundUtil.setSamplePitch(self.samplePump, math.max(self.pumpFillEfficiency.currentScale, 0.25))
                SoundUtil.setSampleVolume(self.samplePump, math.max(self.pumpEfficiency.currentScale, 0.08))

                if self:getIsActiveForSound() then
                    SoundUtil.playSample(self.samplePump, 0, 0, nil)
                    SoundUtil.stop3DSample(self.samplePump)
                else
                    SoundUtil.stopSample(self.samplePump)
                    SoundUtil.play3DSample(self.samplePump)
                end
            else
                SoundUtil.stopSample(self.samplePump)
                SoundUtil.stop3DSample(self.samplePump)
            end
        else
            SoundUtil.stopSample(self.samplePump)
            SoundUtil.stop3DSample(self.samplePump)
        end
    end

    if self.attacherMotor.check or self.getIsMotorStarted ~= nil then
        local vehicle = self:getRootAttacherVehicle()
        self.attacherMotor.isStarted = vehicle.getIsMotorStarted ~= nil and vehicle:getIsMotorStarted()
    end

    if self.attacherMotor.isStarted then
        if self:getIsActive() then
            if self.warningMessage.currentId ~= HoseSystemPumpMotor.NONE then
                if self.warningMessage.currentTime < self.warningMessage.howLongToShow then
                    self.warningMessage.currentTime = self.warningMessage.currentTime + dt
                else
                    self.warningMessage.currentId = HoseSystemPumpMotor.NONE
                end
            end
        end

        if self.isServer then
            if self.pumpIsStarted then
                if not self.fillObjectFound then -- if we lost the object stop pump
                    self:setPumpStarted(false)
                end

                if self.pumpEfficiency.currentStartUpTime < self.pumpEfficiency.startUpTime then
                    self.pumpEfficiency.currentStartUpTime = math.min(self.pumpEfficiency.currentStartUpTime + dt, self.pumpEfficiency.startUpTime)
                end

                local updateFillScale = false

                if self.fillUnitIndex ~= 0 then
                    local fillType = self.sourceObject.fillUnits[self.fillUnitIndex].currentFilltype

                    if self:getFillDirection() == HoseSystemPumpMotor.IN then
                        if self.sourceObject:getFillLevel(fillType) / self.sourceObject:getCapacity(fillType) >= self.autoStopPercentage.inDirection then
                            self:setPumpStarted(false)
                        end

                        if self.isSucking then
                            updateFillScale = true
                        end
                    else
                        if self.sourceObject:getFillLevel(fillType) <= 0 or not self.fillObjectFound and not self.fillFromFillVolume then
                            self:setPumpStarted(false)
                        end

                        updateFillScale = true
                    end
                end

                if updateFillScale then
                    if self.pumpFillEfficiency.currentTime < self.pumpFillEfficiency.maxTime then
                        self.pumpFillEfficiency.currentTime = math.min(self.pumpFillEfficiency.currentTime + dt, self.pumpFillEfficiency.maxTime)
                    end
                else
                    if self.pumpFillEfficiency.currentTime > 0 then
                        self.pumpFillEfficiency.currentTime = math.max(self.pumpFillEfficiency.currentTime - dt, 0)
                    end
                end
            else
                if self.pumpEfficiency.currentStartUpTime > 0 then
                    self.pumpEfficiency.currentStartUpTime = math.max(self.pumpEfficiency.currentStartUpTime - dt, 0)
                end

                if self.pumpFillEfficiency.currentTime > 0 then
                    self.pumpFillEfficiency.currentTime = math.max(self.pumpFillEfficiency.currentTime - dt, 0)
                end
            end
        end
    else
        if self.isServer then
            self:setPumpStarted(false)
            self.pumpEfficiency.currentStartUpTime = 0
            self.pumpFillEfficiency.currentTime = 0
        end
    end

    if self.isServer then
        self.pumpEfficiency.currentScale = Utils.clamp(self.pumpEfficiency.currentStartUpTime / self.pumpEfficiency.startUpTime, 0, 1)
        self.pumpFillEfficiency.currentScale = Utils.clamp(self.pumpFillEfficiency.currentTime / self.pumpFillEfficiency.maxTime, 0, 1)

        if self.pumpEfficiency.currentScale ~= self.pumpEfficiency.currentScaleSend or self.pumpFillEfficiency.currentScale ~= self.pumpFillEfficiency.currentScaleSend then
            self:raiseDirtyFlags(self.pumpEfficiencyDirtyFlag)
            self.pumpEfficiency.currentScaleSend = self.pumpEfficiency.currentScale
            self.pumpFillEfficiency.currentScaleSend = self.pumpFillEfficiency.currentScale
        end
    end
end

---
--
function HoseSystemPumpMotor:draw()
    if self.attacherMotor.isStarted then
        if self.warningMessage.currentId ~= HoseSystemPumpMotor.NONE then
            g_currentMission:showBlinkingWarning(self.warningMessage.messages[self.warningMessage.currentId])
        end

        if self:getFillDirection() == HoseSystemPumpMotor.IN then
            if self.fillObjectFound or self.fillFromFillVolume then
                if not self.pumpIsStarted then -- get fillLevel of object, we got no value to access it for clients
                    g_currentMission:addHelpButtonText(g_i18n:getText('pumpMotor_activatePump'), InputBinding.ACTIVATE_OBJECT)
                else
                    g_currentMission:addHelpButtonText(g_i18n:getText('pumpMotor_deactivatePump'), InputBinding.ACTIVATE_OBJECT)
                end
            elseif self.pumpIsStarted then
                g_currentMission:addHelpButtonText(g_i18n:getText('pumpMotor_deactivatePump'), InputBinding.ACTIVATE_OBJECT)
            end
        else
            if self.fillObjectFound or self.fillFromFillVolume then
                if not self.pumpIsStarted then
                    if self.fillUnitIndex ~= 0 and self.sourceObject ~= nil then
                        local fillType = self.sourceObject.fillUnits[self.fillUnitIndex].currentFilltype

                        if self.sourceObject:getFillLevel(fillType) > 0 then
                            g_currentMission:addHelpButtonText(g_i18n:getText('pumpMotor_activatePump'), InputBinding.ACTIVATE_OBJECT)
                        end
                    end
                else
                    g_currentMission:addHelpButtonText(g_i18n:getText('pumpMotor_deactivatePump'), InputBinding.ACTIVATE_OBJECT)
                end
            elseif self.pumpIsStarted then
                g_currentMission:addHelpButtonText(g_i18n:getText('pumpMotor_deactivatePump'), InputBinding.ACTIVATE_OBJECT)
            end
        end

        if not self.pumpIsStarted then
            if self.pumpEfficiency.currentScale < self.pumpEfficiency.scaleLimit then
                g_currentMission:addHelpButtonText(g_i18n:getText('pumpMotor_changeDirection'):format(self:getFillDirection() == HoseSystemPumpMotor.IN and g_i18n:getText('pumpMotor_directionOut') or g_i18n:getText('pumpMotor_directionIn')), InputBinding.IMPLEMENT_EXTRA4)
            end
        end
    end
end

---
-- @param attacherVehicle
-- @param jointDescIndex
--
function HoseSystemPumpMotor:onAttach(attacherVehicle, jointDescIndex)
    self.attacherMotor.check = true
end

---
-- @param attacherVehicle
-- @param jointDescIndex
--
function HoseSystemPumpMotor:onDetach(attacherVehicle, jointDescIndex)
    self.warningMessage.currentId = HoseSystemPumpMotor.NONE
    self.attacherMotor.check = false
    self.attacherMotor.isStarted = false

    if self.isClient then
        SoundUtil.stop3DSample(self.samplePump)
    end
end

---
--
function HoseSystemPumpMotor:onDeactivate()
    self:setPumpStarted(false, nil, true)
end

---
--
function HoseSystemPumpMotor:getFillMode()
    return self.fillMode
end

---
-- @param int
-- @param noEventSend
--
function HoseSystemPumpMotor:setFillMode(int, noEventSend)
    self.fillMode = int

    SetFillModeEvent.sendEvent(self, int, noEventSend)
end

---
--
function HoseSystemPumpMotor:getFillDirection()
    return self.fillDirection
end

---
-- @param int
-- @param noEventSend
--
function HoseSystemPumpMotor:setFillDirection(int, noEventSend)
    self.fillDirection = int > HoseSystemPumpMotor.OUT and HoseSystemPumpMotor.IN or int

    SetFillDirectionEvent.sendEvent(self, int, noEventSend)
end

---
-- @param isStarted
-- @param warningId
-- @param noEventSend
--
function HoseSystemPumpMotor:setPumpStarted(isStarted, warningId, noEventSend)
    if self.pumpIsStarted ~= isStarted then
        self.pumpIsStarted = isStarted
        self.allowsSpraying = not isStarted -- disable manure tankers to start emptying while pumping

        if self.setIsTurnedOn ~= nil then
            self:setIsTurnedOn(isStarted)
        end

        if not isStarted and warningId ~= nil and self.isClient then
            self:setWarningMessage(warningId)
        end

        SetPumpStartedEvent.sendEvent(self, isStarted, warningId, noEventSend)
    end
end

---
--
function HoseSystemPumpMotor:allowPumpStarted()
    local fillMode = self:getFillMode()

    if not HoseSystemPumpMotorFactory.allowFillMode(fillMode) and not fillMode == 0 then
        return false
    end

    if self.fillUnitIndex == 0 then
        return false
    end

    if self:getFillDirection() == HoseSystemPumpMotor.IN then
        if not self.fillObjectFound and not self.fillFromFillVolume then
            return false
        end
    else
        local fillType = self.sourceObject.fillUnits[self.fillUnitIndex].currentFilltype

        if (self.sourceObject:getFillLevel(fillType) <= 0 or not self.fillObjectFound and not self.fillFromFillVolume) then
            return false
        end
    end

    return true
end

---
-- @param fillMode
-- @param dt
-- @param isAbleToPump
--
function HoseSystemPumpMotor:handlePump(fillMode, dt, isAbleToPump)
    if not self.isServer then
        return
    end

    if self:getFillMode() == fillMode then
        local isSucking = self.fillObjectFound

        if isAbleToPump ~= nil and not isAbleToPump then
            isSucking = false
        end

        if self.pumpIsStarted and self.fillObject ~= nil then
            local fillDirection = self:getFillDirection()

            if fillDirection == HoseSystemPumpMotor.IN then
                local objectFillTypes = self.fillObject:getCurrentFillTypes()

                if self.fillObject:getFreeCapacity() ~= self.fillObject:getCapacity() then
                    for _, objectFillType in pairs(objectFillTypes) do
                        if self.sourceObject:allowUnitFillType(self.fillUnitIndex, objectFillType, false) then
                            local objectFillLevel = self.fillObject:getFillLevel(objectFillType)
                            local fillLevel = self.sourceObject:getUnitFillLevel(self.fillUnitIndex)

                            if objectFillLevel > 0 and fillLevel < self.sourceObject:getUnitCapacity(self.fillUnitIndex) then
                                self:pumpIn(self.sourceObject, dt, objectFillLevel, objectFillType)
                            else
                                self:setPumpStarted(false, HoseSystemPumpMotor.UNIT_EMPTY)
                            end
                        else
                            self:setPumpStarted(false, HoseSystemPumpMotor.INVALID_FILLTYPE)
                        end
                    end
                else
                    self:setPumpStarted(false, HoseSystemPumpMotor.OBJECT_EMPTY)
                end
            else
                self:pumpOut(self.sourceObject, dt)
            end
        end

        if self.isSucking ~= isSucking then
            self.isSucking = isSucking
            g_server:broadcastEvent(IsSuckingEvent:new(self, self.isSucking))
        end
    end
end

---
-- @param sourceObject
-- @param dt
-- @param targetFillLevel
-- @param targetFillType
-- @param scale
--
function HoseSystemPumpMotor:pumpIn(sourceObject, dt, targetFillLevel, targetFillType, scale)
    if not self.isServer or self:getFillDirection() ~= HoseSystemPumpMotor.IN then
        return
    end

    if self.pumpFillEfficiency.currentScale > 0 then
        local deltaFillLevel = math.min((self.pumpFillEfficiency.litersPerSecond * self.pumpFillEfficiency.currentScale) * 0.001 * dt, targetFillLevel)

        self:doPump(sourceObject, self.fillObject, targetFillType, deltaFillLevel, sourceObject.fillVolumeDischargeInfos[self.pumpMotor.dischargeInfoIndex], self.fillObjectIsObject)
    end
end

---
-- @param sourceObject
-- @param dt
-- @param scale
--
function HoseSystemPumpMotor:pumpOut(sourceObject, dt, scale)
    if not self.isServer or self:getFillDirection() ~= HoseSystemPumpMotor.OUT then
        return
    end

    local fillType = sourceObject:getUnitLastValidFillType(self.fillUnitIndex)
    local fillLevel = sourceObject:getFillLevel(fillType)

    -- we checked that the fillObject accepts the fillType already
    if fillLevel > 0 then
        local deltaFillLevel = math.min((self.pumpFillEfficiency.litersPerSecond * self.pumpFillEfficiency.currentScale) * 0.001 * dt, fillLevel)

        self:doPump(sourceObject, self.fillObject, fillType, deltaFillLevel, sourceObject.fillVolumeUnloadInfos[self.pumpMotor.unloadInfoIndex], self.fillObjectIsObject)
    else
        self:setPumpStarted(false)
    end
end

---
-- @param sourceObject
-- @param targetObject
-- @param fillType
-- @param deltaFill
-- @param fillInfo
-- @param isTrigger
--
function HoseSystemPumpMotor:doPump(sourceObject, targetObject, fillType, deltaFill, fillInfo, isTrigger)
    local fillDirection = self:getFillDirection()
    local fillLevel = sourceObject:getUnitFillLevel(self.fillUnitIndex)
    local targetObjectFillLevel = targetObject:getFillLevel(fillType)

    sourceObject:setFillLevel(fillDirection == HoseSystemPumpMotor.IN and fillLevel + deltaFill or fillLevel - deltaFill, fillType, false, fillInfo)

    if fillDirection == HoseSystemPumpMotor.OUT then
        targetObject:resetFillLevelIfNeeded(fillType)
    end

    if self.fillFromFillVolume then -- Todo: Lookup new fill volume changes
        local fillVolumeInfo = fillDirection == HoseSystemPumpMotor.IN and self.fillVolumeLoadInfo or self.fillVolumeDischargeInfo
        local x, y, z = getWorldTranslation(fillVolumeInfo.node)
        local d1x, d1y, d1z = localDirectionToWorld(fillVolumeInfo.node, fillVolumeInfo.width, 0, 0)
        local d2x, d2y, d2z = localDirectionToWorld(fillVolumeInfo.node, 0, 0, fillVolumeInfo.length)
        local fillSourceStruct = { x = x, y = y, z = z, d1x = d1x, d1y = d1y, d1z = d1z, d2x = d2x, d2y = d2y, d2z = d2z }

        targetObject:setFillLevel(fillDirection == HoseSystemPumpMotor.IN and targetObjectFillLevel - deltaFill or targetObjectFillLevel + deltaFill, fillType, false, fillSourceStruct)
    else
        if isTrigger then
            targetObject:setFillLevel(fillDirection == HoseSystemPumpMotor.IN and targetObjectFillLevel - deltaFill or targetObjectFillLevel + deltaFill)
        else
            targetObject:setFillLevel(fillDirection == HoseSystemPumpMotor.IN and targetObjectFillLevel - deltaFill or targetObjectFillLevel + deltaFill, fillType)
        end
    end

    if fillDirection == HoseSystemPumpMotor.OUT then
        if targetObjectFillLevel >= (targetObject:getCapacity(fillType) * self.autoStopPercentage.outDirection) then
            self:setPumpStarted(false, HoseSystemPumpMotor.OBJECT_FULL)
        end
    end
end

---
-- @param fillType
-- @param deltaFill
-- @param fillInfo
--
function HoseSystemPumpMotor:doFakePump(fillType, deltaFill, fillInfo)
    self:setFillLevel(deltaFill, fillType, true)
end

---
-- @param superFunc
--
function HoseSystemPumpMotor:getIsTurnedOn(superFunc)
    if self.pumpIsStarted then
        return true
    end

    if superFunc ~= nil then
        return superFunc(self)
    end

    return false
end

---
-- @param superFunc
-- @param isTurnedOn
--
function HoseSystemPumpMotor:getIsTurnedOnAllowed(superFunc, isTurnedOn)
    if self.fillObjectFound or self.pumpIsStarted then
        return false
    end

    return superFunc(self, isTurnedOn)
end

---
-- @param superFunc
--
function HoseSystemPumpMotor:getConsumedPtoTorque(superFunc)
    if self.pumpIsStarted then
        local rpm = superFunc(self) * HoseSystemPumpMotor.RPM_INCREASE

        return rpm * self.pumpEfficiency.currentScale
    end

    return superFunc(self)
end

---
-- @param id
--
function HoseSystemPumpMotor:setWarningMessage(id)
    self.warningMessage.currentId = id
    self.warningMessage.currentTime = 0
end

---
-- @param message
--
function HoseSystemPumpMotor:showWarningMessage(message)
    g_currentMission:showBlinkingWarning(message)
end

---
-- @param object
-- @param fillMode
-- @param rayCasted
--
function HoseSystemPumpMotor:addFillObject(object, fillMode, rayCasted)
    if not self.isServer then
        return
    end

    if not HoseSystemPumpMotorFactory.allowFillMode(fillMode) then
        return
    end

    local sourceObject = self

    if self.fillArm ~= nil and self.fillArm.needsTransfer then
        local rootVehicle = self:getRootAttacherVehicle()

        sourceObject = HoseSystemPumpMotor.findAttachedTransferTank(rootVehicle)
    elseif self.pumpMotor.isStandalone then
        sourceObject = self.standAloneSourceObject
    end

    if sourceObject ~= nil then
        local allowedFillUnitIndex = self:getAllowedFillUnitIndex(object, sourceObject)

        -- Todo: lookup table insertings on multiple fill objects
        if allowedFillUnitIndex ~= 0 then
            local oldFillmode = self:getFillMode()

            if oldFillmode ~= fillMode then
                self:setFillMode(fillMode)
            end

            self.fillObject = object
            self.fillObjectFound = true
            self.fillFromFillVolume = false -- not implemented
            self.fillObjectIsObject = object:isa(FillTrigger) -- or Object.. but we are actually pumping from a map trigger

            if object.checkPlaneY ~= nil and rayCasted then
                self.fillObjectHasPlane = true
            end

            self.fillUnitIndex = allowedFillUnitIndex
            -- need to set a source object to distrube the fillType to correct vehicle
            self.sourceObject = sourceObject

            self:updateFillObject()
        end
    end
end

---
-- @param object
-- @param fillMode
--
function HoseSystemPumpMotor:removeFillObject(object, fillMode)
    if not self.isServer then
        return
    end

    local oldFillmode = self:getFillMode()
    if oldFillmode == fillMode then
        -- Todo: lookup table insertings on multiple fill objects
        self.sourceObject = nil
        self.fillObject = nil
        self.fillObjectFound = false
        self.fillFromFillVolume = false -- not implemented
        self.fillObjectIsObject = false
        self.fillObjectHasPlane = false
        self.fillUnitIndex = 0
        self:updateFillObject()
    end
end

---
--
function HoseSystemPumpMotor:updateFillObject()
    if self.lastFillObjectFound ~= self.fillObjectFound or self.lastFillFromFillVolume ~= self.fillFromFillVolume or self.lastFillUnitIndex ~= self.fillUnitIndex or self.lastFillObjectHasPlane ~= self.fillObjectHasPlane or self.lastSourceObject ~= self.sourceObject then
        g_server:broadcastEvent(SendUpdateOnFillEvent:new(self, self.fillObjectFound, self.fillFromFillVolume, self.fillUnitIndex, self.fillObjectHasPlane, self.sourceObject))

        self.lastFillUnitIndex = self.fillUnitIndex
        self.lastFillObjectFound = self.fillObjectFound
        self.lastFillFromFillVolume = self.fillFromFillVolume
        self.lastFillObjectHasPlane = self.fillObjectHasPlane
        self.lastSourceObject = self.sourceObject
    end
end

---
-- @param object
-- @param sourceObject
--
function HoseSystemPumpMotor:getAllowedFillUnitIndex(object, sourceObject)
    if sourceObject == nil or sourceObject.fillUnits == nil then
        return 0
    end

    for index, fillUnit in pairs(sourceObject.fillUnits) do
        if fillUnit.currentFillType ~= FillUtil.FILLTYPE_UNKNOWN then
            if object:allowFillType(fillUnit.currentFillType) then
                return index
            end
        else
            local fillTypes = sourceObject:getUnitFillTypes(index)

            for fillType, bool in pairs(fillTypes) do
                -- check if object accepts any of our fillTypes
                if object:allowFillType(fillType) then
                    return index
                end
            end
        end
    end

    return 0
end

---
-- @param object
--
function HoseSystemPumpMotor.findAttachedTransferTank(object)
    if object.transferSystemReferences ~= nil and SpecializationUtil.hasSpecialization(Fillable, object.specializations) then
        local reference = next(object.transferSystemReferences)

        if reference ~= nil then
            return object
        end
    end

    for _, implement in pairs(object.attachedImplements) do
        if implement.object ~= nil then
            local implementFound = HoseSystemPumpMotor.findAttachedTransferTank(implement.object)

            if implementFound ~= nil then
                return implementFound
            end
        end
    end

    return nil
end

--

SetPumpStartedEvent = {}
SetPumpStartedEvent_mt = Class(SetPumpStartedEvent, Event)

InitEventClass(SetPumpStartedEvent, 'SetPumpStartedEvent')

function SetPumpStartedEvent:emptyNew()
    local event = Event:new(SetPumpStartedEvent_mt)
    return event
end

function SetPumpStartedEvent:new(object, isStarted, warningId)
    local event = SetPumpStartedEvent:emptyNew()

    event.object = object
    event.isStarted = isStarted
    event.warningId = warningId

    return event
end

function SetPumpStartedEvent:readStream(streamId, connection)
    self.object = readNetworkNodeObject(streamId)
    self.isStarted = streamReadBool(streamId)

    if streamReadBool(streamId) then
        self.warningId = streamReadUInt8(streamId)
    end

    self:run(connection)
end

function SetPumpStartedEvent:writeStream(streamId, connection)
    writeNetworkNodeObject(streamId, self.object)
    streamWriteBool(streamId, self.isStarted)
    streamWriteBool(streamId, self.warningId ~= nil)

    if self.warningId ~= nil then
        streamWriteUInt8(streamId, self.warningId)
    end
end

function SetPumpStartedEvent:run(connection)
    self.object:setPumpStarted(self.isStarted, self.warningId, true)

    if not connection:getIsServer() then
        g_server:broadcastEvent(self, false, connection, self.object)
    end
end

function SetPumpStartedEvent.sendEvent(object, isStarted, warningId, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(SetPumpStartedEvent:new(object, isStarted, warningId), nil, nil, object)
        else
            g_client:getServerConnection():sendEvent(SetPumpStartedEvent:new(object, isStarted, warningId))
        end
    end
end

--

SetFillDirectionEvent = {}
SetFillDirectionEvent_mt = Class(SetFillDirectionEvent, Event)

InitEventClass(SetFillDirectionEvent, 'SetFillDirectionEvent')

function SetFillDirectionEvent:emptyNew()
    local event = Event:new(SetFillDirectionEvent_mt)
    return event
end

function SetFillDirectionEvent:new(object, int)
    local event = SetFillDirectionEvent:emptyNew()

    event.object = object
    event.int = int

    return event
end

function SetFillDirectionEvent:readStream(streamId, connection)
    self.object = readNetworkNodeObject(streamId)
    self.int = streamReadUIntN(streamId, HoseSystemPumpMotor.sendNumBits)

    self:run(connection)
end

function SetFillDirectionEvent:writeStream(streamId, connection)
    writeNetworkNodeObject(streamId, self.object)
    streamWriteUIntN(streamId, self.int, HoseSystemPumpMotor.sendNumBits)
end

function SetFillDirectionEvent:run(connection)
    self.object:setFillDirection(self.int, true)

    if not connection:getIsServer() then
        g_server:broadcastEvent(self, false, connection, self.object)
    end
end

function SetFillDirectionEvent.sendEvent(object, int, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(SetFillDirectionEvent:new(object, int), nil, nil, object)
        else
            g_client:getServerConnection():sendEvent(SetFillDirectionEvent:new(object, int))
        end
    end
end

--

SetFillModeEvent = {}
SetFillModeEvent_mt = Class(SetFillModeEvent, Event)

InitEventClass(SetFillModeEvent, 'SetFillModeEvent')

function SetFillModeEvent:emptyNew()
    local event = Event:new(SetFillModeEvent_mt)
    return event
end

function SetFillModeEvent:new(object, int)
    local event = SetFillModeEvent:emptyNew()

    event.object = object
    event.int = int

    return event
end

function SetFillModeEvent:readStream(streamId, connection)
    self.object = readNetworkNodeObject(streamId)
    self.int = streamReadUIntN(streamId, HoseSystemPumpMotor.sendNumBits)

    self:run(connection)
end

function SetFillModeEvent:writeStream(streamId, connection)
    writeNetworkNodeObject(streamId, self.object)
    streamWriteUIntN(streamId, self.int, HoseSystemPumpMotor.sendNumBits)
end

function SetFillModeEvent:run(connection)
    self.object:setFillMode(self.int, true)

    if not connection:getIsServer() then
        g_server:broadcastEvent(self, false, connection, self.object)
    end
end

function SetFillModeEvent.sendEvent(object, int, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(SetFillModeEvent:new(object, int), nil, nil, object)
        else
            g_client:getServerConnection():sendEvent(SetFillModeEvent:new(object, int))
        end
    end
end

--

IsSuckingEvent = {}
IsSuckingEvent_mt = Class(IsSuckingEvent, Event)

InitEventClass(IsSuckingEvent, 'IsSuckingEvent')

function IsSuckingEvent:emptyNew()
    local event = Event:new(IsSuckingEvent_mt)
    return event
end

function IsSuckingEvent:new(object, isSucking)
    local event = IsSuckingEvent:emptyNew()

    event.object = object
    event.isSucking = isSucking

    return event
end

function IsSuckingEvent:writeStream(streamId, connection)
    writeNetworkNodeObject(streamId, self.object)
    streamWriteBool(streamId, self.isSucking)
end

function IsSuckingEvent:readStream(streamId, connection)
    self.object = readNetworkNodeObject(streamId)
    self.isSucking = streamReadBool(streamId)

    self:run(connection)
end

function IsSuckingEvent:run(connection)
    self.object.isSucking = self.isSucking
end

--

SendUpdateOnFillEvent = {}
SendUpdateOnFillEvent_mt = Class(SendUpdateOnFillEvent, Event)

InitEventClass(SendUpdateOnFillEvent, 'SendUpdateOnFillEvent')

function SendUpdateOnFillEvent:emptyNew()
    local event = Event:new(SendUpdateOnFillEvent_mt)
    return event
end

function SendUpdateOnFillEvent:new(vehicle, fillObjectFound, fillFromFillVolume, fillUnitIndex, fillObjectHasPlane, sourceObject)
    local event = SendUpdateOnFillEvent:emptyNew()

    event.vehicle = vehicle
    event.fillObjectFound = fillObjectFound
    event.fillFromFillVolume = fillFromFillVolume
    event.fillUnitIndex = fillUnitIndex
    event.fillObjectHasPlane = fillObjectHasPlane
    event.sourceObject = sourceObject

    return event
end

function SendUpdateOnFillEvent:writeStream(streamId, connection)
    writeNetworkNodeObject(streamId, self.vehicle)
    streamWriteBool(streamId, self.fillObjectFound)
    streamWriteBool(streamId, self.fillFromFillVolume)
    streamWriteInt32(streamId, self.fillUnitIndex)
    streamWriteBool(streamId, self.fillObjectHasPlane)
    writeNetworkNodeObject(streamId, self.sourceObject)
end

function SendUpdateOnFillEvent:readStream(streamId, connection)
    self.vehicle = readNetworkNodeObject(streamId)
    self.fillObjectFound = streamReadBool(streamId)
    self.fillFromFillVolume = streamReadBool(streamId)
    self.fillUnitIndex = streamReadInt32(streamId)
    self.fillObjectHasPlane = streamReadBool(streamId)
    self.sourceObject = readNetworkNodeObject(streamId)

    if self.vehicle ~= nil then
        self:run(connection)
    end
end

function SendUpdateOnFillEvent:run(connection)
    self.vehicle.fillObjectFound = self.fillObjectFound
    self.vehicle.fillFromFillVolume = self.fillFromFillVolume
    self.vehicle.fillUnitIndex = self.fillUnitIndex
    self.vehicle.fillObjectHasPlane = self.fillObjectHasPlane
    self.vehicle.sourceObject = self.sourceObject
end
