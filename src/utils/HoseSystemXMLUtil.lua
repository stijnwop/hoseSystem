HoseSystemXMLUtil = {}

---
-- @param components
-- @param xmlFile
-- @param key
-- @param index
--
function HoseSystemXMLUtil.getOrCreateNode(components, xmlFile, key, index)
    if Utils.getNoNil(getXMLBool(xmlFile, key .. '#createNode'), false) then
        if index == nil then
            index = 0
        end

        local node = createTransformGroup(('hoseSystemReference_node_%d'):format(index + 1))
        local linkNode = Utils.indexToObject(components, Utils.getNoNil(getXMLString(xmlFile, key .. '#linkNode'), '0>'))

        local translation = { Utils.getVectorFromString(getXMLString(xmlFile, key .. '#position')) }
        if translation[1] ~= nil and translation[2] ~= nil and translation[3] ~= nil then
            setTranslation(node, unpack(translation))
        end

        local rotation = { Utils.getVectorFromString(getXMLString(xmlFile, key .. '#rotation')) }
        if rotation[1] ~= nil and rotation[2] ~= nil and rotation[3] ~= nil then
            setRotation(node, Utils.degToRad(rotation[1]), Utils.degToRad(rotation[2]), Utils.degToRad(rotation[3]))
        end

        link(linkNode, node)

        return node
    end

    return Utils.indexToObject(components, getXMLString(xmlFile, key .. '#index'))
end