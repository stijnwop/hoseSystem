--
-- Created by IntelliJ IDEA.
-- User: Stijn Wopereis
-- Date: 13-4-2017
-- Time: 18:36
-- To change this template use File | Settings | File Templates.
--

HoseSystemUtil = {
    consoleCommandToggleHoseSystemDebugRendering = function(unusedSelf)
        HoseSystem.debugRendering = not HoseSystem.debugRendering

        return "HoseSystemDebugRendering = "..tostring(HoseSystem.debugRendering)
    end
}

addConsoleCommand("gsToggleHoseSystemDebugRendering", "Toggles the debug rendering of the HoseSystem", "consoleCommandToggleHoseSystemDebugRendering", HoseSystemUtil)