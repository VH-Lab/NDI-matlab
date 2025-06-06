% TestStrain.m
classdef TestStrain < matlab.unittest.TestCase
    %TESTSTRAIN Unit tests for the Strain class.

    properties
        StrainClassName = 'ndi.gui.component.metadataEditor.class.Strain'
    end

    methods (Test)
        function testDefaultInitialization(testCase)
            strain = feval(testCase.StrainClassName);
            testCase.verifyClass(strain, testCase.StrainClassName);
            testCase.verifyEqual(strain.Name, char.empty(1,0));
            testCase.verifyEqual(strain.CellStrDelimiter, ', ');
        end

        function testPropertyAssignment(testCase)
            strain = feval(testCase.StrainClassName);
            strain.Name = 'C57BL/6J';
            testCase.verifyEqual(strain.Name, 'C57BL/6J');
        end
        
        function testPropertyValidation(testCase)
            strain = feval(testCase.StrainClassName);
            try
                strain.Name = struct();
                testCase.fail('An error was expected but not thrown.');
            catch ME
                testCase.verifyEqual(ME.identifier, 'MATLAB:validation:UnableToConvert');
            end
        end

        function testToStruct(testCase)
            strain = feval(testCase.StrainClassName);
            strain.Name = 'FVB';
            s = strain.toStruct();
            
            testCase.verifyTrue(isstruct(s));
            testCase.verifyEqual(s.Name, 'FVB');
            testCase.verifyEqual(s.CellStrDelimiter, ', ');
        end

        % --- Tests for static fromStruct (inherited) ---
        function testFromStructValid(testCase)
            s.Name = 'BALB/c';
            s.CellStrDelimiter = ';';
            strain = ndi.util.StructSerializable.fromStruct(testCase.StrainClassName, s, false);
            testCase.verifyClass(strain, testCase.StrainClassName);
            testCase.verifyEqual(strain.Name, s.Name);
            testCase.verifyEqual(strain.CellStrDelimiter, ';');
        end

        function testFromStructMissingFieldRequired(testCase)
            s = struct('CellStrDelimiter', ', '); % Name is missing
            testCase.verifyError(@() ndi.util.StructSerializable.fromStruct(testCase.StrainClassName, s, true), ...
                'ndi:validators:mustHaveFields:MissingField');
        end
        
        % --- Tests for static fromAlphaNumericStruct ---
        function testFromAlphaNumericStructValidScalar(testCase)
            alphaS.Name = '129S1/SvImJ';
            alphaS.CellStrDelimiter = '|';
            
            f = str2func([testCase.StrainClassName '.fromAlphaNumericStruct']);
            strain = f(alphaS);
            
            testCase.verifyClass(strain, testCase.StrainClassName);
            testCase.verifyEqual(strain.Name, alphaS.Name);
            testCase.verifyEqual(strain.CellStrDelimiter, '|');
        end

        function testFromAlphaNumericStructValidArray(testCase)
            alphaS(1,1).Name = 'Strain A'; alphaS(1,1).CellStrDelimiter = ',';
            alphaS(1,2).Name = 'Strain B'; alphaS(1,2).CellStrDelimiter = ';';
            
            f = str2func([testCase.StrainClassName '.fromAlphaNumericStruct']);
            strainArray = f(alphaS);
            
            testCase.verifyClass(strainArray, testCase.StrainClassName);
            testCase.verifySize(strainArray, [1 2]);
            testCase.verifyEqual(strainArray(1,1).Name, 'Strain A');
            testCase.verifyEqual(strainArray(1,2).Name, 'Strain B');
            testCase.verifyEqual(strainArray(1,2).CellStrDelimiter, ';');
        end

        function testFromAlphaNumericStructMissingFieldRequired(testCase)
            alphaS = struct('CellStrDelimiter', ', '); % Name is missing
            
            f = str2func([testCase.StrainClassName '.fromAlphaNumericStruct']);
            testCase.verifyError(@() f(alphaS, 'errorIfFieldNotPresent', true), 'ndi:validators:mustHaveFields:MissingField');
        end
        
        function testFromAlphaNumericStructExtraField(testCase)
            alphaS.Name = 'DBA/2';
            alphaS.CellStrDelimiter = ', ';
            alphaS.extraNotes = 'This should not be here';
            
            f = str2func([testCase.StrainClassName '.fromAlphaNumericStruct']);
            testCase.verifyError(@() f(alphaS), 'ndi:validators:mustHaveOnlyFields:ExtraField');
        end
    end
end