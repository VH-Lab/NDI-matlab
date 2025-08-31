classdef TestRehydrateJSONNanNull < matlab.unittest.TestCase
    % TESTREHYDRATEJSONNANNULL - Unit tests for the ndi.util.rehydrateJSONNanNull function.
    %
    %   Run with: 
    %   results = runtests('ndi.unittest.util.TestRehydrateJSONNanNull')
    %
    
    methods (Test)

        function testDefaultReplacements(testCase)
            % Test basic, default replacements
            json_in = '{"value1":"S_NAN","value2":"S_INF","value3":"S_NINF"}';
            expected_out = '{"value1":NaN,"value2":Infinity,"value3":-Infinity}';
            
            actual_out = ndi.util.rehydrateJSONNanNull(json_in);
            
            testCase.verifyEqual(actual_out, expected_out, ...
                'Default strings were not replaced correctly.');
        end

        function testMultipleOccurrences(testCase)
            % Test multiple replacements in a single string
            json_in = '["S_NAN", "S_INF", "S_NAN", "S_NINF"]';
            expected_out = '[NaN, Infinity, NaN, -Infinity]';

            actual_out = ndi.util.rehydrateJSONNanNull(json_in);

            testCase.verifyEqual(actual_out, expected_out, ...
                'Multiple occurrences were not handled correctly.');
        end

        function testContextVariations(testCase)
            % Test different contexts (end of line, followed by comma, etc.)
            json_in = sprintf('{"a":"S_NAN",\n"b":"S_INF"}');
            expected_out = sprintf('{"a":NaN,\n"b":Infinity}');

            actual_out = ndi.util.rehydrateJSONNanNull(json_in);

            testCase.verifyEqual(actual_out, expected_out, ...
                'Replacements with different contexts (e.g., newline) failed.');
        end
        
        function testCustomStrings(testCase)
            % Test the ability to specify custom search strings
            json_in = '{"val1":"MY_NAN", "val2":"YOUR_INF", "val3":"THEIR_NINF"}';
            expected_out = '{"val1":NaN, "val2":Infinity, "val3":-Infinity}';
            
            actual_out = ndi.util.rehydrateJSONNanNull(json_in, ...
                'nan_string', '"MY_NAN"', ...
                'inf_string', '"YOUR_INF"', ...
                'ninf_string', '"THEIR_NINF"');
                
            testCase.verifyEqual(actual_out, expected_out, ...
                'Custom string replacements failed.');
        end

        function testPartialCustomStrings(testCase)
            % Test overriding only one of the custom strings
            json_in = '{"val1":"MY_NAN", "val2":"S_INF"}';
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
            json_in = '{"a": "S_NAN_but_not_really", "b": "S_NAN"}';
            expected_out = '{"a": "S_NAN_but_not_really", "b": NaN}';

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
