classdef test_isfullfield < matlab.unittest.TestCase
    methods(Test)
        function test_isfullfield_simple(testCase)
            s = struct('a', 5, 'b', []);
            testCase.verifyTrue(logical(vlt.data.isfullfield(s, 'a')));
            testCase.verifyFalse(logical(vlt.data.isfullfield(s, 'b')));
            testCase.verifyFalse(logical(vlt.data.isfullfield(s, 'c')));
        end

        function test_isfullfield_nested(testCase)
            s = struct('a', struct('b', 5, 'c', []));
            testCase.verifyTrue(logical(vlt.data.isfullfield(s, 'a.b')));
            testCase.verifyFalse(logical(vlt.data.isfullfield(s, 'a.c')));
            testCase.verifyFalse(logical(vlt.data.isfullfield(s, 'a.d')));
        end

        function test_isfullfield_struct_array(testCase)
            s = [struct('a', 5) struct('a', 6)];
            testCase.verifyTrue(logical(vlt.data.isfullfield(s, 'a')));
            s = [struct('a', 5) struct('a', [])];
            testCase.verifyFalse(logical(vlt.data.isfullfield(s, 'a')));
            s = [struct('a', 5) struct('b', 5)];
            testCase.verifyFalse(logical(vlt.data.isfullfield(s, 'a')));
        end

        function test_isfullfield_non_struct(testCase)
            testCase.verifyFalse(logical(vlt.data.isfullfield(5, 'a')));
            testCase.verifyFalse(logical(vlt.data.isfullfield('a', 'a')));
            testCase.verifyFalse(logical(vlt.data.isfullfield({}, 'a')));
        end
    end
end
