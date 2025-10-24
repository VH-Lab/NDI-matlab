classdef test_islikevarname < matlab.unittest.TestCase
    methods(Test)
        function test_islikevarname_valid(testCase)
            testCase.verifyTrue(logical(vlt.data.islikevarname('a')));
            testCase.verifyTrue(logical(vlt.data.islikevarname('a_variable')));
            testCase.verifyTrue(logical(vlt.data.islikevarname('a1')));
            testCase.verifyTrue(logical(vlt.data.islikevarname(repmat('a',1,namelengthmax))));
        end

        function test_islikevarname_invalid(testCase)
            testCase.verifyFalse(logical(vlt.data.islikevarname('1a')));
            testCase.verifyFalse(logical(vlt.data.islikevarname('_a')));
            testCase.verifyFalse(logical(vlt.data.islikevarname('a-b')));
            testCase.verifyFalse(logical(vlt.data.islikevarname('a b')));
            testCase.verifyFalse(logical(vlt.data.islikevarname('a!')));
            testCase.verifyFalse(logical(vlt.data.islikevarname(repmat('a',1,namelengthmax+1))));
        end

        function test_islikevarname_cell(testCase)
            testCase.verifyTrue(logical(vlt.data.islikevarname({'a','b'})));
            testCase.verifyFalse(logical(vlt.data.islikevarname({'a','1b'})));
        end

        function test_islikevarname_non_string(testCase)
            testCase.verifyFalse(logical(vlt.data.islikevarname(5)));
            testCase.verifyFalse(logical(vlt.data.islikevarname(struct('a',1))));
            testCase.verifyFalse(logical(vlt.data.islikevarname({5,10})));
        end
    end
end
