classdef datasetBinaryDocCloseTests < matlab.unittest.TestCase
%DATASETBINARYDOCCLOSETESTS Cover the #509 fix in ndi.dataset.
%
%   Before #509 was fixed, ndi.dataset/database_closebinarydoc always
%   dispatched to ndi_dataset_obj.session (the dataset's internal
%   session), even for binarydocs the open path had routed to a linked
%   session. That mismatch leaked the DID lock on the linked session's
%   store. These tests exercise the open->close round-trip through the
%   dataset for a doc that lives in a linked session, and pin the
%   invariant that the close returns cleanly and does not leave a
%   dangling entry in the dataset's owning-session map.

    properties
        TempRoot char
        Dataset
        MemberSession
        TestDoc
        FileSlot char = 'filename1.ext'
    end

    methods (TestMethodSetup)
        function setup(testCase)
            testCase.TempRoot = tempname;
            mkdir(testCase.TempRoot);

            % Dataset + a linked (not ingested) member session -- the
            % configuration that triggers the pre-#509 buggy close path.
            memberDir = fullfile(testCase.TempRoot, 'member');
            mkdir(memberDir);
            testCase.MemberSession = ndi.session.dir('member_ref', memberDir);

            testCase.Dataset = ndi.dataset.dir('ds_close_test', ...
                testCase.TempRoot);
            testCase.Dataset.add_linked_session(testCase.MemberSession);

            % One document with one binary payload, owned by the member
            % session. `+ newdocument()` picks up the correct session_id.
            payloadPath = fullfile(testCase.TempRoot, 'payload.bin');
            fid = fopen(payloadPath, 'w');
            fwrite(fid, uint8([1 2 3 4 5]), 'uint8');
            fclose(fid);

            doc = ndi.document('demoNDI', 'demoNDI.value', 1);
            doc = doc.add_file(testCase.FileSlot, payloadPath, ...
                'ingest', 1, 'delete_original', 0);
            doc = doc + testCase.MemberSession.newdocument();
            testCase.MemberSession.database_add(doc);
            testCase.TestDoc = doc;
        end
    end

    methods (TestMethodTeardown)
        function teardown(testCase)
            if isfolder(testCase.TempRoot)
                rmdir(testCase.TempRoot, 's');
            end
        end
    end

    methods (Test)

        function testCloseThroughDatasetIsWarningFreeForMemberSessionDoc(testCase)
            % Before #509 fix: close went to the dataset's internal
            % session's driver, which usually did not know the file and
            % either raised or silently no-oped. Now it goes to the
            % member session's driver, which does know it.
            binaryDoc = testCase.Dataset.database_openbinarydoc( ...
                testCase.TestDoc, testCase.FileSlot, 'autoClose', false);
            testCase.assertNotEmpty(binaryDoc);
            testCase.verifyWarningFree(@() ...
                testCase.Dataset.database_closebinarydoc(binaryDoc));
        end

        function testCloseUnregistersFromTheOwningSessionMap(testCase)
            % The dataset records (binarydoc key -> owning session) at
            % open time. After close it must be gone; otherwise the map
            % slowly leaks across a session's lifetime.
            binaryDoc = testCase.Dataset.database_openbinarydoc( ...
                testCase.TestDoc, testCase.FileSlot, 'autoClose', false);
            key = binaryDoc.fullpathfilename;
            m = testCase.getBinaryDocSessions(testCase.Dataset);
            testCase.assertTrue(isKey(m, key), ...
                'open should have recorded the owning session under the binarydoc key.');
            testCase.Dataset.database_closebinarydoc(binaryDoc);
            m = testCase.getBinaryDocSessions(testCase.Dataset);
            testCase.verifyFalse(isKey(m, key), ...
                'close should have removed the binarydoc from the map.');
        end

        function testMemberSessionMapValueIsTheMemberSession(testCase)
            % Pins the routing: the value recorded under the binarydoc's
            % key is the SAME handle as the member session, not the
            % dataset's internal session.
            binaryDoc = testCase.Dataset.database_openbinarydoc( ...
                testCase.TestDoc, testCase.FileSlot, 'autoClose', false);
            cleaner = onCleanup(@() ...
                testCase.Dataset.database_closebinarydoc(binaryDoc)); %#ok<NASGU>
            m = testCase.getBinaryDocSessions(testCase.Dataset);
            key = binaryDoc.fullpathfilename;
            recorded = m(key);
            testCase.verifyTrue(recorded == testCase.MemberSession, ...
                'the recorded session must be the linked member session.');
        end

    end

    methods (Access = private)

        function m = getBinaryDocSessions(testCase, ds) %#ok<INUSD>
            % Reach the protected BinaryDocSessions property via
            % struct(handle) -- this exposes protected values with a
            % single warning we suppress. The property is declared
            % Access = protected on ndi.dataset, and this test class
            % is outside the +ndi.dataset access list.
            warning('off', 'MATLAB:structOnObject');
            cleaner = onCleanup(@() warning('on', 'MATLAB:structOnObject')); %#ok<NASGU>
            s = struct(ds);
            m = s.BinaryDocSessions;
        end

    end
end
