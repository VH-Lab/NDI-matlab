% TestDatasetDetails.m
classdef TestDatasetDetails < matlab.unittest.TestCase
    %TESTDATASETDETAILS Unit tests for the DatasetDetails class.

    properties
        ClassName = 'ndi.gui.component.metadataEditor.class.DatasetDetails'
    end

    methods (Test)
        function testDefaultInitialization(testCase)
            details = feval(testCase.ClassName);
            testCase.verifyClass(details, testCase.ClassName);
            testCase.verifyEqual(details.Description, char.empty(1,0));
            testCase.verifyEqual(details.FullName, char.empty(1,0));
            testCase.verifyEqual(details.ShortName, char.empty(1,0));
            testCase.verifyEqual(details.Comment, char.empty(1,0)); % Added check for Comment
            testCase.verifyEqual(details.CellStrDelimiter, ', ');
        end

        function testPropertyAssignment(testCase)
            details = feval(testCase.ClassName);
            details.FullName = 'My First Neurodata Dataset';
            details.ShortName = 'Neurodata1';
            details.Description = 'An example dataset.';
            details.Comment = 'Internal use only.'; % Added check for Comment
            
            testCase.verifyEqual(details.FullName, 'My First Neurodata Dataset');
            testCase.verifyEqual(details.ShortName, 'Neurodata1');
            testCase.verifyEqual(details.Comment, 'Internal use only.');
        end
        
        function testPropertyValidation(testCase)
            details = feval(testCase.ClassName);
            try
                details.FullName = struct('a',1); % Assign invalid type
                testCase.fail('An error was expected but not thrown.');
            catch ME
                testCase.verifyEqual(ME.identifier, 'MATLAB:validation:UnableToConvert');
            end
        end

        function testToStruct(testCase)
            details = feval(testCase.ClassName);
            details.ShortName = 'DatasetShort';
            details.Comment = 'A comment.';
            s = details.toStruct();
            
            testCase.verifyTrue(isstruct(s));
            testCase.verifyEqual(s.ShortName, 'DatasetShort');
            testCase.verifyEqual(s.Comment, 'A comment.');
            testCase.verifyEqual(s.FullName, char.empty(1,0)); 
        end

        % --- Tests for static fromStruct (inherited) ---
        function testFromStructValid(testCase)
            s = struct(...
                'Description', 'A test dataset.', ...
                'FullName', 'Full Test Dataset Name', ...
                'ShortName', 'TestDS', ...
                'Comment', 'Comment from struct', ... % Added Comment
                'CellStrDelimiter', ';' ...
                );
            
            details = ndi.util.StructSerializable.fromStruct(testCase.ClassName, s, false);
            testCase.verifyClass(details, testCase.ClassName);
            testCase.verifyEqual(details.FullName, 'Full Test Dataset Name');
            testCase.verifyEqual(details.Comment, 'Comment from struct');
            testCase.verifyEqual(details.CellStrDelimiter, ';');
        end

        function testFromStructMissingFieldRequired(testCase)
            s = struct('ShortName', 'Incomplete', 'CellStrDelimiter', ', '); 
            testCase.verifyError(@() ndi.util.StructSerializable.fromStruct(testCase.ClassName, s, true), ...
                'ndi:validators:mustHaveFields:MissingFields');
        end
        
        % --- Tests for static fromAlphaNumericStruct ---
        function testFromAlphaNumericStructValid(testCase)
            alphaS = struct(...
                'Description', 'An alpha test dataset.', ...
                'FullName', 'Full Alpha Test Dataset Name', ...
                'ShortName', 'AlphaTestDS', ...
                'Comment', 'Alpha comment', ... % Added Comment
                'CellStrDelimiter', '|' ...
            );
            
            f = str2func([testCase.ClassName '.fromAlphaNumericStruct']);
            details = f(alphaS);
            
            testCase.verifyEqual(details.FullName, 'Full Alpha Test Dataset Name');
            testCase.verifyEqual(details.Comment, 'Alpha comment');
            testCase.verifyEqual(details.CellStrDelimiter, '|');
        end
        
        function testFromAlphaNumericStructArray(testCase)
            alphaS(1,1).FullName = 'DS_A'; alphaS(1,1).ShortName = 'A'; alphaS(1,1).Description = ''; alphaS(1,1).Comment = 'c_a'; alphaS(1,1).CellStrDelimiter = ',';
            alphaS(1,2).FullName = 'DS_B'; alphaS(1,2).ShortName = 'B'; alphaS(1,2).Description = ''; alphaS(1,2).Comment = 'c_b'; alphaS(1,2).CellStrDelimiter = ';';
            
            f = str2func([testCase.ClassName '.fromAlphaNumericStruct']);
            detailsArray = f(alphaS);
            
            testCase.verifySize(detailsArray, [1 2]);
            testCase.verifyEqual(detailsArray(1,2).ShortName, 'B');
            testCase.verifyEqual(detailsArray(1,2).Comment, 'c_b');
            testCase.verifyEqual(detailsArray(1,2).CellStrDelimiter, ';');
        end

        function testFromAlphaNumericStructMissingRequired(testCase)
            alphaS = struct('ShortName', 'Incomplete', 'CellStrDelimiter', ', ');
            f = str2func([testCase.ClassName '.fromAlphaNumericStruct']);
            testCase.verifyError(@() f(alphaS, 'errorIfFieldNotPresent', true), 'ndi:validators:mustHaveFields:MissingFields');
        end
        
        function testFromAlphaNumericStructExtraField(testCase)
            alphaS = struct(...
                'Description', '', 'FullName', '', 'ShortName', '', 'Comment', '', 'CellStrDelimiter', ',', ...
                'extraField', 'not allowed' ... 
            );
            
            f = str2func([testCase.ClassName '.fromAlphaNumericStruct']);
            testCase.verifyError(@() f(alphaS), 'ndi:validators:mustHaveOnlyFields:ExtraField');
        end
    end
end