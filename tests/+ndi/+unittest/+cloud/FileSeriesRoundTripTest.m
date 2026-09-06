classdef FileSeriesRoundTripTest < matlab.unittest.TestCase
% FILESERIESROUNDTRIPTEST - a file series through the cloud and back.
%
% Builds a demoNDISeries document with a manifest and several chunk members,
% uploads it, and reads it back. This is the acceptance test for the file
% series work tracked in VH-Lab/DID-matlab#173.
%
% It does not pass yet, and is written so that it reports Incomplete rather
% than Failed until each piece lands. Three things are outstanding, and the
% assumptions below name them individually so the reason a run skipped is the
% reason, not a guess:
%
%   1. ndi.document has no series methods. It re-implements DID's file API
%      (add_file, is_in_file_list, current_file_list, remove_file,
%      reset_file_info) rather than inheriting it, so did.document gaining
%      addFileSeries in VH-Lab/DID-matlab#178 does not give ndi.document one.
%   2. Member ingestion is deferred: addFileSeries records where members are
%      but nothing yet copies them into FileDir/<uid> or gives them rows in
%      the files table, so there is nothing to upload for a member.
%   3. ndi-cloud-node does not enumerate series members when signing URLs.
%
% The manifest half of the round trip is testable ahead of (2) and (3),
% because the manifest is an ordinary document file and travels like one.

    properties (Constant)
        DatasetNamePrefix = 'NDI_UNITTEST_FILE_SERIES_';
        MemberCount = 4;
    end

    properties
        DatasetID (1,1) string = missing
        LocalDataset
        MemberPaths (1,:) cell = {}
        MemberContent (1,:) cell = {}
        SeriesDocId (1,1) string = missing
    end

    methods (TestClassSetup)
        function checkCredentials(testCase)
            username = getenv("NDI_CLOUD_USERNAME");
            password = getenv("NDI_CLOUD_PASSWORD");
            diagMsg = ['Missing NDI Cloud credentials ' ...
                '(NDI_CLOUD_USERNAME/NDI_CLOUD_PASSWORD). Skipping cloud tests.'];
            testCase.assumeNotEmpty(username, diagMsg);
            testCase.assumeNotEmpty(password, diagMsg);
        end

        function checkSeriesSupport(testCase)
            % Named separately from the credential check so a skipped run says
            % which of the two reasons applied.
            testCase.assumeTrue(...
                any(strcmp(methods('ndi.document'), 'addFileSeries')), ...
                ['ndi.document has no addFileSeries yet. It re-implements ' ...
                 'DID''s file API rather than inheriting it, so the series ' ...
                 'methods have to be mirrored onto it. See VH-Lab/DID-matlab#173.']);
        end
    end

    methods (TestMethodSetup)
        function setupLocalDatasetAndCloud(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            tempFolder = testCase.applyFixture(TemporaryFolderFixture);
            testCase.LocalDataset = ndi.dataset.dir('test_series_ds', tempFolder.Folder);

            % Members with distinguishable content, so a read-back that
            % returned the right count but the wrong bytes still fails.
            memberDir = fullfile(tempFolder.Folder, 'level0');
            mkdir(memberDir);
            for i = 1:testCase.MemberCount
                content = uint8(mod((1:64) * i, 251));
                p = fullfile(memberDir, sprintf('chunk_%04d.bin', i));
                fid = fopen(p, 'w');
                fwrite(fid, content, 'uint8');
                fclose(fid);
                testCase.MemberPaths{i} = p;
                testCase.MemberContent{i} = content;
            end

            doc = ndi.document('demoNDISeries', ...
                'base.name', 'test_series_doc', ...
                'demoNDISeries.value', 1, ...
                'base.session_id', testCase.LocalDataset.id());
            doc = doc.addFileSeries('chunkdata.bin', testCase.MemberPaths);
            testCase.LocalDataset.database_add(doc);
            testCase.SeriesDocId = doc.id();

            unique_name = testCase.DatasetNamePrefix + string(did.ido.unique_id());
            [b, cloudId] = ndi.cloud.api.datasets.createDataset(struct("name", unique_name));
            testCase.fatalAssertTrue(b, "Failed to create cloud dataset.");
            testCase.DatasetID = cloudId;

            remoteDoc = ndi.cloud.internal.createRemoteDatasetDoc(cloudId, testCase.LocalDataset);
            testCase.LocalDataset.database_add(remoteDoc);

            successUpload = ndi.cloud.uploadDataset(testCase.LocalDataset);
            testCase.fatalAssertTrue(successUpload, "Failed to upload test dataset.");

            % Server-side zip extraction has to finish before anything reads
            % the per-file objects back (issue #755).
            ndi.cloud.api.files.waitForAllBulkUploads(testCase.DatasetID);

            testCase.addTeardown(@() testCase.cleanupCloudDataset());
        end
    end

    methods (Access = private)
        function cleanupCloudDataset(testCase)
            if ~ismissing(testCase.DatasetID)
                ndi.cloud.api.datasets.deleteDataset(testCase.DatasetID, 'when', 'now');
            end
        end
    end

    methods (Test)

        function testManifestSurvivesTheRoundTrip(testCase)
            % The manifest is an ordinary document file, so this half works
            % before member ingestion and before the server knows about series.
            q = ndi.query('base.name', 'exact_string', 'test_series_doc');
            docs = testCase.LocalDataset.database_search(q);
            testCase.fatalAssertNumElements(docs, 1);

            fobj = testCase.LocalDataset.database_openbinarydoc(docs{1}, 'chunkdata.bin');
            manifestPath = fobj.fullpathfilename;
            m = did.file.readSeriesManifest(manifestPath);
            testCase.LocalDataset.database_closebinarydoc(fobj);

            testCase.verifyEqual(m.count, testCase.MemberCount);
            for i = 1:testCase.MemberCount
                testCase.verifyNotEmpty(m.uids{i}, ...
                    sprintf('member %d should have a uid in the manifest', i));
            end
        end

        function testDocumentReportsItsSeries(testCase)
            q = ndi.query('base.name', 'exact_string', 'test_series_doc');
            docs = testCase.LocalDataset.database_search(q);
            testCase.fatalAssertNumElements(docs, 1);
            doc = docs{1};

            testCase.verifyTrue(doc.isFileSeries('chunkdata.bin'));
            [n, nPresent] = doc.seriesCount('chunkdata.bin');
            testCase.verifyEqual(n, testCase.MemberCount);
            testCase.verifyEqual(nPresent, testCase.MemberCount);
        end

        function testCurrentFileListDoesNotExpandTheSeries(testCase)
            % A 28,000-member series must not materialise 28,000 names here --
            % that is the bloat the manifest exists to remove, reappearing one
            % layer up. Called out in VH-Lab/DID-matlab#173.
            q = ndi.query('base.name', 'exact_string', 'test_series_doc');
            docs = testCase.LocalDataset.database_search(q);
            fl = docs{1}.current_file_list();

            testCase.verifyTrue(ismember('chunkdata.bin', fl), ...
                'the manifest itself is an ordinary file and should be listed');
            testCase.verifyFalse(ismember('chunkdata.bin_1', fl), ...
                'members must not be expanded into the file list');
        end

        function testMembersSurviveTheRoundTrip(testCase)
            % The whole point. Needs member ingestion (DID) and series-aware
            % URL signing (ndi-cloud-node); until both land this skips rather
            % than fails, and becomes live on its own once they do.
            q = ndi.query('base.name', 'exact_string', 'test_series_doc');
            docs = testCase.LocalDataset.database_search(q);
            doc = docs{1};

            testCase.assumeTrue(...
                testCase.LocalDataset.database_existbinarydoc(doc.id(), 'chunkdata.bin_1'), ...
                ['Series members are not ingested yet: addFileSeries records ' ...
                 'where they are, but nothing copies them into FileDir/<uid> ' ...
                 'or gives them a files-table row. See VH-Lab/DID-matlab#173.']);

            for i = 1:testCase.MemberCount
                memberName = sprintf('chunkdata.bin_%d', i);
                fobj = testCase.LocalDataset.database_openbinarydoc(doc, memberName);
                fid = fopen(fobj.fullpathfilename, 'rb');
                got = fread(fid, inf, '*uint8')';
                fclose(fid);
                testCase.LocalDataset.database_closebinarydoc(fobj);

                testCase.verifyEqual(got, testCase.MemberContent{i}, ...
                    sprintf('member %d came back with different bytes', i));
            end
        end
    end
end
