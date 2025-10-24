classdef test_isempty_cell < matlab.unittest.TestCase
    methods(Test)
        function test_empty_cell(testCase)
            c = {};
            out = isempty_cell(c);
            testCase.verifyTrue(logical(out));
        end

        function test_cell_with_empty_elements(testCase)
            c = {[], [], []};
            out = isempty_cell(c);
            testCase.verifyTrue(logical(out));
        end

        function test_cell_with_mixed_elements(testCase)
            c = {[], 'hello', []};
            out = isempty_cell(c);
            testCase.verifyFalse(logical(out));
        end

        function test_cell_with_no_empty_elements(testCase)
            c = {'world', 'hello', 'again'};
            out = isempty_cell(c);
            testCase.verifyFalse(logical(out));
        end
    end
end
