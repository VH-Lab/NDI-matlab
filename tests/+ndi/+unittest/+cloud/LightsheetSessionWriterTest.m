classdef LightsheetSessionWriterTest < matlab.unittest.TestCase
% LIGHTSHEETSESSIONWRITERTEST - a lightsheet pyramid straight into a cloud session, live.
%
% Setup uploads an ordinary dataset holding one session with one subject
% (no pyramid). The tests then add the blob fixture's pyramid to that
% session with ndi.cloud.upload.SessionWriter -- nothing local in between
% -- and check what the real server makes of it:
%
%   - the session is found among the dataset's sessions, and the dataset's
%     own id is refused as a target (a pyramid goes to a session);
%   - the session's subject is listed, and is what the pyramid depends on;
%   - every chunk file is recorded uploaded with the CRC-32 of the bytes
%     an ordinary local ingest of the same store writes;
%   - a fresh download (SyncFiles=false) has the pyramid in that session,
%     and every chunk read back through it is byte-identical to the local
%     ingest's.
%
% The offline counterparts (SessionWriterMockTest, TestFromOMEZarrToCloud)
% cover the failure paths a live server cannot be made to produce.
%
% Authored without a local MATLAB runtime; needs MATLAB to validate/run.

    properties (Constant)
        DatasetNamePrefix = 'NDI_UNITTEST_LIGHTSHEET_WRITER_';
    end

    properties
        DatasetID (1,1) string = missing
        LocalDataset
        SessionId char = ''
        SubjectId char = ''
        ZarrPath char = ''
    end

    methods (TestClassSetup)
        function checkCredentials(testCase)
            diagMsg = ['Missing NDI Cloud credentials ' ...
                '(NDI_CLOUD_USERNAME/NDI_CLOUD_PASSWORD). Skipping cloud tests.'];
            testCase.assumeNotEmpty(getenv("NDI_CLOUD_USERNAME"), diagMsg);
            testCase.assumeNotEmpty(getenv("NDI_CLOUD_PASSWORD"), diagMsg);
        end

        function checkReader(testCase)
            testCase.assumeNotEmpty(which('ndr.format.omezarr.listPyramids'), ...
                'NDR reader not on path; fromOMEZarr cannot read the fixture.');
        end

        function uploadADatasetWithASessionAndSubject(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            root = testCase.applyFixture(TemporaryFolderFixture).Folder;

            mkdir(fullfile(root, 'session'));
            mkdir(fullfile(root, 'dataset'));
            mkdir(fullfile(root, 'zarr'));
            S = ndi.session.dir('lightsheet_writer', fullfile(root, 'session'));
            sub = ndi.document('subject', 'base.session_id', S.id(), ...
                'subject.local_identifier', 'blob@vhlab');
            S.database_add(sub);
            testCase.SessionId = S.id();
            testCase.SubjectId = sub.id();

            D = ndi.dataset.dir('lightsheet_writer_ds', fullfile(root, 'dataset'));
            D = D.add_ingested_session(S);
            testCase.LocalDataset = D;

            name = testCase.DatasetNamePrefix + string(did.ido.unique_id());
            [ok, cloudId, msg] = ndi.cloud.uploadDataset(D, ...
                'uploadAsNew', true, 'skipMetadataEditorMetadata', true, ...
                'remoteDatasetName', char(name), ...
                'organizationID', ndi.unittest.cloud.testOrganizationID());
            if ~isempty(cloudId)
                testCase.DatasetID = string(cloudId);
                testCase.addTeardown(@() ndi.cloud.api.datasets.deleteDataset( ...
                    testCase.DatasetID, 'when', 'now'));
            end
            testCase.assertTrue(logical(ok), "Uploading the starting dataset failed: " + string(msg));
            ndi.cloud.api.files.waitForAllBulkUploads(testCase.DatasetID);

            testCase.ZarrPath = ndi.test.lightsheet.makeBlobFixture( ...
                fullfile(root, 'zarr'), 'Shape', [32 32 32], 'NumChannels', 1, ...
                'NumLevels', 2, 'ChunkShape', [16 16 16]);
        end
    end

    methods (Test)

        function testTheSessionIsATargetAndTheDatasetIsNot(testCase)
            sessions = ndi.cloud.upload.SessionWriter.listSessions(char(testCase.DatasetID));
            testCase.verifyTrue(any(strcmp({sessions.session_id}, testCase.SessionId)), ...
                'the uploaded session must be listed among the dataset''s sessions');
            testCase.verifyError(@() ndi.cloud.upload.SessionWriter( ...
                char(testCase.DatasetID), testCase.LocalDataset.id(), 'Verbose', false), ...
                'NDI:cloud:SessionWriter:noSuchSession', ...
                'the dataset''s own session is not a place to put a pyramid');
        end

        function testTheSessionsSubjectIsListed(testCase)
            subjects = ndi.cloud.upload.SessionWriter.listSubjects( ...
                char(testCase.DatasetID), testCase.SessionId);
            testCase.verifyEqual({subjects.id}, {testCase.SubjectId});
            testCase.verifyEqual({subjects.local_identifier}, {'blob@vhlab'});
        end

        function testTheBlobReadsBackIdenticalFromTheSession(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture

            W = ndi.cloud.upload.SessionWriter(char(testCase.DatasetID), testCase.SessionId);
            [P, L, info] = ndi.fun.doc.lightsheet.fromOMEZarr(W, testCase.ZarrPath, ...
                'subjectID', testCase.SubjectId, 'progressFcn', [], ...
                'numWorkers', 0, 'codec', 'blosc-zstd', 'chunks', [8 8 8]);
            testCase.verifyEqual(info.cloud.documents, 2 + numel(L), ...
                'source fileReference + pyramid + one document per level');

            % The reference: the same store ingested into a local session.
            refRoot = testCase.applyFixture(TemporaryFolderFixture).Folder;
            R = ndi.session.dir('reference', refRoot);
            rsub = ndi.document('subject', 'base.session_id', R.id(), ...
                'subject.local_identifier', 'blob@vhlab');
            R.database_add(rsub);
            [~, Lref] = ndi.fun.doc.lightsheet.fromOMEZarr(R, testCase.ZarrPath, ...
                'subjectID', rsub.id(), 'progressFcn', [], 'numWorkers', 0, ...
                'codec', 'blosc-zstd', 'chunks', [8 8 8], 'materializeChunks', true);

            % What the server recorded for every member.
            for k = 1:numel(L)
                ref = matchingLevel(L{k}, Lref);
                members = L{k}.document_properties.files.series_info(1).ingest_locations;
                [ok, answer] = ndi.cloud.api.files.lookupFiles( ...
                    testCase.DatasetID, string({members.uid}));
                testCase.assertTrue(ok, 'lookupFiles failed');
                testCase.verifyEmpty(answer.missing, 'every chunk must be in the cloud');
                for m = 1:numel(members)
                    row = answer.files(strcmp({answer.files.uid}, members(m).uid));
                    testCase.assertNumElements(row, 1);
                    testCase.verifyTrue(row.uploaded);
                    f = R.database_openbinarydoc(ref, sprintf('chunk.bin_%d', members(m).index));
                    expectedCrc = ndi.fun.file.crc32(f.fullpathfilename);
                    R.database_closebinarydoc(f);
                    if ~isempty(row.crc32)
                        testCase.verifyEqual(char(row.crc32), expectedCrc, ...
                            sprintf('chunk %d of level %d', members(m).index, ...
                                L{k}.document_properties.lightsheetZarrLevel.level));
                    end
                end
            end

            % A fresh download: the pyramid is in the session, and reads back.
            downloadDir = testCase.applyFixture(TemporaryFolderFixture).Folder;
            Ddown = ndi.cloud.downloadDataset(testCase.DatasetID, downloadDir, ...
                'SyncFiles', false, 'Verbose', false);
            testCase.assertNotEmpty(Ddown, 'downloadDataset returned nothing');
            Sdown = Ddown.open_session(testCase.SessionId);
            pyr = Sdown.database_search(ndi.query('base.id', 'exact_string', P.id()));
            testCase.assertNumElements(pyr, 1, 'the pyramid must be in the chosen session');
            testCase.verifyEqual(pyr{1}.dependency_value('subject_id'), testCase.SubjectId);
            levels = Sdown.database_search(ndi.query('', 'depends_on', ...
                'lightsheetZarrPyramid_id', P.id()));
            testCase.assertNumElements(levels, numel(L));

            nCompared = 0;
            for k = 1:numel(levels)
                ref = matchingLevel(levels{k}, Lref);
                lv = levels{k}.document_properties.lightsheetZarrLevel;
                for i = 1:prod(double(lv.chunk_grid))
                    name = sprintf('chunk.bin_%d', i);
                    f = Sdown.database_openbinarydoc(levels{k}, name);
                    got = readBytes(f.fullpathfilename);
                    Sdown.database_closebinarydoc(f);
                    f = R.database_openbinarydoc(ref, name);
                    expected = readBytes(f.fullpathfilename);
                    R.database_closebinarydoc(f);
                    testCase.verifyEqual(got, expected, sprintf( ...
                        '%s of level %d (%s) differs after the round trip', ...
                        name, lv.level, lv.reduction_function));
                    nCompared = nCompared + 1;
                end
            end
            testCase.verifyGreaterThan(nCompared, 8);
        end
    end
end

function ref = matchingLevel(doc, refDocs)
% The reference level with the same level index and reduction.
    lp = doc.document_properties.lightsheetZarrLevel;
    hit = cellfun(@(x) ...
        x.document_properties.lightsheetZarrLevel.level == lp.level && ...
        strcmp(x.document_properties.lightsheetZarrLevel.reduction_function, ...
            lp.reduction_function), refDocs);
    assert(nnz(hit) == 1, 'no single reference level %d (%s)', ...
        lp.level, lp.reduction_function);
    ref = refDocs{hit};
end

function b = readBytes(p)
    fid = fopen(p, 'r');
    b = fread(fid, Inf, '*uint8');
    fclose(fid);
end
