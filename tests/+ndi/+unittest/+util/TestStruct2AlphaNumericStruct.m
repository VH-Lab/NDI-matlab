classdef TestStruct2AlphaNumericStruct < matlab.unittest.TestCase
%TESTSTRUCT2ALPHANUMERICSTRUCT Unit tests for ndi.util.Struct2AlphaNumericStruct.

    methods (Test)

        function testBasicValidTypes(testCase)
            s.num = 123;
            s.char = 'hello';
            s.log = true;
            s.emptyChar = '';
            s.emptyNum = [];

            s_out = ndi.util.Struct2AlphaNumericStruct(s);

            testCase.assertEqual(s_out.num, 123);
            testCase.assertEqual(s_out.char, 'hello');
            testCase.assertEqual(s_out.log, true);
            testCase.assertEqual(s_out.emptyChar, '');
            testCase.assertEqual(s_out.emptyNum, []);
        end

        function testStringConversion(testCase)
            s.strScalar = "scalar string";
            s.strArrayCol = ["string1"; "string2"; "string3"];
            s.strArrayRow = ["alpha", "beta"];
            s.emptyStringScalar = ""; % Scalar empty string
            s.emptyStringArray = strings(0,1); % 0x1 empty string array
            s.stringArrayWithEmpty = ["one", "", "three"];

            s_out = ndi.util.Struct2AlphaNumericStruct(s);

            testCase.assertEqual(s_out.strScalar, 'scalar string');
            testCase.assertTrue(ischar(s_out.strScalar));
            testCase.assertEqual(s_out.strArrayCol, 'string1, string2, string3');
            testCase.assertTrue(ischar(s_out.strArrayCol));
            testCase.assertEqual(s_out.strArrayRow, 'alpha, beta');
            testCase.assertTrue(ischar(s_out.strArrayRow));
            testCase.assertEqual(s_out.emptyStringScalar, ''); % char('') is ''
            testCase.assertTrue(ischar(s_out.emptyStringScalar));
            testCase.assertEqual(s_out.emptyStringArray, ''); % char(strings(0,1)) is ''
            testCase.assertTrue(ischar(s_out.emptyStringArray));
            testCase.assertEqual(s_out.stringArrayWithEmpty, 'one, , three');
            testCase.assertTrue(ischar(s_out.stringArrayWithEmpty));
        end

        function testCellArrayOfStringConversion(testCase)
            s.cellStrRow = {'hello', 'world'};
            s.cellStrCol = {'good'; 'morning'};
            s.cellStrMixed = {'item1', "item2_scalar_string"}; % Mix of char and scalar string
            s.emptyCell = {};
            s.cellWithEmptyChar = {'a', '', 'b'};
            s.cellWithEmptyString = {'c', "", 'd'}; % scalar empty string

            s_out = ndi.util.Struct2AlphaNumericStruct(s);

            testCase.assertEqual(s_out.cellStrRow, 'hello, world');
            testCase.assertTrue(ischar(s_out.cellStrRow));
            testCase.assertEqual(s_out.cellStrCol, 'good, morning');
            testCase.assertTrue(ischar(s_out.cellStrCol));
            testCase.assertEqual(s_out.cellStrMixed, 'item1, item2_scalar_string');
            testCase.assertTrue(ischar(s_out.cellStrMixed));
            testCase.assertEqual(s_out.emptyCell, '');
            testCase.assertTrue(ischar(s_out.emptyCell));
            testCase.assertEqual(s_out.cellWithEmptyChar, 'a, , b');
            testCase.assertTrue(ischar(s_out.cellWithEmptyChar));
            testCase.assertEqual(s_out.cellWithEmptyString, 'c, , d');
            testCase.assertTrue(ischar(s_out.cellWithEmptyString));
        end

        function testNestedStructsValid(testCase)
            s.level1_num = 10;
            s.level1_nest.level2_char = 'nested char';
            s.level1_nest.level2_str = "nested string";
            s.level1_nest.level2_cell = {'cell1', 'cell2'};
            s.level1_nest.deeper_nest.final_val = 99;

            s_out = ndi.util.Struct2AlphaNumericStruct(s);

            testCase.assertEqual(s_out.level1_num, 10);
            testCase.assertEqual(s_out.level1_nest.level2_char, 'nested char');
            testCase.assertEqual(s_out.level1_nest.level2_str, 'nested string');
            testCase.assertTrue(ischar(s_out.level1_nest.level2_str));
            testCase.assertEqual(s_out.level1_nest.level2_cell, 'cell1, cell2');
            testCase.assertTrue(ischar(s_out.level1_nest.level2_cell));
            testCase.assertEqual(s_out.level1_nest.deeper_nest.final_val, 99);
        end

        function testStructArrayFieldValid(testCase)
            s.array(1).fieldA = 'A1';
            s.array(1).fieldB = 101;
            s.array(1).fieldC = {"c1a", "c1b"};
            s.array(2).fieldA = "A2_string";
            s.array(2).fieldB = 202;
            s.array(2).fieldC = {'c2a'};

            s_out = ndi.util.Struct2AlphaNumericStruct(s);

            testCase.assertEqual(s_out.array(1).fieldA, 'A1');
            testCase.assertEqual(s_out.array(1).fieldB, 101);
            testCase.assertEqual(s_out.array(1).fieldC, 'c1a, c1b');
            testCase.assertTrue(ischar(s_out.array(1).fieldC));

            testCase.assertEqual(s_out.array(2).fieldA, 'A2_string');
            testCase.assertTrue(ischar(s_out.array(2).fieldA));
            testCase.assertEqual(s_out.array(2).fieldB, 202);
            testCase.assertEqual(s_out.array(2).fieldC, 'c2a');
            testCase.assertTrue(ischar(s_out.array(2).fieldC));
        end
        
        function testEmptyStructInput(testCase)
            s = struct();
            s_out = ndi.util.Struct2AlphaNumericStruct(s);
            testCase.assertTrue(isstruct(s_out));
            testCase.assertTrue(isempty(fieldnames(s_out)));
        end

        function testStructWithEmptyStructField(testCase)
            s.a = 1;
            s.b = struct(); % Empty struct field
            s_out = ndi.util.Struct2AlphaNumericStruct(s);
            testCase.assertTrue(isstruct(s_out.b));
            testCase.assertTrue(isempty(fieldnames(s_out.b)));
        end

        function testStructWithEmptyStructArrayField(testCase)
            s.a = 1;
            s.b = repmat(struct('x',1), 0, 1); % 0x1 struct array
            s_out = ndi.util.Struct2AlphaNumericStruct(s);
            testCase.assertTrue(isstruct(s_out.b));
            testCase.assertTrue(isempty(s_out.b)); % Empty struct array
        end


        % --- Tests for Invalid Types ---

        function testErrorInvalidCellContent_Numeric(testCase)
            s.badCell = {123, 'text'}; % Contains a number
            testCase.verifyError(@() ndi.util.Struct2AlphaNumericStruct(s), ...
                'ndi:util:Struct2AlphaNumericStruct:InvalidCellContent', ...
                'Cell array contains non-string/char numeric element.');
        end

        function testErrorInvalidCellContent_NestedCell(testCase)
            s.badCell = {{'a'}, 'text'}; % Contains a nested cell
            testCase.verifyError(@() ndi.util.Struct2AlphaNumericStruct(s), ...
                'ndi:util:Struct2AlphaNumericStruct:InvalidCellContent', ...
                'Cell array contains nested cell.');
        end
        
        function testErrorInvalidCellContent_StructInCell(testCase)
            s.badCell = {struct('a',1), 'text'}; % Contains a struct
            testCase.verifyError(@() ndi.util.Struct2AlphaNumericStruct(s), ...
                'ndi:util:Struct2AlphaNumericStruct:InvalidCellContent', ...
                'Cell array contains struct.');
        end

        function testErrorUnsupportedType_Table(testCase)
            s.badTable = table([1;2]);
            testCase.verifyError(@() ndi.util.Struct2AlphaNumericStruct(s), ...
                'ndi:util:Struct2AlphaNumericStruct:UnsupportedType', ...
                'Struct contains a table.');
        end

        function testErrorUnsupportedType_FunctionHandle(testCase)
            s.badFunc = @disp;
            testCase.verifyError(@() ndi.util.Struct2AlphaNumericStruct(s), ...
                'ndi:util:Struct2AlphaNumericStruct:UnsupportedType', ...
                'Struct contains a function handle.');
        end
        
        function testErrorUnsupportedType_CustomObject(testCase)
            % Use a simple timer object as an example of a custom/non-supported object
            s.badObject = timer; 
            try
                ndi.util.Struct2AlphaNumericStruct(s);
                testCase.fail('Function should have thrown an error for timer object.');
            catch ME
                testCase.assertEqual(ME.identifier, 'ndi:util:Struct2AlphaNumericStruct:UnsupportedType');
                testCase.assertTrue(contains(ME.message, 'timer'), ...
                    'Error message should mention the problematic type "timer".');
            end
            % Clean up the timer object if it was created
            if isfield(s, 'badObject') && isa(s.badObject, 'timer') && isvalid(s.badObject)
                delete(s.badObject);
            end
        end

        function testErrorInNestedStruct(testCase)
            s.level1.good = 'ok';
            s.level1.level2.bad = {1, 'mixed'}; % Invalid cell in nested struct
            testCase.verifyError(@() ndi.util.Struct2AlphaNumericStruct(s), ...
                'ndi:util:Struct2AlphaNumericStruct:InvalidCellContent', ...
                'Invalid cell in nested struct should error.');
            
            try
                ndi.util.Struct2AlphaNumericStruct(s);
            catch ME
                testCase.assertTrue(contains(ME.message, 'S_in.level1.level2.bad'), ...
                    'Error message should contain the correct path.');
                testCase.assertTrue(contains(ME.message, 'double'), ...
                    'Error message should mention the problematic type.');
            end
        end

        function testErrorInStructArray(testCase)
            s.array(1).fieldA = 'Good';
            s.array(2).fieldB_bad = table(); % Invalid table in struct array
            testCase.verifyError(@() ndi.util.Struct2AlphaNumericStruct(s), ...
                'ndi:util:Struct2AlphaNumericStruct:UnsupportedType', ...
                'Invalid type in struct array should error.');
            
            try
                ndi.util.Struct2AlphaNumericStruct(s);
            catch ME
                testCase.assertTrue(contains(ME.message, 'S_in.array(2).fieldB_bad'), ...
                    'Error message should contain the correct path for struct array element.');
                 testCase.assertTrue(contains(ME.message, 'table'), ...
                    'Error message should mention the problematic type.');
            end
        end
        
        function testPathInErrorMessageForDeeplyNestedError(testCase)
            s.a.b.c.d.e.f_bad = {123}; % Deeply nested error
            try
                ndi.util.Struct2AlphaNumericStruct(s);
                testCase.fail('Function should have thrown an error.');
            catch ME
                testCase.assertEqual(ME.identifier, 'ndi:util:Struct2AlphaNumericStruct:InvalidCellContent');
                testCase.assertTrue(contains(ME.message, 'S_in.a.b.c.d.e.f_bad'), ...
                    'Error message should contain the full path to the deeply nested error.');
            end
        end

    end
end
