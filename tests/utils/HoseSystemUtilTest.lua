--
-- HoseSystemUtilTest
--
-- Authors:    	Wopster
-- Description: Testcase for the util
--
-- Copyright (c) Wopster, 2018

require("src.utils.HoseSystemUtil")

local lu = require('luaunit')

---
--
function testStrFirstToUpper()
    -- setup
    local upperStr = HoseSystemUtil:firstToUpper('hoseSystem')
    -- test
    lu.assertEquals(upperStr, "HoseSystem")
    lu.assertStrMatches(upperStr, "HoseSystem")
end

---
--
function testFirstElementFromList()
    -- setup
    local element = { t = 1 }
    local list = { element, { t = 2 } }
    local listElement = HoseSystemUtil:getElementFromList(list, element)
    -- test
    lu.assertEquals(listElement, element)
end

---
--
function testHasListElement()
    -- setup
    local element = { t = 1 }
    local list = { element, { t = 2 } }
    -- test
    lu.assertTrue(HoseSystemUtil.getHasListElement(list, element))
end

---
--
function testRemoveListElement()
    -- setup
    local element = { t = 1 }
    local list = { element }
    -- test
    HoseSystemUtil:removeElementFromList(list, element)
    lu.assertEquals(list, {})
end

---
--
function testGetFirstElement()
    -- setup
    local element = { t = 1 }
    local list = { element, { t = 2 } }
    -- test
    lu.assertEquals(element, HoseSystemUtil:getFirstElement(list))
end

---
--
function testGetLastElement()
    -- setup
    local element = { t = 1 }
    local list = { { t = 2 }, element }
    -- test
    lu.assertEquals(element, HoseSystemUtil:getLastElement(list))
end