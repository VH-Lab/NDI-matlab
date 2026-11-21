classdef TestEntryValue < matlab.unittest.TestCase
%TESTENTRYVALUE ndi.v2.entryValue reads every value form of a condition / method-parameter entry.
%
%   did-schema #88: an entry holds ONE of term, numeric, count, text or
%   logical (Jess Haley 2026-10-22 [logical entries]); `numeric` replaced
%   quantity and matrix (did-schema did_v2_numeric_shape_plan.md, [one
%   shape for measured numbers], Jess Haley, 2026-11-17), and an entry that
%   still holds those is refused ([no migrated database is kept], Jess
%   Haley, 2026-11-19). A stored entry may carry the other forms' blanks
%   (statement.conditions: count 0, logical false, text '', numeric []), so
%   each case is also read with every other form's blank beside it.

    methods (Test)
        function testEachFormAlone(testCase)
            [v, ~, k] = ndi.v2.entryValue(struct('variable', t('x'), 'logical', true));
            testCase.verifyEqual({v, k}, {true, 'logical'});
            [v, ~, k] = ndi.v2.entryValue(struct('variable', t('x'), 'logical', false));
            testCase.verifyEqual({v, k}, {false, 'logical'});
            [v, ~, k] = ndi.v2.entryValue(struct('variable', t('x'), 'count', 3));
            testCase.verifyEqual({v, k}, {3, 'count'});
            [v, ~, k] = ndi.v2.entryValue(struct('variable', t('x'), 'numeric', [1 2; 3 4]));
            testCase.verifyEqual({v, k}, {[1 2; 3 4], 'matrix'});
            [v, ~, k] = ndi.v2.entryValue(struct('variable', t('x'), 'text', 'on'));
            testCase.verifyEqual({v, k}, {'on', 'text'});
        end

        function testWithTheOtherFormsBlanks(testCase)
            b = struct('variable', t('x'), 'term', t(''), 'quantity', struct(), ...
                'count', 0, 'text', '', 'logical', false, 'matrix', [], 'numeric', []);
            e = b; e.logical = true;
            [v, ~, k] = ndi.v2.entryValue(e);
            testCase.verifyEqual({v, k}, {true, 'logical'}, 'a stored true is logical');
            e = b; e.count = 5;
            [v, ~, k] = ndi.v2.entryValue(e);
            testCase.verifyEqual({v, k}, {5, 'count'}, 'a count beside a blank logical');
            e = b; e.numeric = [1 0 1];
            [v, ~, k] = ndi.v2.entryValue(e);
            testCase.verifyEqual({v, k}, {[1 0 1], 'matrix'});
            e = b; e.matrix = [1 0 1];
            testCase.verifyError(@() ndi.v2.entryValue(e), 'ndi:v2:oldNumericShapeReMigrate', ...
                'an old-shape matrix is refused');
            e = b; e.term = t('on');
            [v, ~, k] = ndi.v2.entryValue(e);
            testCase.verifyEqual({v, k}, {'on', 'term'});
        end
    end
end

function x = t(name)
x = struct('node', '', 'name', name);
end
