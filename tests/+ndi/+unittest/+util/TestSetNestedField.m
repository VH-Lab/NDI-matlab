classdef TestSetNestedField < matlab.unittest.TestCase
%TestSetNested Comprehensive unit tests for the ndi.util.setNested function.

    properties
        SimpleStruct, NestedStruct, ArrayStruct, TestObject
    end

    methods(TestMethodSetup)
        function createFixtures(testCase)
            testCase.SimpleStruct = struct('a', 1, 'b', 2);
            testCase.NestedStruct = struct('a', 1, 'b', struct('c', 2, 'd', struct('e', 3)));
            
            s_arr.a(1).b = struct('c', 10);
            s_arr.a(2).b = struct('c', 20);
            s_arr.a(3).b = struct('c', 30);
            testCase.ArrayStruct = s_arr;
            
            testCase.TestObject = ndi.unittest.util.SimpleTestClass(10);
        end
    end

    methods(Test)

        function testSimpleAssignment(testCase)
            s_in = testCase.SimpleStruct;
            s_out = ndi.util.setNestedField(s_in, 'a', 99);
            testCase.verifyEqual(s_out.a, 99);

            s_in_nest = testCase.NestedStruct;
            s_out_nest = ndi.util.setNestedField(s_in_nest, 'b.d.e', 101);
            testCase.verifyEqual(s_out_nest.b.d.e, 101);
        end

        function testNewFieldCreation(testCase)
            s_in = testCase.SimpleStruct;
            s_out = ndi.util.setNestedField(s_in, 'x.y.z', 500);
            testCase.verifyEqual(s_out.x.y.z, 500);
        end

        function testIndexedAssignment(testCase)
            s_new = ndi.util.setNestedField(testCase.ArrayStruct, 'a(1).b.c', 99);
            testCase.verifyEqual(s_new.a(1).b.c, 99);
            
            s_new_ext = ndi.util.setNestedField(testCase.ArrayStruct, 'a(4).b.c', 101);
            testCase.verifySize(s_new_ext.a, [1 4]);
            testCase.verifyEqual(s_new_ext.a(4).b.c, 101);
        end
        
        function testSetSingleValueToRange(testCase)
            % This tests the default behavior (SetRange=false)
            s = testCase.ArrayStruct;
            
            s_new = ndi.util.setNestedField(s, 'a(1:2).b.c', 999);
            testCase.verifyEqual(s_new.a(1).b.c, 999);
            testCase.verifyEqual(s_new.a(2).b.c, 999);
            testCase.verifyEqual(s_new.a(3).b.c, 30, 'Unmodified element should be untouched.');
        end

        function testSetRange(testCase)
            s = testCase.ArrayStruct;
            
            % --- Test valid range setting ---
            values_to_set = {'hello', 'world'};
            s_new = ndi.util.setNestedField(s, 'a(1:2).b.c', values_to_set, 'SetRange', true);
            testCase.verifyEqual(s_new.a(1).b.c, 'hello');
            testCase.verifyEqual(s_new.a(2).b.c, 'world');
            
            % --- Test with full colon ---
            values_to_set_full = {100, 200, 300};
            s_new_full = ndi.util.setNestedField(s, 'a(:).b.c', values_to_set_full, 'SetRange', true);
            testCase.verifyEqual(s_new_full.a(1).b.c, 100);
            testCase.verifyEqual(s_new_full.a(2).b.c, 200);
            testCase.verifyEqual(s_new_full.a(3).b.c, 300);

            % --- Test error conditions ---
            testCase.verifyError(...
                @() ndi.util.setNestedField(s, 'a(1:2).b.c', {1}, 'SetRange', true), ...
                'setNestedField:SetRangeSizeMismatch');
            
            testCase.verifyError(...
                @() ndi.util.setNestedField(s, 'a(1:2).b.c', [1 2], 'SetRange', true), ...
                'setNestedField:SetRangeValueNotCell');
            
            testCase.verifyError(...
                @() ndi.util.setNestedField(s, 'a', {1}, 'SetRange', true), ...
                'setNestedField:SetRangeNoIndex');
        end
        
        function testInputValidationAndOptions(testCase)
            s = testCase.SimpleStruct;
            testCase.verifyError(@() ndi.util.setNestedField(123, 'a', 1), 'setNestedField:invalidInputType');
            
            testCase.verifyError(...
                @() ndi.util.setNestedField(s, 'c', 5, 'ErrIfDoesNotExist', true), ...
                'setNestedField:fieldNotFound');

            testCase.verifyError(@() ndi.util.setNestedField(s, 'a..b', 5), 'stringToSubstruct:invalidFieldString');
        end
    end
end
