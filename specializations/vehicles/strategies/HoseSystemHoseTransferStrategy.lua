HoseSystemHoseTransferStrategy = {}

local HoseSystemHoseTransferStrategy_mt = Class(HoseSystemHoseTransferStrategy)

---
-- @param object
-- @param mt
--
function HoseSystemHoseTransferStrategy:new(object, mt)
    local hoseTransferStrategy = {
        object = object
    }

    setmetatable(hoseTransferStrategy, mt == nil and HoseSystemHoseTransferStrategy_mt or mt)

    return hoseTransferStrategy
end

---
-- @param xmlFile
-- @param key
-- @param entry
--
function HoseSystemHoseTransferStrategy:loadTransfer(xmlFile, key, entry)
    entry.hasVisuals = Utils.getNoNil(getXMLBool(xmlFile, key .. '#hasVisuals'), false)

    if entry.hasVisuals then
        -- Todo: setup nodes for a visual hose connection
        -- entry.node = Utils.indexToObject(self.object.components, getXMLString(xmlFile, key .. '#node'))
    end

    table.insert(self.object.transferSystemReferences, entry)

    return entry
end

function HoseSystemHoseTransferStrategy:update(dt)
end

function HoseSystemHoseTransferStrategy:updateTick(dt)
end
