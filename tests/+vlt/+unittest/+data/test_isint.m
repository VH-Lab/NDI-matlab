classdef test_isint < matlab.unittest.TestCase
    methods(Test)
        function test_isint_positive(testCase)
            testCase.verifyTrue(logical(vlt.data.isint(5)));
            testCase.verifyTrue(logical(vlt.data.isint(5.0)));
            testCase.verifyFalse(logical(vlt.data.isint(5.1)));
        end

        function test_isint_negative(testCase)
            testCase.verifyTrue(logical(vlt.data.isint(-5)));
            testCase.verifyFalse(logical(vlt.data.isint(-5.1)));
        end

        function test_isint_zero(testCase)
            testCase.verifyTrue(logical(vlt.data.isint(0)));
        end

        function test_isint_array(testCase)
            testCase.verifyTrue(logical(vlt.data.isint([1 2 3])));
            testCase.verifyFalse(logical(vlt.data.isint([1 2.1 3])));
        end

        function test_isint_non_numeric(testCase)
            testCase.verifyFalse(logical(vlt.data.isint('a')));
            testCase.verifyFalse(logical(vlt.data.isint(struct('a',1))));
            testCase.verifyFalse(logical(vlt.data.isint({})) );
        end
    end
end
