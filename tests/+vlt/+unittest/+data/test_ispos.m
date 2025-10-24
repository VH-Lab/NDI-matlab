classdef test_ispos < matlab.unittest.TestCase
    methods(Test)
        function test_ispos_positive(testCase)
            testCase.verifyTrue(logical(vlt.data.ispos(5)));
            testCase.verifyTrue(logical(vlt.data.ispos(5.1)));
        end

        function test_ispos_negative(testCase)
            testCase.verifyFalse(logical(vlt.data.ispos(-5)));
            testCase.verifyFalse(logical(vlt.data.ispos(-5.1)));
        end

        function test_ispos_zero(testCase)
            testCase.verifyFalse(logical(vlt.data.ispos(0)));
        end

        function test_ispos_array(testCase)
            testCase.verifyTrue(logical(vlt.data.ispos([1 2 3])));
            testCase.verifyFalse(logical(vlt.data.ispos([1 -2 3])));
            testCase.verifyFalse(logical(vlt.data.ispos([1 0 3])));
        end

        function test_ispos_non_numeric(testCase)
            testCase.verifyFalse(logical(vlt.data.ispos('a')));
            testCase.verifyFalse(logical(vlt.data.ispos(struct('a',1))));
            testCase.verifyFalse(logical(vlt.data.ispos({})));
        end
    end
end
