classdef TestIsAlphaNumericStruct < matlab.unittest.TestCase
%TESTISALPHANUMERICSTRUCT Unit tests for the ndi.util.isAlphaNumericStruct function.

    methods (Test)

        function testValidFlatStruct(testCase)
            % Test with a simple structure containing only numbers and chars.
            s = struct('field1', 10, 'field2', 'hello', 'field3', [1 2 3]);
            [isValid, errors] = ndi.util.isAlphaNumericStruct(s);
            testCase.assertTrue(isValid, 'Flat struct with valid types should be valid.');
            testCase.assertEmpty(errors, 'Errors should be empty for a valid flat struct.');
        end

        function testValidNestedScalarStruct(testCase)
            % Test with a structure containing a nested scalar structure.
            s = struct();
            s.level1_num = 10;
            s.level1_char = 'hello';
            s.level1_nest = struct('level2_num', 20, 'level2_char', 'world');
            [isValid, errors] = ndi.util.isAlphaNumericStruct(s);
            testCase.assertTrue(isValid, 'Struct with valid nested scalar struct should be valid.');
            testCase.assertEmpty(errors, 'Errors should be empty for a valid nested struct.');
        end

        function testValidStructArrayField(testCase)
            % Test with a structure containing a field that is a struct array.
            s = struct();
            s.struct_array_field(1).item = 'item1_text';
            s.struct_array_field(1).value = 101;
            s.struct_array_field(2).item = 'item2_text';
            s.struct_array_field(2).value = 202;
            s.another_field = 'top_level_char';
            [isValid, errors] = ndi.util.isAlphaNumericStruct(s);
            testCase.assertTrue(isValid, 'Struct with valid struct array field should be valid.');
            testCase.assertEmpty(errors, 'Errors should be empty for a valid struct array field.');
        end

        function testEmptyStruct(testCase)
            % Test with an empty structure.
            s = struct();
            [isValid, errors] = ndi.util.isAlphaNumericStruct(s);
            testCase.assertTrue(isValid, 'Empty struct should be considered valid.');
            testCase.assertEmpty(errors, 'Errors should be empty for an empty struct.');
        end

        function testStructWithEmptyStructField(testCase)
            % Test with a field that is an empty struct.
            s = struct('field1', 1, 'emptyNestedStruct', struct());
            [isValid, errors] = ndi.util.isAlphaNumericStruct(s);
            testCase.assertTrue(isValid, 'Struct with an empty nested struct field should be valid.');
            testCase.assertEmpty(errors, 'Errors should be empty.');
        end
        
        function testStructWithEmptyStructArrayField(testCase)
            % Test with a field that is an empty struct array.
            s = struct('field1', 1, 'emptyStructArray', repmat(struct('a',1),0,1) ); % 0x1 struct array
            [isValid, errors] = ndi.util.isAlphaNumericStruct(s);
            testCase.assertTrue(isValid, 'Struct with an empty struct array field should be valid.');
            testCase.assertEmpty(errors, 'Errors should be empty.');
        end


        function testInvalidTypeAtTopLevel(testCase)
            % Test with an invalid type (cell array) at the top level.
            % Corrected definition of s to be a scalar struct
            s = struct('goodField', 123, 'badField', {{1, 2, 3}}); 
            [isValid, errors] = ndi.util.isAlphaNumericStruct(s);
            testCase.assertFalse(isValid, 'Struct with a top-level cell array should be invalid.');
            testCase.assertEqual(numel(errors), 1, 'Should report one error.');
            testCase.assertEqual(errors(1).name, 'badField', 'Error name mismatch.');
            testCase.assertEqual(errors(1).msg, 'type cell', 'Error message mismatch.');
        end

        function testInvalidTypeInNestedStruct(testCase)
            % Test with an invalid type (table) inside a nested scalar structure.
            s = struct();
            s.level1_ok = 'good';
            s.level1_nest.level2_ok = 123;
            s.level1_nest.level2_bad = table([1;2], 'VariableNames', {'Var1'});
            [isValid, errors] = ndi.util.isAlphaNumericStruct(s);
            testCase.assertFalse(isValid, 'Struct with a table in a nested struct should be invalid.');
            testCase.assertEqual(numel(errors), 1, 'Should report one error.');
            testCase.assertEqual(errors(1).name, 'level1_nest.level2_bad', 'Error name mismatch for nested field.');
            testCase.assertEqual(errors(1).msg, 'type table', 'Error message mismatch for table type.');
        end

        function testInvalidTypeInStructArrayField(testCase)
            % Test with an invalid type (cell array) within an element of a struct array field.
            s = struct();
            s.struct_array(1).good_field = 'text_ok';
            s.struct_array(1).another_good = 10;
            s.struct_array(2).good_field = 'more_text_ok';
            s.struct_array(2).bad_field_in_array = { pi }; % Invalid cell
            s.struct_array(3).good_field = 'last_one_ok';

            [isValid, errors] = ndi.util.isAlphaNumericStruct(s);
            testCase.assertFalse(isValid, 'Struct with a cell in a struct array field should be invalid.');
            
            testCase.assertEqual(numel(errors), 1, 'Should report one error for cell in struct array.');
            testCase.assertEqual(errors(1).name, 'struct_array(2).bad_field_in_array', 'Error name mismatch for field in struct array.');
            testCase.assertEqual(errors(1).msg, 'type cell', 'Error message mismatch for cell type in struct array.');
        end
        
        function testMultipleErrors(testCase)
            % Test with multiple invalid types at different locations.
            s = struct();
            s.topLevelBad = {{magic(2)}}; % Corrected to ensure scalar struct with cell field
            s.nestedStruct.level2_good = 'fine';
            s.nestedStruct.level2_bad = @disp; % Error 2 (function handle)
            s.structArray(1).item = 'ok';
            s.structArray(2).item_bad = table(1); % Error 3
            s.anotherTopLevelGood = 123;

            [isValid, errors] = ndi.util.isAlphaNumericStruct(s);
            testCase.assertFalse(isValid, 'Struct with multiple errors should be invalid.');
            testCase.assertEqual(numel(errors), 3, 'Should report three errors.');

            % Check first error
            testCase.assertEqual(errors(1).name, 'topLevelBad', 'Error 1 name mismatch.');
            testCase.assertEqual(errors(1).msg, 'type cell', 'Error 1 message mismatch.');

            % Check second error
            testCase.assertEqual(errors(2).name, 'nestedStruct.level2_bad', 'Error 2 name mismatch.');
            testCase.assertEqual(errors(2).msg, 'type function_handle', 'Error 2 message mismatch.');
            
            % Check third error
            testCase.assertEqual(errors(3).name, 'structArray(2).item_bad', 'Error 3 name mismatch.');
            testCase.assertEqual(errors(3).msg, 'type table', 'Error 3 message mismatch.');
        end

        function testComplexNestingValid(testCase)
            % Test a more complex but still valid structure.
            s = struct();
            s.a = 1;
            s.b.c = 'text';
            s.b.d(1).e = 100;
            s.b.d(1).f = 'f1';
            s.b.d(2).e = 200;
            s.b.d(2).f = 'f2';
            s.b.d(2).g.h = 300;
            s.i(1).j = 'j1';
            s.i(2).j = 'j2';

            [isValid, errors] = ndi.util.isAlphaNumericStruct(s);
            testCase.assertTrue(isValid, 'Complex validly nested struct should be valid.');
            testCase.assertEmpty(errors, 'Errors should be empty for complex valid struct.');
        end
        
        function testComplexNestingInvalid(testCase)
            % Test a complex structure with an invalid field deep inside.
            s = struct();
            s.a = 1;
            s.b.c = 'text';
            s.b.d(1).e = 100;
            s.b.d(1).f = 'f1';
            s.b.d(2).e = 200;
            s.b.d(2).f = 'f2';
            s.b.d(2).g.h_bad = { 1, 2, 3}; % Invalid cell deep inside
            s.i(1).j = 'j1';
            s.i(2).j = 'j2';

            [isValid, errors] = ndi.util.isAlphaNumericStruct(s);
            testCase.assertFalse(isValid, 'Complex struct with deep invalid field should be invalid.');
            testCase.assertEqual(numel(errors), 1, 'Should report one error.');
            testCase.assertEqual(errors(1).name, 'b.d(2).g.h_bad', 'Error name mismatch for deep field.');
            testCase.assertEqual(errors(1).msg, 'type cell', 'Error message mismatch for deep cell.');
        end

    end
end
