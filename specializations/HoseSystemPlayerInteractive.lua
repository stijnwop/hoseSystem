--
-- Created by IntelliJ IDEA.
-- User: stijn
-- Date: 14-4-2017
-- Time: 00:09
-- To change this template use File | Settings | File Templates.
--

HoseSystemPlayerInteractive = {}
local HoseSystemPlayerInteractive_mt = Class(HoseSystemPlayerInteractive)

function HoseSystemPlayerInteractive:new(object, mt)
    local self = {
        object = object
    }

    setmetatable(self, mt == nil and HoseSystemPlayerInteractive_mt or mt)

    return self
end
-- Todo: implement player handling here
function HoseSystemPlayerInteractive:grab() end
function HoseSystemPlayerInteractive:drop() end