--
-- HoseSystemHoseCouplingStrategy
--
-- Authors: Wopster
-- Description: Strategy for loading hose couplings
--
-- Copyright (c) Wopster, 2017

HoseSystemHoseCouplingStrategy = {}

HoseSystemHoseCouplingStrategy.TYPE = 'hoseCoupling'

local HoseSystemHoseCouplingStrategy_mt = Class(HoseSystemHoseCouplingStrategy)

---
-- @param object
-- @param mt
--
function HoseSystemHoseCouplingStrategy:new(object, mt)
    local hoseCouplingStrategy = {
        object = object
    }

    setmetatable(hoseCouplingStrategy, mt == nil and HoseSystemHoseCouplingStrategy_mt or mt)

    return hoseCouplingStrategy
end

---
--
function HoseSystemHoseCouplingStrategy:delete()
end

---
-- @param type
-- @param xmlFile
-- @param key
-- @param entry
--
function HoseSystemHoseCouplingStrategy:loadHoseCoupling(type, xmlFile, key, entry)
    if type ~= HoseSystemConnector.getInitialType(HoseSystemHoseCouplingStrategy.TYPE) then
        return entry
    end

    entry.isUsed = false
    entry.flowOpened = false
    entry.isLocked = false
    entry.hoseSystem = nil
    entry.grabPoints = nil
    entry.isObject = false
    entry.componentIndex = Utils.getNoNil(getXMLFloat(xmlFile, key .. 'componentIndex'), 0) + 1
    entry.parkable = Utils.getNoNil(getXMLBool(xmlFile, key .. '#parkable'), false)
    entry.lockAnimationName = Utils.getNoNil(getXMLString(xmlFile, key .. '#lockAnimationName'), nil)
    entry.manureFlowAnimationName = Utils.getNoNil(getXMLString(xmlFile, key .. '#manureFlowAnimationName'), nil)

    if entry.parkable then
        entry.parkAnimationName = Utils.getNoNil(getXMLString(xmlFile, key .. '#parkAnimationName'), nil)
        entry.parkLength = Utils.getNoNil(getXMLFloat(xmlFile, key .. '#parkLength'), 5) -- Default length of 5m
        local offsetDirection = Utils.getNoNil(getXMLString(xmlFile, key .. '#offsetDirection'), 'right')
        entry.offsetDirection = string.lower(offsetDirection) ~= 'right' and HoseSystemUtil.DIRECTION_LEFT or HoseSystemUtil.DIRECTION_RIGHT
        entry.startTransOffset = Utils.getNoNil(Utils.getVectorNFromString(getXMLString(xmlFile, key .. '#startTransOffset'), 3), { 0, 0, 0 })
        entry.startRotOffset = Utils.getNoNil(Utils.getVectorNFromString(getXMLString(xmlFile, key .. '#startRotOffset'), 3), { 0, 0, 0 })
        entry.endTransOffset = Utils.getNoNil(Utils.getVectorNFromString(getXMLString(xmlFile, key .. '#endTransOffset'), 3), { 0, 0, 0 })
        entry.endRotOffset = Utils.getNoNil(Utils.getVectorNFromString(getXMLString(xmlFile, key .. '#endRotOffset'), 3), { 0, 0, 0 })

        local maxNode = createTransformGroup(('hoseSystemReference_park_maxNode_%d'):format(entry.id))
        local trans = { localToWorld(entry.node, 0, 0, entry.offsetDirection ~= 1 and -entry.parkLength or entry.parkLength) }

        link(entry.node, maxNode)
        setWorldTranslation(maxNode, unpack(trans))

        entry.maxParkLengthNode = maxNode
    end

    return entry
end