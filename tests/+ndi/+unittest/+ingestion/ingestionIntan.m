classdef ingestionIntan < ndi.unittest.session.buildSession
    methods (Test)
        function testIngestion(testCase)
            % TESTINGESTION - Test ingestion on a copy of the session

            % 1. Get original session path
            S1 = testCase.Session;
            S1_path = S1.path();

            % 2. Create new path for copy
            S2_path = [tempname];

            % 3. Close original session to release locks (important for file copy)
            % We delete the object.
            delete(S1);
            testCase.Session = []; % clear reference

            % 4. Copy session
            copyfile(S1_path, S2_path);

            % 5. Re-open sessions
            % Note: buildSession uses 'exp1' as reference.
            S1 = ndi.session.dir('exp1', S1_path);
            S2 = ndi.session.dir('exp1', S2_path);

            % Restore S1 to testCase.Session for automatic teardown of S1
            testCase.Session = S1;

            % Register S2 cleanup
            testCase.addTeardown(@rmdir, S2_path, 's');

            % 6. Ingest S2
            [b, msg] = S2.ingest();
            testCase.verifyTrue(b, ['Ingestion failed: ' msg]);

            % 7. Compare S1 and S2
            report = ndi.fun.session.diff(S1, S2);

            % We expect differences because S2 was ingested and S1 was not.
            % Specifically, S2 should have more documents (epochs).

            % Verify that we have some differences
            testCase.verifyNotEmpty(report.documentsInBOnly, 'S2 should have new documents after ingestion');

        end
    end
end
