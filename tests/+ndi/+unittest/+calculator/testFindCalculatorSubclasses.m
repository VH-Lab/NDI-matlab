classdef testFindCalculatorSubclasses < matlab.unittest.TestCase

    methods (Test)
        function testReturnsNonEmpty(testCase)
            % The repo has known calculator subclasses, so result should not be empty
            result = ndi.calculator.find_calculator_subclasses('ClearCache', true);
            testCase.verifyNotEmpty(result, ...
                'find_calculator_subclasses should return at least one subclass');
        end

        function testKnownSubclassesPresent(testCase)
            % Verify known calculator subclasses are found
            result = ndi.calculator.find_calculator_subclasses('ClearCache', true);
            testCase.verifyTrue(ismember("ndi.calc.example.simple", result), ...
                'ndi.calc.example.simple should be found as a calculator subclass');
        end

        function testAllResultsAreCalculatorSubclasses(testCase)
            % Every returned class should actually be a subclass of ndi.calculator
            result = ndi.calculator.find_calculator_subclasses('ClearCache', true);
            for i = 1:numel(result)
                mc = meta.class.fromName(result(i));
                testCase.verifyNotEmpty(mc, ...
                    sprintf('%s should be a valid class', result(i)));
                testCase.verifyTrue(isSubclassOf(mc, 'ndi.calculator'), ...
                    sprintf('%s should be a subclass of ndi.calculator', result(i)));
            end
        end

        function testCachingWorks(testCase)
            % First call with cache cleared, second call should use cache
            result1 = ndi.calculator.find_calculator_subclasses('ClearCache', true);
            result2 = ndi.calculator.find_calculator_subclasses();
            testCase.verifyEqual(result1, result2, ...
                'Cached result should match fresh result');
        end

        function testClearCacheDoesNotError(testCase)
            % Calling with UseCache=false should not error
            testCase.verifyWarningFree( ...
                @() ndi.calculator.find_calculator_subclasses('ClearCache', true));
        end
    end
end

function tf = isSubclassOf(mc, parentName)
    % Check if meta.class mc inherits from parentName
    tf = false;
    if strcmp(mc.Name, parentName)
        tf = true;
        return;
    end
    for i = 1:numel(mc.SuperclassList)
        if isSubclassOf(mc.SuperclassList(i), parentName)
            tf = true;
            return;
        end
    end
end
