classdef TestRehydrateJSONNanNull < matlab.unittest.TestCase
    % TESTREHYDRATEJSONNANNULL - Unit tests for the ndi.util.rehydrateJSONNanNull function.
    %
    %   Run with: 
    %   results = runtests('ndi.unittest.util.TestRehydrateJSONNanNull')
    %
    
    methods (Test)

        function testDefaultReplacements(testCase)
            % Test basic, default replacements
            json_in = '{"value1":"__NDI__NaN__","value2":"__NDI__Infinity__","value3":"__NDI__-Infinity__"}';
            expected_out = '{"value1":NaN,"value2":Infinity,"value3":-Infinity}';
            
            actual_out = ndi.util.rehydrateJSONNanNull(json_in);
            
            testCase.verifyEqual(actual_out, expected_out, ...
                'Default strings were not replaced correctly.');
        end

        function testMultipleOccurrences(testCase)
            % Test multiple replacements in a single string
            json_in = '["__NDI__NaN__", "__NDI__Infinity__", "__NDI__NaN__", "__NDI__-Infinity__"]';
            expected_out = '[NaN, Infinity, NaN, -Infinity]';

            actual_out = ndi.util.rehydrateJSONNanNull(json_in);

            testCase.verifyEqual(actual_out, expected_out, ...
                'Multiple occurrences were not handled correctly.');
        end

        function testContextVariations(testCase)
            % Test different contexts (end of line, followed by comma, etc.)
            json_in = sprintf('{"a":"__NDI__NaN__",\n"b":"__NDI__Infinity__"}');
            expected_out = sprintf('{"a":NaN,\n"b":Infinity}');

            actual_out = ndi.util.rehydrateJSONNanNull(json_in);

            testCase.verifyEqual(actual_out, expected_out, ...
                'Replacements with different contexts (e.g., newline) failed.');
        end
        
        function testCustomStrings(testCase)
            % Test the ability to specify custom search strings
            json_in = '{"val1":"S_NAN", "val2":"S_INF", "val3":"S_NINF"}';
            expected_out = '{"val1":NaN, "val2":Infinity, "val3":-Infinity}';
            
            actual_out = ndi.util.rehydrateJSONNanNull(json_in, ...
                'nan_string', '"S_NAN"', ...
                'inf_string', '"S_INF"', ...
                'ninf_string', '"S_NINF"');
                
            testCase.verifyEqual(actual_out, expected_out, ...
                'Custom string replacements failed.');
        end

        function testPartialCustomStrings(testCase)
            % Test overriding only one of the custom strings
            json_in = '{"val1":"MY_NAN", "val2":"__NDI__Infinity__"}';
            expected_out = '{"val1":NaN, "val2":Infinity}';

            actual_out = ndi.util.rehydrateJSONNanNull(json_in, 'nan_string', '"MY_NAN"');

            testCase.verifyEqual(actual_out, expected_out, ...
                'Partially overriding custom strings failed.');
        end

        function testNoReplacement(testCase)
            % Test that a string without any special values is unchanged
            json_in = '{"a": 1, "b": "hello", "c": [1,2,3]}';
            
            actual_out = ndi.util.rehydrateJSONNanNull(json_in);
            
            testCase.verifyEqual(actual_out, json_in, ...
                'Function incorrectly modified a string with no special values.');
        end

        function testNoPartialMatches(testCase)
            % Test that substrings are not incorrectly matched
            json_in = '{"a": "__NDI__NaN___but_not_really", "b": "__NDI__NaN__"}';
            expected_out = '{"a": "__NDI__NaN___but_not_really", "b": NaN}';

            actual_out = ndi.util.rehydrateJSONNanNull(json_in);

            testCase.verifyEqual(actual_out, expected_out, ...
                'Function incorrectly matched a partial string.');
        end

        function testEmptyInput(testCase)
            % Test that an empty input string is handled gracefully
            json_in = '';
            expected_out = '';
            
            actual_out = ndi.util.rehydrateJSONNanNull(json_in);
            
            testCase.verifyEqual(actual_out, expected_out, ...
                'Empty input string was not handled correctly.');
        end

    end
end

