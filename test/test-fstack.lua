--------------------------------------------------------------------------------
--! @file
--! @brief Main stack manipulation routines test module.
--! @author btoskin - <brigham@ionoclast.com>
--! @copyright © 2025 Brigham Toskin
--
-- <p>This file is part of the :Firth language reference implementation. Usage
-- and redistribution of this software is governed by the terms of a modified
-- MIT-style license. You should have received a copy of the license with the
-- source distribution; if not, you may find it online at:
-- <https://github.com/IonoclastBrigham/firth/blob/master/LICENSE.firth></p>
--
-- Formatting:
--	utf-8 ; unix ; 80 cols ; tabwidth 4
--------------------------------------------------------------------------------



local fstack = require 'firth.fstack'


-- Automated tests for all firth.fstack routines.
-- Uses global test.assert_eq and expects errors for edge cases.
return {
    -- push
    function()
        local a, b = fstack.push(1, 2)
        test.assert_eq(a, 1, 'push should put first arg on top')
        test.assert_eq(b, 2, 'push should pass through rest')
    end,
    -- top
    function()
        local t = fstack.top(42, 99)
        test.assert_eq(t, 42, 'top should return first arg')
    end,
    -- peek
    function()
        local t = fstack.peek(0, 42, 99)
        test.assert_eq(t, 42, 'peek(0) should return first arg')
        local t2 = fstack.peek(1, 42, 99)
        test.assert_eq(t2, 99, 'peek(1) should return second arg')
    end,
    -- dup
    function()
        local a, b, c = fstack.dup(5, 6)
        test.assert_eq(a, 5, 'dup should duplicate first arg')
        test.assert_eq(b, 5, 'dup should duplicate first arg')
        test.assert_eq(c, 6, 'dup should pass through rest')
    end,
    -- over
    function()
        local a, b, c, d = fstack.over(1, 2, 3)
        test.assert_eq(a, 2, 'over should bring second arg to top')
        test.assert_eq(b, 1, 'over should keep first arg')
        test.assert_eq(c, 2, 'over should duplicate second arg')
        test.assert_eq(d, 3, 'over should keep the third arg')
    end,
    -- drop
    function()
        local a, b, c = fstack.drop(1, 2, 3)
        test.assert_eq(a, 2, 'drop should remove first arg')
        test.assert_eq(b, 3, 'drop should remove first arg')
        test.assert_eq(c, nil, 'drop should remove first arg')
    end,
    -- clear
    function()
        local size = select("#", fstack.clear(1, 2, 3))
        test.assert_eq(size, 0, 'clear should remove all args')
    end,
    -- swap
    function()
        local a, b, c = fstack.swap(1, 2, 3)
        test.assert_eq(a, 2, 'swap should bring second arg to top')
        test.assert_eq(b, 1, 'swap should bring first arg to second')
        test.assert_eq(c, 3, 'swap should pass through rest')

        a, b = fstack.swap(1, 2)
        test.assert_eq(a, 2, 'swap should bring second arg to top')
        test.assert_eq(b, 1, 'swap should bring first arg to second')

        a, b = fstack.swap(1)
        test.assert_eq(a, nil, 'swap with one arg treats second value as nil')
        test.assert_eq(b, 1, 'swap with one arg treats second value as nil')
    end,
    -- rot
    function()
        local a, b, c, d = fstack.rot(1, 2, 3, 4)
        test.assert_eq(a, 3, 'rot should bring third arg to top')
        test.assert_eq(b, 1, 'rot should bring first arg to second')
        test.assert_eq(c, 2, 'rot should bring second arg to third')
        test.assert_eq(d, 4, 'rot should pass through rest')
    end,
    -- -rot
    function()
        local a, b, c, d = fstack['-rot'](1, 2, 3, 4)
        test.assert_eq(a, 2, '-rot should bring second arg to top')
        test.assert_eq(b, 3, '-rot should bring third arg to second')
        test.assert_eq(c, 1, '-rot should bring first arg to third')
        test.assert_eq(d, 4, '-rot should pass through rest')
    end,
    -- pivot
    function()
        local a, b, c, d = fstack.pivot(1, 2, 3, 4)
        test.assert_eq(a, 3, 'pivot should bring third arg to top')
        test.assert_eq(b, 2, 'pivot should bring second arg to second')
        test.assert_eq(c, 1, 'pivot should bring first arg to third')
        test.assert_eq(d, 4, 'pivot should pass through rest')
    end,
    -- pick
    function()
        local a, b, c = fstack.pick(0, 1, 2, 3)
        test.assert_eq(a, 1, 'pick(0) should duplicate first arg')
        local x, y, z = fstack.pick(2, 1, 2, 3)
        test.assert_eq(x, 3, 'pick(2) should bring third arg to top')
    end,
    -- roll
    function()
        local a, b, c = fstack.roll(0, 1, 2, 3)
        test.assert_eq(a, 1, 'roll(0) should pass through unchanged')
        a, b, c = fstack.roll(1, 1, 2, 3)
        test.assert_eq(a, 2, 'roll(1) should swap first two args')
        test.assert_eq(b, 1, 'roll(1) should swap first two args')
        test.assert_eq(c, 3, 'roll(1) should swap first two args')
        a, b, c, d = fstack.roll(2, 1, 2, 3, 4)
        test.assert_eq(a, 3, 'roll(n >= 2) should remove the arg at index and leave it on top')
        test.assert_eq(b, 1, 'roll(n >= 2) should remove the arg at index and leave it on top')
        test.assert_eq(c, 2, 'roll(n >= 2) should remove the arg at index and leave it on top')
        test.assert_eq(d, 4, 'roll(n >= 2) should remove the arg at index and leave it on top')
    end,
    -- shove
    function()
        -- i = 0
        local a, b, c = fstack.shove(0, "inserted", 1, 2)
        test.assert_eq(a, "inserted", 'shove(0) should put x on top')
        test.assert_eq(b, 1, 'shove(0) should pass through rest')
        test.assert_eq(c, 2, 'shove(0) should pass through rest')
        -- i = 1
        local a, b, c = fstack.shove(1, "inserted", 1, 2)
        test.assert_eq(a, 1, 'shove(1) should swap x and tos')
        test.assert_eq(b, "inserted", 'shove(1) should swap x and tos')
        test.assert_eq(c, 2, 'shove(1) should pass through rest')
        -- i = 2; expect stack to be 1, 2, 7, 3
        local a, b, c, d = fstack.shove(2, "inserted", 1, 2, 3)
        test.assert_eq(a, 1, 'shove(2) should revrot x and tos')
        test.assert_eq(b, 2, 'shove(2) should revrot x and tos')
        test.assert_eq(c, "inserted", 'shove(2) should revrot x and tos')
        test.assert_eq(d, 3, 'shove(2) should revrot x and tos')
        -- i = 3 (and higher)
        local a, b, c, d, e = fstack.shove(3, "inserted", 1, 2, 3, 4)
        test.assert_eq(a, 1, 'shove(3) should put x in fourth position')
        test.assert_eq(b, 2, 'shove(3) should put x in fourth position')
        test.assert_eq(c, 3, 'shove(3) should put x in fourth position')
        test.assert_eq(d, "inserted", 'shove(3) should put x in fourth position')
        test.assert_eq(e, 4, 'shove(3) should put x in fourth position')
    end,
    -- yank
    function()
        local a, b = fstack.yank(0, 1, 2)
        test.assert_eq(a, 2, 'yank(0) should remove first arg')
        test.assert_eq(b, nil, 'yank(0) should remove first arg')
        a, b = fstack.yank(1, 1, 2)
        test.assert_eq(a, 1, 'yank(1) should remove second arg')
        test.assert_eq(b, nil, 'yank(1) should remove second arg')
        a, b, c, d = fstack.yank(2, 1, 2, 3, 4)
        test.assert_eq(a, 1, 'yank(2) should remove third arg')
        test.assert_eq(b, 2, 'yank(2) should remove third arg')
        test.assert_eq(c, 4, 'yank(2) should remove third arg')
        test.assert_eq(d, nil, 'yank(2) should remove third arg')
    end,
    -- chop
    function()
        local a, b = fstack.chop(0, 1, 2)
        test.assert_eq(a, 1, 'chop(0) should do nothing')
        test.assert_eq(b, 2, 'chop(0) should do nothing')
        a, b = fstack.chop(1, 1, 2)
        test.assert_eq(a, 2, 'chop(1) should remove first arg')
        test.assert_eq(b, nil, 'chop(1) should remove first arg')
        local d
        a, b, c, d = fstack.chop(2, 1, 2, 3, 4)
        test.assert_eq(a, 3, 'chop(2) should remove first two args')
        test.assert_eq(b, 4, 'chop(2) should remove first two args')
        test.assert_eq(c, nil, 'chop(2) should remove first two args')
        test.assert_eq(d, nil, 'chop(2) should remove first two args')
    end,
    -- height
    function()
        local h, a, b, c = fstack.height(10, 20, 30)
        test.assert_eq(h, 3, 'height should push the number of args on top of the stack')
        test.assert_eq(a, 10, 'height should push the number of args on top of the stack')
        test.assert_eq(b, 20, 'height should push the number of args on top of the stack')
        test.assert_eq(c, 30, 'height should push the number of args on top of the stack')
    end
}
