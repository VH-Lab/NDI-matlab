classdef test_islikevarname < matlab.unittest.TestCase
    methods(Test)
        function test_islikevarname_valid(testCase)
            testCase.verifyTrue(logical(islikevarname('a')));
            testCase.verifyTrue(logical(islikevarname('a_variable')));
            testCase.verifyTrue(logical(islikevarname('a1')));
            testCase.verifyTrue(logical(islikevarname(repmat('a',1,namelengthmax))));
        end

        function test_islikevarname_invalid(testCase)
            testCase.verifyFalse(logical(islikevarname('1a')));
            testCase.verifyFalse(logical(islikevarname('_a')));
            testCase.verifyFalse(logical(islikevarname('a-b')));
            testCase.verifyFalse(logical(islikevarname('a b')));
            testCase.verifyFalse(logical(islikevarname('a!')));
            testCase.verifyFalse(logical(islikevarname(repmat('a',1,namelengthmax+1))));
        end

        function test_islikevarname_cell(testCase)
            testCase.verifyTrue(logical(islikevarname({'a','b'})));
            testCase.verifyFalse(logical(islikevarname({'a','1b'})));
        end

        function test_islikevarname_non_string(testCase)
            testCase.verifyFalse(logical(islikevarname(5)));
            testCase.verifyFalse(logical(islikevarname(struct('a',1))));
            testCase.verifyFalse(logical(islikevarname({5,10})));
        end
    end
end
