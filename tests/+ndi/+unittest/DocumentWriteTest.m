classdef DocumentWriteTest < matlab.unittest.TestCase
    properties
        TempDir
    end

    methods (TestMethodSetup)
        function setup(testCase)
            testCase.TempDir = [tempname];
            mkdir(testCase.TempDir);
        end
    end

    methods (TestMethodTeardown)
        function teardown(testCase)
            rmdir(testCase.TempDir, 's');
        end
    end

    methods (Test)
        function testWriteJSON(testCase)
            % Create a document
            d = ndi.document('base');
            d = d.setproperties('base.name', 'test_doc');

            outputPrefix = fullfile(testCase.TempDir, 'test_output');
            d.write(outputPrefix);

            testCase.assertTrue(isfile([outputPrefix '.json']));

            % Read back and verify
            fid = fopen([outputPrefix '.json'], 'r');
            jsonStr = fread(fid, '*char')';
            fclose(fid);

            data = jsondecode(jsonStr'); % Transpose to make it row vector if needed
            testCase.verifyEqual(data.base.name, 'test_doc');
        end

        function testWriteLocalFiles(testCase)
            % Create a dummy file
            dummyFile = fullfile(testCase.TempDir, 'dummy.txt');
            fid = fopen(dummyFile, 'w');
            fprintf(fid, 'Hello World');
            fclose(fid);

            % Create doc and add file
            d = ndi.document('base');
            d = d.add_file('myfile.txt', dummyFile);

            outputPrefix = fullfile(testCase.TempDir, 'test_output_local');

            % Write with writeLocalFiles=true
            d.write(outputPrefix, 'writeLocalFiles', true);

            % Check JSON exists
            testCase.assertTrue(isfile([outputPrefix '.json']));

            % Check file copy exists
            targetFile = [outputPrefix '_myfile.txt'];
            testCase.assertTrue(isfile(targetFile));

            fid = fopen(targetFile, 'r');
            content = fread(fid, '*char')';
            fclose(fid);
            testCase.verifyEqual(content', 'Hello World');
        end

        function testWriteSessionFiles(testCase)
            sessionDir = fullfile(testCase.TempDir, 'session_dir');
            mkdir(sessionDir);

            % Initialize session
            S = ndi.session.dir('test_session', sessionDir);

            % Create a dummy file to ingest
            dummyFile = fullfile(testCase.TempDir, 'ingest.txt');
            fid = fopen(dummyFile, 'w');
            fprintf(fid, 'Session Content');
            fclose(fid);

            % Create doc
            d = S.newdocument('base', 'base.name', 'session_doc');
            d = d.add_file('ingest.txt', dummyFile); % Default ingest=1 for local file

            % Add to session database
            S.database_add(d);

            outputPrefix = fullfile(testCase.TempDir, 'test_output_session');

            d.write(outputPrefix, 'writeLocalFiles', true, 'session', S);

            % Check JSON
            testCase.assertTrue(isfile([outputPrefix '.json']));

            % Check file
            targetFile = [outputPrefix '_ingest.txt'];
            testCase.assertTrue(isfile(targetFile));

            fid = fopen(targetFile, 'r');
            content = fread(fid, '*char')';
            fclose(fid);
            testCase.verifyEqual(content', 'Session Content');
        end
    end
end
