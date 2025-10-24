classdef test_ind2subD < matlab.unittest.TestCase
    methods(Test)
        function test_ind2subD_1(testCase)
            % Test a simple case
            sz = [10 11 12];
            ind = 20;
            [I,J,K] = ind2sub(sz,ind);
            sub = ind2subD(sz,ind);
            testCase.verifyEqual([I J K], sub);
        end

        function test_ind2subD_edge(testCase)
            % Test an edge case
            sz = [10 11 12];
            ind = 1;
            [I,J,K] = ind2sub(sz,ind);
            sub = ind2subD(sz,ind);
            testCase.verifyEqual([I J K], sub);
        end

        function test_ind2subD_edge2(testCase)
            % Test another edge case
            sz = [10 11 12];
            ind = prod(sz);
            [I,J,K] = ind2sub(sz,ind);
            sub = ind2subD(sz,ind);
            testCase.verifyEqual([I J K], sub);
        end
    end
end
