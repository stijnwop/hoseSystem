HoseSystemStandalonePumpStrategy = {}

HoseSystemStandalonePumpStrategy.MIN_REFERENCES = 2

local HoseSystemStandalonePumpStrategy_mt = Class(HoseSystemStandalonePumpStrategy)

---
-- @param object
--
function HoseSystemStandalonePumpStrategy:prerequisitesPresent(object)
    if not SpecializationUtil.hasSpecialization(HoseSystemConnector, object.specializations) then
        HoseSystemUtil:log(HoseSystemUtil.ERROR, "Strategy HoseSystemStandalonePumpStrategy needs the specialization HoseSystemConnector")

        return false
    end

    return true
end

---
-- @param object
-- @param mt
--
function HoseSystemStandalonePumpStrategy:new(object, mt)
    local pumpStrategy = {
        object = object
    }

    object.standAloneSourceObject = nil

    setmetatable(pumpStrategy, mt == nil and HoseSystemStandalonePumpStrategy_mt or mt)

    return pumpStrategy
end

---
-- @param xmlFile
-- @param key
--
function HoseSystemStandalonePumpStrategy:load(xmlFile, key)
end

function HoseSystemStandalonePumpStrategy:update(dt)
end

---
-- @param ref1
-- @param ref2
--
local sortReferencesByActiveState = function(ref1, ref2)
    return ref1.isActive and not ref2.isActive
end

function HoseSystemStandalonePumpStrategy:updateTick(dt)
    local object = self.object

    if not object.isServer or next(object.attachedHoseSystemReferences) == nil then
        return
    end

    -- use custom since we need the number of elements which are not nil, the # or maxn operator won't do in this case..
    if HoseSystemUtil.getNoNilAmount(object.attachedHoseSystemReferences) >= HoseSystemStandalonePumpStrategy.MIN_REFERENCES then -- we only need two sources.
        table.sort(object.attachedHoseSystemReferences, sortReferencesByActiveState)

        for _, entry in pairs({ unpack(object.attachedHoseSystemReferences, 1, 2) }) do
            if entry ~= nil and entry.isActive and entry.fillObject ~= nil then
                if entry.fillObject ~= object.fillObject and entry.fillObject ~= object.standAloneSourceObject then
                    object.standAloneSourceObject = entry.fillObject
                    object:addFillObject(object.fillObject, object:getFillMode())
                end
            end
        end

        if g_hoseSystem.debugRendering then
            --            local debugTable = {}
            --
            --            for _, n in pairs(self.object.attachedHoseSystemReferences) do
            --                table.insert(debugTable, { isActive = n.isActive })
            --            end
            --
            --            HoseSystemUtil:log(HoseSystemUtil.DEBUG, debugTable)
        end
    end
end
