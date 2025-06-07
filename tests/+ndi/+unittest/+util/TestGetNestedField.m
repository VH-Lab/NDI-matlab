classdef TestGetNestedField < matlab.unittest.TestCase
%TestGetNested Comprehensive unit tests for the ndi.util.getNested function.

    properties
        SimpleStruct
        ArrayStruct
        TestObject
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

        function testSingleValueGet(testCase)
            % Test getting single scalar values from various path types.
            testCase.verifyEqual(ndi.util.getNestedField(testCase.SimpleStruct, 'a'), 1);
            testCase.verifyEqual(ndi.util.getNestedField(testCase.SimpleStruct, 'b.d.e'), 3);
            testCase.verifyEqual(ndi.util.getNestedField(testCase.ArrayStruct, 'a(2).b.c'), 20);
            testCase.verifyEqual(ndi.util.getNestedField(testCase.TestObject, 'Prop1'), 10);
            testCase.verifyEqual(ndi.util.getNestedField(testCase.TestObject, 'NestedProp.f'), 5);
        end

        function testComplexValueGet(testCase)
            % Test getting non-scalar values like structs and arrays.
            st = ndi.util.getNestedField(testCase.ArrayStruct, 'a(1).b');
            testCase.verifyEqual(st, struct('c',10));
            
            arr = ndi.util.getNestedField(testCase.ArrayStruct, 'a');
            testCase.verifyEqual(arr, testCase.ArrayStruct.a);
            testCase.verifySize(arr, [1 3]);
        end

        function testColonOperatorGet(testCase)
            % Test getting multiple values using the colon operator, which
            % should ALWAYS return a single cell array.
            s = testCase.ArrayStruct;

            % Test with the full colon ':'
            vals_cell_full = ndi.util.getNestedField(s, 'a(:).b.c');
            testCase.verifyClass(vals_cell_full, 'cell', 'Did not return a cell array for full colon path.');
            testCase.verifyEqual(vals_cell_full, {10, 20, 30});
            
            % Test with a numerical range M:N
            vals_cell_range = ndi.util.getNestedField(s, 'a(1:2).b.c');
            testCase.verifyClass(vals_cell_range, 'cell', 'Did not return a cell array for M:N colon path.');
            testCase.verifyEqual(vals_cell_range, {10, 20});
        end
        
        function testErrorConditions(testCase)
            % Verify that an error is thrown for various invalid paths.
            s_simple = testCase.SimpleStruct;
            s_array = testCase.ArrayStruct;
            
            % --- Test for non-existent paths ---
            testCase.verifyError(@() ndi.util.getNestedField(s_simple, 'x.y.z'), 'getNestedField:pathNotFound');
            testCase.verifyError(@() ndi.util.getNestedField(s_array, 'a(4).b'), 'getNestedField:pathNotFound');
            testCase.verifyError(@() ndi.util.getNestedField(s_array, 'a(:).z'), 'getNestedField:pathNotFound');

            % --- Test for syntax errors (should be caught and re-thrown) ---
            testCase.verifyError(@() ndi.util.getNestedField(s_simple, 'a..b'), 'getNestedField:pathNotFound');
            testCase.verifyError(@() ndi.util.getNestedField(s_simple, 'a(1))'), 'getNestedField:pathNotFound');
            testCase.verifyError(@() ndi.util.getNestedField(s_simple, 'a(1)junk'), 'getNestedField:pathNotFound');
        end

    end
end
