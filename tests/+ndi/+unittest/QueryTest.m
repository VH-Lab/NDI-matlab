classdef QueryTest < matlab.unittest.TestCase

    properties
    end

    methods (Test)
        function test_all_query(testCase)
            q = ndi.query.all();
            testCase.verifyEqual(q.searchstructure.field, '');
            testCase.verifyEqual(q.searchstructure.operation, 'isa');
            testCase.verifyEqual(q.searchstructure.param1, 'base');
        end

        function test_none_query(testCase)
            q = ndi.query.none();
            testCase.verifyEqual(q.searchstructure.field, '');
            testCase.verifyEqual(q.searchstructure.operation, 'isa');
            testCase.verifyEqual(q.searchstructure.param1, 'ladskjfldksjfkds');
        end
    end
end
