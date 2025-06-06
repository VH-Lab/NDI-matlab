% TestAuthorDigitalIdentifier.m
classdef TestAuthorDigitalIdentifier < matlab.unittest.TestCase
    %TESTAUTHORDIGITALIDENTIFIER Unit tests for the AuthorDigitalIdentifier class.

    properties
        AuthorIdClassName = 'ndi.gui.component.metadataEditor.class.AuthorDigitalIdentifier'
    end

    methods (Test)
        function testDefaultInitialization(testCase)
            authorId = feval(testCase.AuthorIdClassName);
            testCase.verifyClass(authorId, testCase.AuthorIdClassName);
            testCase.verifyEqual(authorId.identifier, char.empty(1,0));
            testCase.verifyEqual(authorId.type, char.empty(1,0));
            testCase.verifyEqual(authorId.CellStrDelimiter, ', ');
        end

        function testPropertyAssignmentValid(testCase)
            authorId = feval(testCase.AuthorIdClassName);
            
            authorId.identifier = '0000-0002-1825-0097';
            testCase.verifyEqual(authorId.identifier, '0000-0002-1825-0097');

            authorId.type = 'ORCID';
            testCase.verifyEqual(authorId.type, 'ORCID');
        end

        function testPropertyValidationTypeInvalid(testCase)
            authorId = feval(testCase.AuthorIdClassName);
            try
                authorId.type = 'INVALIDTYPE';
                testCase.fail('An error was expected but not thrown.');
            catch ME
                testCase.verifyEqual(ME.identifier, 'MATLAB:validators:mustBeMember');
            end
        end
        
        function testToStruct(testCase)
            authorId = feval(testCase.AuthorIdClassName);
            authorId.identifier = 'id1';
            authorId.type = 'ORCID';
            s = authorId.toStruct();
            
            testCase.verifyTrue(isstruct(s));
            testCase.verifyEqual(s.identifier, 'id1');
            testCase.verifyEqual(s.type, 'ORCID');
            testCase.verifyEqual(s.CellStrDelimiter, ', ');
        end

        % --- Tests for static fromStruct (inherited) ---
        function testFromStructValid(testCase)
            s.identifier = 'structId';
            s.type = 'ORCID';
            s.CellStrDelimiter = ';';
            authorId = ndi.util.StructSerializable.fromStruct(testCase.AuthorIdClassName, s, false);
            testCase.verifyClass(authorId, testCase.AuthorIdClassName);
            testCase.verifyEqual(authorId.identifier, s.identifier);
            testCase.verifyEqual(authorId.type, s.type);
            testCase.verifyEqual(authorId.CellStrDelimiter, ';');
        end

        function testFromStructMissingFieldRequired(testCase)
            s.type = 'ORCID'; 
            s.CellStrDelimiter = ', ';
            testCase.verifyError(@() ndi.util.StructSerializable.fromStruct(testCase.AuthorIdClassName, s, true), ...
                'ndi:validators:mustHaveFields:MissingField');
        end
        
        % --- Tests for static fromAlphaNumericStruct ---
        function testFromAlphaNumericStructValidScalar(testCase)
            alphaS.identifier = 'alphaId1';
            alphaS.type = 'orcid'; % test normalization
            alphaS.CellStrDelimiter = '|';
            
            f = str2func([testCase.AuthorIdClassName '.fromAlphaNumericStruct']);
            authorId = f(alphaS);
            
            testCase.verifyClass(authorId, testCase.AuthorIdClassName);
            testCase.verifyEqual(authorId.identifier, alphaS.identifier);
            testCase.verifyEqual(authorId.type, 'ORCID');
            testCase.verifyEqual(authorId.CellStrDelimiter, '|');
        end

        function testFromAlphaNumericStructMissingFieldRequired(testCase)
            alphaS.type = 'ORCID';
            alphaS.CellStrDelimiter = ', ';
            
            f = str2func([testCase.AuthorIdClassName '.fromAlphaNumericStruct']);
            testCase.verifyError(@() f(alphaS, 'errorIfFieldNotPresent', true), 'ndi:validators:mustHaveFields:MissingField');
        end
        
        function testFromAlphaNumericStructExtraField(testCase)
            alphaS.identifier = 'id';
            alphaS.type = 'ORCID';
            alphaS.CellStrDelimiter = ', ';
            alphaS.extraData = 123;
            
            f = str2func([testCase.AuthorIdClassName '.fromAlphaNumericStruct']);
            testCase.verifyError(@() f(alphaS), 'ndi:validators:mustHaveOnlyFields:ExtraField');
        end
    end
end