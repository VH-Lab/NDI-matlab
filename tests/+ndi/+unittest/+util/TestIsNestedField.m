classdef TestIsNestedField < matlab.unittest.TestCase
%TestIsNestedField Comprehensive unit tests for the ndi.util.isNestedField function.
    properties
        SimpleStruct, ArrayStruct, TestObject
    end

    methods(TestMethodSetup)
        function createFixtures(testCase)
            % Fixture for simple dot notation
            testCase.SimpleStruct = struct('a', 1, 'b', struct('c', 2, 'd', struct('e', 3)));
            
            % Fixture for array indexing notation
            s_arr.a(1).b = struct('c', 10);
            s_arr.a(2).b = struct('c', 20);
            s_arr.a(3).b = struct('c', 30);
            testCase.ArrayStruct = s_arr;
            
            % Fixture for object property testing
            testCase.TestObject = ndi.unittest.util.SimpleTestClass(10);
            testCase.TestObject.addprop('NestedProp'); 
            testCase.TestObject.NestedProp = struct('f', 5);
        end
    end

    methods(Test)
        function testExistingPaths(testCase)
            % Test various valid paths
            testCase.verifyTrue(ndi.util.isNestedField(testCase.SimpleStruct, 'a'), 'Failed on simple top-level field.');
            testCase.verifyTrue(ndi.util.isNestedField(testCase.SimpleStruct, 'b.d.e'), 'Failed on simple deep-nested field.');
            testCase.verifyTrue(ndi.util.isNestedField(testCase.ArrayStruct, 'a(1).b.c'), 'Failed on specific array index path.');
            testCase.verifyTrue(ndi.util.isNestedField(testCase.ArrayStruct, 'a(:).b.c'), 'Failed on full colon path.');
            testCase.verifyTrue(ndi.util.isNestedField(testCase.ArrayStruct, 'a(1:2).b.c'), 'Failed on M:N colon path.');
        end

        function testNonExistingPaths(testCase)
            % Test various invalid paths that should return false
            testCase.verifyFalse(ndi.util.isNestedField(testCase.SimpleStruct, 'z'), 'Incorrectly found non-existent top-level field.');
            testCase.verifyFalse(ndi.util.isNestedField(testCase.ArrayStruct, 'a(4)'), 'Incorrectly validated out-of-bounds index.');
            testCase.verifyFalse(ndi.util.isNestedField(testCase.ArrayStruct, 'a(:).z'), 'Incorrectly validated path with non-existent field after colon.');
            testCase.verifyFalse(ndi.util.isNestedField(testCase.SimpleStruct, 'a.b.c'), 'Incorrectly validated an invalid path on a non-struct.');
        end

        function testObjectProperties(testCase)
            % Test paths involving object properties
            testCase.verifyTrue(ndi.util.isNestedField(testCase.TestObject, 'Prop1'), 'Failed on simple object property.');
            testCase.verifyTrue(ndi.util.isNestedField(testCase.TestObject, 'NestedProp.f'), 'Failed on nested field within an object property.');
            testCase.verifyFalse(ndi.util.isNestedField(testCase.TestObject, 'NestedProp.g'), 'Incorrectly found non-existent field in an object property.');
        end

        function testInvalidInputsAndSyntax(testCase)
            % Test that malformed inputs and syntax errors return false
            s = testCase.SimpleStruct;
            testCase.verifyFalse(ndi.util.isNestedField(s, 'a..b'), 'Failed on double-dot input.');
            testCase.verifyFalse(ndi.util.isNestedField(s, '.a'), 'Failed on leading-dot input.');
            testCase.verifyFalse(ndi.util.isNestedField(5, 'a'), 'Failed on non-struct/object input.');
            
            % --- Test for syntax errors ---
            testCase.verifyFalse(ndi.util.isNestedField(s, 'a(1))'), 'Failed on extra closing parenthesis.');
            testCase.verifyFalse(ndi.util.isNestedField(s, 'a((1)'), 'Failed on extra opening parenthesis.');
            testCase.verifyFalse(ndi.util.isNestedField(s, 'a(1)junk'), 'Failed on trailing junk characters.');
            testCase.verifyFalse(ndi.util.isNestedField(s, 'a.2b'), 'Failed on invalid field name.');
        end
    end
end
