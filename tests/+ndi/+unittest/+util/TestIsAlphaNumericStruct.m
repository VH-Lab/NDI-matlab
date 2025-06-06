classdef TestIsAlphaNumericStruct < matlab.unittest.TestCase
%TESTISALPHANUMERICSTRUCT Unit tests for the ndi.util.isAlphaNumericStruct function.

    methods (Test)
        % --- Tests for Scalar Struct Inputs (from previous version) ---
        function testValidFlatStruct(testCase)
            s = struct('field1', 10, 'field2', 'hello', 'field3', [1 2 3]);
            [isValid, errors] = ndi.util.isAlphaNumericStruct(s);
            testCase.assertTrue(isValid, 'Flat struct with valid types should be valid.');
            testCase.assertEmpty(errors, 'Errors should be empty for a valid flat struct.');
        end
        function testValidNestedScalarStruct(testCase)
            s = struct();
            s.level1_num = 10;
            s.level1_nest = struct('level2_num', 20);
            [isValid, errors] = ndi.util.isAlphaNumericStruct(s);
            testCase.assertTrue(isValid, 'Struct with valid nested scalar struct should be valid.');
            testCase.assertEmpty(errors, 'Errors should be empty for a valid nested struct.');
        end
        function testValidStructArrayField(testCase)
            s = struct();
            s.struct_array_field(1).item = 'item1_text';
            s.struct_array_field(2).value = 202;
            [isValid, errors] = ndi.util.isAlphaNumericStruct(s);
            testCase.assertTrue(isValid, 'Struct with valid struct array field should be valid.');
            testCase.assertEmpty(errors, 'Errors should be empty for a valid struct array field.');
        end
        function testEmptyStruct(testCase)
            s = struct();
            [isValid, errors] = ndi.util.isAlphaNumericStruct(s);
            testCase.assertTrue(isValid, 'Empty struct should be considered valid.');
            testCase.assertEmpty(errors, 'Errors should be empty for an empty struct.');
        end
        function testInvalidTypeInNestedStruct(testCase)
            s = struct();
            s.level1_nest.level2_bad = table([1;2]);
            [isValid, errors] = ndi.util.isAlphaNumericStruct(s);
            testCase.assertFalse(isValid, 'Struct with a table in a nested struct should be invalid.');
            testCase.assertEqual(errors(1).name, 'level1_nest.level2_bad');
        end
        function testInvalidTypeInStructArrayField(testCase)
            s = struct();
            s.struct_array(1).good_field = 'text_ok';
            s.struct_array(2).bad_field_in_array = { pi }; % Invalid cell
            [isValid, errors] = ndi.util.isAlphaNumericStruct(s);
            testCase.assertFalse(isValid, 'Struct with a cell in a struct array field should be invalid.');
            testCase.assertEqual(errors(1).name, 'struct_array(2).bad_field_in_array');
        end

        % --- NEW TESTS for Non-Scalar Struct Array Inputs ---
        function testValidNonScalarInput(testCase)
            % Test a valid 1x3 struct array.
            s(1).name = 'A';
            s(1).value = 1;
            s(2).name = 'B';
            s(2).value = 2;
            s(3).name = 'C';
            s(3).value = 3;
            [isValid, errors] = ndi.util.isAlphaNumericStruct(s);
            testCase.assertTrue(isValid, 'A valid non-scalar struct array should be valid.');
            testCase.assertEmpty(errors, 'Errors should be empty for a valid struct array input.');
        end
        
        function testInvalidNonScalarInput(testCase)
            % Test a 1x2 struct array where the second element is invalid.
            s(1).name = 'good';
            s(2).name = 'bad';
            s(2).badField = {1,2,3}; % Invalid type
            [isValid, errors] = ndi.util.isAlphaNumericStruct(s);
            testCase.assertFalse(isValid, 'A non-scalar struct array with an invalid element should be invalid.');
            testCase.assertEqual(numel(errors), 1, 'Should report one error for invalid non-scalar input.');
            testCase.assertEqual(errors(1).name, '(2).badField', 'Error path should correctly index the non-scalar input.');
            testCase.assertEqual(errors(1).msg, 'type cell', 'Error message mismatch.');
        end

        function testEmptyStructArrayInput(testCase)
            % Test an empty (0x1) struct array with defined fields.
            s = struct('name', {}, 'value', {});
            [isValid, errors] = ndi.util.isAlphaNumericStruct(s);
            testCase.assertTrue(isValid, 'An empty struct array should be considered valid.');
            testCase.assertEmpty(errors, 'Errors should be empty for an empty struct array input.');
        end
        
        function testMultiDimensionalValidInput(testCase)
            % Test a valid 2x2 struct array.
            s(1,1).value = 11;
            s(1,2).value = 12;
            s(2,1).value = 21;
            s(2,2).value = 22;
            [isValid, errors] = ndi.util.isAlphaNumericStruct(s);
            testCase.assertTrue(isValid, 'A valid multi-dimensional struct array should be valid.');
            testCase.assertEmpty(errors, 'Errors should be empty for a valid multi-dimensional input.');
        end

        function testMultiDimensionalInvalidInput(testCase)
            % Test a 2x2 struct array with an invalid field.
            s(1,1).value = 11;
            s(1,2).value = {12}; % Invalid type
            s(2,1).value = 21;
            s(2,2).value = 22;
            [isValid, errors] = ndi.util.isAlphaNumericStruct(s);
            testCase.assertFalse(isValid, 'A multi-dimensional struct array with an invalid element should be invalid.');
            testCase.assertEqual(numel(errors), 1, 'Should report one error for multi-dimensional input.');
            % s(1,2) is the 2nd element in column-major linear indexing.
            % With the improved pathing, this should now be '(1,2)'.
            testCase.assertEqual(errors(1).name, '(1,2).value', 'Error path should use multi-dimensional index.');
            testCase.assertEqual(errors(1).msg, 'type cell', 'Error message mismatch.');
        end
    end
end