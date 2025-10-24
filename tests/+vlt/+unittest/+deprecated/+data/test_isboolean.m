classdef test_isboolean < matlab.unittest.TestCase
    methods(Test)
        function test_isboolean_logical(testCase)
            testCase.verifyTrue(logical(isboolean(true)));
            testCase.verifyTrue(logical(isboolean(false)));
        end

        function test_isboolean_numeric(testCase)
            testCase.verifyTrue(logical(isboolean(1)));
            testCase.verifyTrue(logical(isboolean(0)));
            testCase.verifyFalse(logical(isboolean(2)));
            testCase.verifyFalse(logical(isboolean(-1)));
        end

        function test_isboolean_array(testCase)
            testCase.verifyTrue(logical(isboolean([true false 1 0])));
            testCase.verifyFalse(logical(isboolean([1 2 0])));
        end

        function test_isboolean_empty(testCase)
            testCase.verifyTrue(logical(isboolean([])));
        end

        function test_isboolean_non_numeric(testCase)
            testCase.verifyFalse(logical(isboolean('a')));
            testCase.verifyFalse(logical(isboolean(struct('a',1))));
            testCase.verifyFalse(logical(isboolean({})));
        end
    end
end
