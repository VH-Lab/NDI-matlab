classdef mustBeCellArrayOfNdiSessionsTest < matlab.unittest.TestCase
    % MUSTBECELLARRAYOFNDISESSIONSTEST - Test for the ndi.validators.mustBeCellArrayOfNdiSessions validator
    %
    % Description:
    %   This test class verifies the functionality of the
    %   ndi.validators.mustBeCellArrayOfNdiSessions function. It checks that the
    %   validator correctly accepts valid inputs and throws appropriate errors
    %   for invalid inputs.
    %

    properties
        testDir
    end

    methods (TestMethodSetup)
        function createTestDir(testCase)
            % Create a temporary directory for session objects
            testCase.testDir = fullfile(tempdir, ['NDISessionTest_' char(java.util.UUID.randomUUID().toString())]);
            if ~exist(testCase.testDir, 'dir')
                mkdir(testCase.testDir);
            end
        end
    end

    methods (TestMethodTeardown)
        function removeTestDir(testCase)
            % Remove the temporary directory
            if exist(testCase.testDir, 'dir')
                rmdir(testCase.testDir, 's');
            end
        end
    end

    methods (Test)

        function testValidInput(testCase)
            % Test that a valid cell array of ndi.session.dir objects passes
            mkdir(fullfile(testCase.testDir, 'sess1'));
            mkdir(fullfile(testCase.testDir, 'sess2'));
            S1 = ndi.session.dir('ref1', fullfile(testCase.testDir, 'sess1'));
            S2 = ndi.session.dir('ref2', fullfile(testCase.testDir, 'sess2'));
            validInput = {S1, S2};
            
            % This should execute without error
            testCase.verifyWarningFree(@() ndi.validators.mustBeCellArrayOfNdiSessions(validInput));
        end

        function testEmptyCellArray(testCase)
            % Test that an empty cell array is considered valid
            emptyCell = {};
            
            % This should execute without error
            testCase.verifyWarningFree(@() ndi.validators.mustBeCellArrayOfNdiSessions(emptyCell));
        end

        function testNonCellInput(testCase)
            % Test that a non-cell array input throws an error
            notACell = 'this is not a cell array';
            
            % Verify that the function throws the correct error
            testCase.verifyError(@() ndi.validators.mustBeCellArrayOfNdiSessions(notACell), ...
                'ndi:validators:mustBeCellArrayOfNdiSessions:InputNotCell');
        end

        function testCellWithInvalidContent(testCase)
            % Test that a cell array containing non-ndi.session.dir objects throws an error
            mkdir(fullfile(testCase.testDir, 'sess1'));
            S1 = ndi.session.dir('ref1', fullfile(testCase.testDir, 'sess1'));
            invalidContent = {S1, 'not_a_session_object', 123};
            
            % Verify that the function throws the correct error
            testCase.verifyError(@() ndi.validators.mustBeCellArrayOfNdiSessions(invalidContent), ...
                'ndi:validators:mustBeCellArrayOfNdiSessions:InvalidCellContent');
        end
        
        function testCellWithSomeInvalidContent(testCase)
            % Test that a cell array with a mix of valid and invalid objects throws an error
            mkdir(fullfile(testCase.testDir, 'sess1'));
            S1 = ndi.session.dir('ref1', fullfile(testCase.testDir, 'sess1'));
            mixedContent = {S1, struct('field', 'value')};
            
            % Verify that the function throws the correct error
            testCase.verifyError(@() ndi.validators.mustBeCellArrayOfNdiSessions(mixedContent), ...
                'ndi:validators:mustBeCellArrayOfNdiSessions:InvalidCellContent');
        end

    end
end
