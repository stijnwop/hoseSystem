#! /usr/bin/env lua

if not pcall(require, 'tests.hosesystem_test_suite') then
    -- run_unit_tests shall also work when called directly from the test directory
    require('tests.hosesystem_test_suite')
end

local lu = require('luaunit')

lu.LuaUnit.verbosity = 2

os.exit(lu.LuaUnit.run())

