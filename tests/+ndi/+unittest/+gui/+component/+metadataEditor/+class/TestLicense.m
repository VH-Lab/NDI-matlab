% TestLicense.m
classdef TestLicense < matlab.unittest.TestCase
    %TESTLICENSE Unit tests for the License class.

    properties
        ClassName = 'ndi.gui.component.metadataEditor.class.License'
    end

    methods (Test)
        function testDefaultInitialization(testCase)
            license = feval(testCase.ClassName);
            testCase.verifyClass(license, testCase.ClassName);
            testCase.verifyEqual(license.FullName, char.empty(1,0));
            testCase.verifyEqual(license.LegalCode, char.empty(1,0));
            testCase.verifyEqual(license.ShortName, char.empty(1,0));
        end

        function testPropertyAssignmentValid(testCase)
            license = feval(testCase.ClassName);
            
            % Use hardcoded valid strings for testing
            license.FullName = 'Creative Commons Attribution 4.0 International';
            license.LegalCode = 'https://creativecommons.org/licenses/by/4.0/legalcode';
            license.ShortName = 'CC BY 4.0';

            testCase.verifyEqual(license.FullName, 'Creative Commons Attribution 4.0 International');
            testCase.verifyEqual(license.LegalCode, 'https://creativecommons.org/licenses/by/4.0/legalcode');
            testCase.verifyEqual(license.ShortName, 'CC BY 4.0');
        end
        
        function testPropertyValidationInvalid(testCase)
            license = feval(testCase.ClassName);
            try
                license.ShortName = 'Invalid License Name';
                testCase.fail('An error was expected but not thrown for invalid ShortName.');
            catch ME
                testCase.verifyEqual(ME.identifier, 'MATLAB:validators:mustBeMember');
            end
        end

        function testToStruct(testCase)
            license = feval(testCase.ClassName);
            license.ShortName = 'CC BY-NC 4.0';
            s = license.toStruct();
            
            testCase.verifyTrue(isstruct(s));
            testCase.verifyEqual(s.ShortName, 'CC BY-NC 4.0');
            testCase.verifyEqual(s.FullName, char.empty(1,0));
        end

        % --- Tests for fromStruct and fromAlphaNumericStruct ---
        function testFromStructValid(testCase)
            % Use hardcoded valid strings for testing
            s = struct(...
                'FullName', 'Creative Commons Attribution-ShareAlike 4.0 International', ...
                'LegalCode', 'https://creativecommons.org/licenses/by-sa/4.0/legalcode', ...
                'ShortName', 'CC BY-SA 4.0', ...
                'CellStrDelimiter', ';' ...
            );
            
            license = ndi.util.StructSerializable.fromStruct(testCase.ClassName, s, false);
            testCase.verifyEqual(license.ShortName, 'CC BY-SA 4.0');
            testCase.verifyEqual(license.CellStrDelimiter, ';');
        end

        function testFromAlphaNumericStructValid(testCase)
            % Use hardcoded valid strings for testing
            alphaS = struct(...
                'FullName', 'Creative Commons Attribution-NonCommercial 4.0 International', ...
                'LegalCode', 'https://creativecommons.org/licenses/by-nc/4.0/legalcode', ...
                'ShortName', 'CC BY-NC 4.0', ...
                'CellStrDelimiter', '|' ...
            );
            
            f = str2func([testCase.ClassName '.fromAlphaNumericStruct']);
            license = f(alphaS);
            
            testCase.verifyEqual(license.FullName, 'Creative Commons Attribution-NonCommercial 4.0 International');
            testCase.verifyEqual(license.CellStrDelimiter, '|');
        end

        function testFromAlphaNumericStructMissingRequired(testCase)
            alphaS = struct('FullName', 'Creative Commons Attribution 4.0 International');
            
            f = str2func([testCase.ClassName '.fromAlphaNumericStruct']);
            testCase.verifyError(@() f(alphaS, 'errorIfFieldNotPresent', true), 'ndi:validators:mustHaveFields:MissingFields');
        end
    end
end