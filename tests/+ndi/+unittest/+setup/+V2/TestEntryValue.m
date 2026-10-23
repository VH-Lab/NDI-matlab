classdef TestEntryValue < matlab.unittest.TestCase
%TESTENTRYVALUE ndi.v2.entryValue reads every value form of a condition / method-parameter entry.
%
%   did-schema #88: an entry holds ONE of term, quantity, count, text,
%   logical (Jess Haley 2026-10-22 [logical entries]) or matrix (data_body
%   AMENDMENT 4). A stored entry may carry the other forms' blanks
%   (statement.conditions: count 0, logical false, text '', matrix []), so
%   each case is also read with every other form's blank beside it.

    methods (Test)
        function testEachFormAlone(testCase)
            [v, ~, k] = ndi.v2.entryValue(struct('variable', t('x'), 'logical', true));
            testCase.verifyEqual({v, k}, {true, 'logical'});
            [v, ~, k] = ndi.v2.entryValue(struct('variable', t('x'), 'logical', false));
            testCase.verifyEqual({v, k}, {false, 'logical'});
            [v, ~, k] = ndi.v2.entryValue(struct('variable', t('x'), 'count', 3));
            testCase.verifyEqual({v, k}, {3, 'count'});
            [v, ~, k] = ndi.v2.entryValue(struct('variable', t('x'), 'matrix', [1 2; 3 4]));
            testCase.verifyEqual({v, k}, {[1 2; 3 4], 'matrix'});
            [v, ~, k] = ndi.v2.entryValue(struct('variable', t('x'), 'text', 'on'));
            testCase.verifyEqual({v, k}, {'on', 'text'});
        end

        function testWithTheOtherFormsBlanks(testCase)
            b = struct('variable', t('x'), 'term', t(''), 'quantity', struct(), ...
                'count', 0, 'text', '', 'logical', false, 'matrix', []);
            e = b; e.logical = true;
            [v, ~, k] = ndi.v2.entryValue(e);
            testCase.verifyEqual({v, k}, {true, 'logical'}, 'a stored true is logical');
            e = b; e.count = 5;
            [v, ~, k] = ndi.v2.entryValue(e);
            testCase.verifyEqual({v, k}, {5, 'count'}, 'a count beside a blank logical');
            e = b; e.matrix = [1 0 1];
            [v, ~, k] = ndi.v2.entryValue(e);
            testCase.verifyEqual({v, k}, {[1 0 1], 'matrix'});
            e = b; e.term = t('on');
            [v, ~, k] = ndi.v2.entryValue(e);
            testCase.verifyEqual({v, k}, {'on', 'term'});
        end
    end
end

function x = t(name)
x = struct('node', '', 'name', name);
end
