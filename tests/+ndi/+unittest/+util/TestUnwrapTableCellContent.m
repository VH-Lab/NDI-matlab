classdef TestUnwrapTableCellContent < matlab.unittest.TestCase
    % TESTUNWRAPTABLECELLCONTENT - Unit tests for the ndi.util.unwrapTableCellContent function.
    %
    % Description:
    %   This class tests the various scenarios for the unwrapTableCellContent utility,
    %   including different data types, levels of cell nesting, and edge cases.
    %

    methods (Test)

        function testNonCellInput(testCase)
            % Test that inputs that are not cells are returned unchanged.
            
            % Numeric
            testCase.verifyEqual(ndi.util.unwrapTableCellContent(42), 42, ...
                'A non-cell numeric value should be returned as is.');
            
            % Char
            testCase.verifyEqual(ndi.util.unwrapTableCellContent('hello'), 'hello', ...
                'A non-cell char value should be returned as is.');
            
            % Logical
            testCase.verifyEqual(ndi.util.unwrapTableCellContent(true), true, ...
                'A non-cell logical value should be returned as is.');
        end

        function testSingleCellUnwrap(testCase)
            % Test unwrapping from a single-level 1x1 cell.
            
            % Numeric
            testCase.verifyEqual(ndi.util.unwrapTableCellContent({42}), 42, ...
                'Failed to unwrap a numeric value from a single cell.');
            
            % Char
            testCase.verifyEqual(ndi.util.unwrapTableCellContent({'hello'}), 'hello', ...
                'Failed to unwrap a char value from a single cell.');
        end

        function testNestedCellUnwrap(testCase)
            % Test unwrapping from multiple levels of nested cells.
            
            deeplyNestedValue = {{{{ 'deep' }}}};
            testCase.verifyEqual(ndi.util.unwrapTableCellContent(deeplyNestedValue), 'deep', ...
                'Failed to unwrap a value from a deeply nested cell.');
                
            deeplyNestedLogical = {{{{{true}}}}};
            testCase.verifyEqual(ndi.util.unwrapTableCellContent(deeplyNestedLogical), true, ...
                'Failed to unwrap a logical from a deeply nested cell.');
        end

        function testStringInputConversion(testCase)
            % Test that MATLAB string inputs are unwrapped and converted to char.
            
            % Non-cell string
            testCase.verifyEqual(ndi.util.unwrapTableCellContent("a string"), 'a string', ...
                'A non-cell string should be converted to char.');
                
            % Cell-wrapped string
            testCase.verifyEqual(ndi.util.unwrapTableCellContent({"a string"}), 'a string', ...
                'A cell-wrapped string should be unwrapped and converted to char.');
                
            % Nested cell-wrapped string
            testCase.verifyEqual(ndi.util.unwrapTableCellContent({{"another string"}}), 'another string', ...
                'A nested cell-wrapped string should be unwrapped and converted to char.');
        end

        function testEmptyCellInput(testCase)
            % Test that an empty cell input results in NaN.
            
            emptyCell = {};
            unwrapped = ndi.util.unwrapTableCellContent(emptyCell);
            testCase.verifyTrue(isnan(unwrapped), ...
                'An empty cell should unwrap to NaN.');
        end

        function testNestedEmptyCellInput(testCase)
            % Test that a nested empty cell also unwraps to NaN.
            
            nestedEmptyCell = {{}};
            unwrapped = ndi.util.unwrapTableCellContent(nestedEmptyCell);
            testCase.verifyTrue(isnan(unwrapped), ...
                'A nested empty cell should unwrap to NaN.');
        end
        
        function testInnermostEmptyCell(testCase)
            % Test that a value nested inside a cell that is itself empty results in NaN
            
            innerEmpty = {{ [] }}; % Note: this is different from {{}}, it contains an empty double
            unwrapped = ndi.util.unwrapTableCellContent(innerEmpty);
            testCase.verifyTrue(isnan(unwrapped), ...
                'A cell containing an empty value should unwrap to NaN.');
        end

        function testNaNInput(testCase)
            % Test that a cell containing NaN unwraps correctly.
            
            nanCell = {NaN};
            unwrapped = ndi.util.unwrapTableCellContent(nanCell);
            testCase.verifyTrue(isnan(unwrapped), ...
                'A cell containing NaN should unwrap to NaN.');
                
            nestedNaNCeil = {{{NaN}}};
            unwrappedNested = ndi.util.unwrapTableCellContent(nestedNaNCeil);
            testCase.verifyTrue(isnan(unwrappedNested), ...
                'A nested cell containing NaN should unwrap to NaN.');
        end
        
        function testEmptyStringAndChar(testCase)
            % Test behavior with empty strings and chars
            
            emptyCharCell = {{''}};
            testCase.verifyEqual(ndi.util.unwrapTableCellContent(emptyCharCell), '', ...
                'A nested empty char should unwrap to an empty char.');

            emptyStringCell = {{""}};
            testCase.verifyEqual(ndi.util.unwrapTableCellContent(emptyStringCell), '', ...
                'A nested empty string should unwrap to an empty char.');
        end

    end
end
