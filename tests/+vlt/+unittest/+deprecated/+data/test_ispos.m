classdef test_ispos < matlab.unittest.TestCase
    methods(Test)
        function test_ispos_positive(testCase)
            testCase.verifyTrue(logical(ispos(5)));
            testCase.verifyTrue(logical(ispos(5.1)));
        end

        function test_ispos_negative(testCase)
            testCase.verifyFalse(logical(ispos(-5)));
            testCase.verifyFalse(logical(ispos(-5.1)));
        end

        function test_ispos_zero(testCase)
            testCase.verifyFalse(logical(ispos(0)));
        end

        function test_ispos_array(testCase)
            testCase.verifyTrue(logical(ispos([1 2 3])));
            testCase.verifyFalse(logical(ispos([1 -2 3])));
            testCase.verifyFalse(logical(ispos([1 0 3])));
        end

        function test_ispos_non_numeric(testCase)
            testCase.verifyFalse(logical(ispos('a')));
            testCase.verifyFalse(logical(ispos(struct('a',1))));
            testCase.verifyFalse(logical(ispos({})));
        end
    end
end
