classdef FileSeriesRoundTripTest < matlab.unittest.TestCase
% FILESERIESROUNDTRIPTEST - a file series through the cloud and back.
%
% Builds a demoNDISeries document with a manifest and several chunk members,
% uploads it, and reads it back. This is the acceptance test for the file
% series work tracked in VH-Lab/DID-matlab#173.
%
% It is written so that what cannot work yet reports Incomplete rather than
% Failed, and so that a skip names its own reason rather than leaving it to be
% guessed. Of the three things that were outstanding when it was written:
%
%   1. DONE. ndi.document had no series methods -- it re-implemented DID's
%      file API rather than inheriting it, so did.document gaining
%      addFileSeries in VH-Lab/DID-matlab#178 gave ndi.document nothing.
%      VH-Lab/NDI-matlab#940 made it a subclass, and the class-level
%      assumption below now opens.
%   2. DONE. Member ingestion landed in VH-Lab/DID-matlab#183: members are
%      copied into FileDir/<uid> and NAME_<i> resolves through the manifest,
%      so a member now has bytes to upload. testMembersAreIngestedLocally
%      checks that and no longer skips.
%   3. HALF DONE, and it turned out not to need series awareness. A member
%      is signed by uid like any other file once something names it, which
%      VH-Lab/NDI-matlab#961 taught ndi.database.internal.list_binary_files
%      to do for the UPLOAD -- proven, since members demonstrably reach the
%      cloud now. The DOWNLOAD direction is unproven, and cannot be proven
%      here yet: nothing has ever asked the cloud for a member's bytes, so
%      no member uid has been through batchSignedUrlLookup on the way back.
%      testMembersSurviveADownloadFromTheCloud is what will exercise it, and
%      is blocked behind the read-side gap below. Do not read this item as
%      "signing works"; read it as "signing has no reason to care, and the
%      return half is untested".
%
% What remains is on the READ side: VH-Lab/DID-matlab#188. A series member
% carries no location of its own, so a dataset freshly downloaded from the
% cloud cannot fetch one. It has the manifest, and the manifest names its
% members by uid, but nothing asks the caller's handler for those bytes --
% did.implementations.sqlitedb.seriesMemberPath resolves the manifest, looks
% the member up in the local cache, and reports a miss. The ndic:// locations
% that ndi.cloud.sync.internal.reconstructSeriesIngestLocations builds do not
% help here: they carry ingest = 0 (members stay on the cloud until wanted,
% deliberately), and do_add_doc strips them before storing anyway, so by open
% time the manifest is all there is to go on.
%
% READ THE TEST NAMES CAREFULLY, because most of them do less than they sound
% like. testManifestSurvivesTheRoundTrip, testDocumentReportsItsSeries,
% testCurrentFileListDoesNotExpandTheSeries and testMembersAreIngestedLocally
% all upload and then assert against LocalDataset, which is never
% re-downloaded -- they check the same bytes setup wrote to disk, which no
% transfer can corrupt, and so establish only that the cloud ACCEPTS a
% document carrying a series. Only the two ...FromTheCloud tests read anything
% back out. See VH-Lab/NDI-matlab#966 for how a suite of five green tests
% managed to prove nothing about a member's bytes.

    properties (Constant)
        DatasetNamePrefix = 'NDI_UNITTEST_FILE_SERIES_';
        MemberCount = 4;
    end

    properties
        % Every cloud test in this suite carries a narrative, so a failure
        % reads as a sequence of steps and a structured JSON report rather
        % than a bare number. The audience for these failures is often not a
        % MATLAB user -- NDI-matlab#945 is being handed to whoever maintains
        % ndi-cloud-node -- and "0 where 4 was expected" is not something they
        % can act on. See ndi.unittest.cloud.APIMessage.
        Narrative (1,:) string
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

            narrative = "Begin FileSeriesRoundTripTest setup.";
            narrative(end+1) = "Creating a local dataset and " + ...
                testCase.MemberCount + " series members on disk.";

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
            narrative(end+1) = "Added document 'test_series_doc' (id " + ...
                string(doc.id()) + ") with file series 'chunkdata.bin' " + ...
                "declaring " + testCase.MemberCount + " members.";

            unique_name = testCase.DatasetNamePrefix + string(did.ido.unique_id());
            narrative(end+1) = "Creating cloud dataset named " + unique_name + ".";
            [b, cloudId] = ndi.cloud.api.datasets.createDataset(struct("name", unique_name));
            msg = ndi.unittest.cloud.APIMessage(narrative, b, cloudId, ...
                matlab.net.http.ResponseMessage.empty, "datasets.createDataset");
            testCase.assertTrue(b, "Failed to create cloud dataset. " + msg);
            testCase.DatasetID = cloudId;
            narrative(end+1) = "Cloud dataset id is " + string(cloudId) + ".";

            remoteDoc = ndi.cloud.internal.createRemoteDatasetDoc(cloudId, testCase.LocalDataset);
            testCase.LocalDataset.database_add(remoteDoc);

            narrative(end+1) = "Uploading the dataset (documents are batched " + ...
                "as one JSON array by zip_documents_for_upload).";
            successUpload = ndi.cloud.uploadDataset(testCase.LocalDataset);
            msg = ndi.unittest.cloud.APIMessage(narrative, successUpload, ...
                successUpload, matlab.net.http.ResponseMessage.empty, ...
                "ndi.cloud.uploadDataset");
            testCase.assertTrue(successUpload, ...
                "Failed to upload test dataset. " + msg);

            % Server-side zip extraction has to finish before anything reads
            % the per-file objects back (issue #755).
            narrative(end+1) = "Waiting for server-side bulk upload extraction to finish.";
            ndi.cloud.api.files.waitForAllBulkUploads(testCase.DatasetID);
            narrative(end+1) = "Setup complete; the series is now in the cloud.";

            testCase.Narrative = narrative;
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
            narrative = testCase.Narrative;
            narrative(end+1) = "Begin testManifestSurvivesTheRoundTrip.";
            narrative(end+1) = "NOTE: this test reads the LOCAL dataset, not the cloud. " + ...
                "It shows the upload was accepted, not that anything came back.";

            q = ndi.query('base.name', 'exact_string', 'test_series_doc');
            docs = testCase.LocalDataset.database_search(q);
            testCase.assertNumElements(docs, 1);

            fobj = testCase.LocalDataset.database_openbinarydoc(docs{1}, 'chunkdata.bin');
            manifestPath = fobj.fullpathfilename;
            m = did.file.readSeriesManifest(manifestPath);
            testCase.LocalDataset.database_closebinarydoc(fobj);

            narrative(end+1) = "Read the local manifest; it reports " + m.count + " members.";
            msg = ndi.unittest.cloud.APIMessage(narrative, true, m, ...
                matlab.net.http.ResponseMessage.empty, "local read of chunkdata.bin");

            testCase.verifyEqual(m.count, testCase.MemberCount, ...
                "local manifest member count is wrong. " + msg);
            for i = 1:testCase.MemberCount
                testCase.verifyNotEmpty(m.uids{i}, ...
                    "member " + i + " has no uid in the manifest. " + msg);
            end
            testCase.Narrative = narrative;
        end

        function testDocumentReportsItsSeries(testCase)
            narrative = testCase.Narrative;
            narrative(end+1) = "Begin testDocumentReportsItsSeries.";
            narrative(end+1) = "Reading the LOCAL dataset. This is the control for " + ...
                "NDI-matlab#945: the same query against the DOWNLOADED dataset returns 0.";

            q = ndi.query('base.name', 'exact_string', 'test_series_doc');
            docs = testCase.LocalDataset.database_search(q);
            testCase.assertNumElements(docs, 1);
            doc = docs{1};

            [n, nPresent] = doc.seriesCount('chunkdata.bin');
            narrative(end+1) = "Local document reports count=" + n + ", n_present=" + nPresent + ".";
            msg = ndi.unittest.cloud.APIMessage(narrative, true, ...
                doc.document_properties.files, ...
                matlab.net.http.ResponseMessage.empty, "local database_search");

            testCase.verifyTrue(doc.isFileSeries('chunkdata.bin'), ...
                "local document does not report chunkdata.bin as a series. " + msg);
            testCase.verifyEqual(n, testCase.MemberCount, ...
                "local series count is wrong. " + msg);
            testCase.verifyEqual(nPresent, testCase.MemberCount, ...
                "local series present-count is wrong. " + msg);
            testCase.Narrative = narrative;
        end

        function testCurrentFileListDoesNotExpandTheSeries(testCase)
            % A 28,000-member series must not materialise 28,000 names here --
            % that is the bloat the manifest exists to remove, reappearing one
            % layer up. Called out in VH-Lab/DID-matlab#173.
            narrative = testCase.Narrative;
            narrative(end+1) = "Begin testCurrentFileListDoesNotExpandTheSeries.";

            q = ndi.query('base.name', 'exact_string', 'test_series_doc');
            docs = testCase.LocalDataset.database_search(q);
            fl = docs{1}.current_file_list();
            narrative(end+1) = "current_file_list returned " + numel(fl) + " entries.";
            msg = ndi.unittest.cloud.APIMessage(narrative, true, fl, ...
                matlab.net.http.ResponseMessage.empty, "local current_file_list");

            testCase.verifyTrue(ismember('chunkdata.bin', fl), ...
                "the manifest itself is an ordinary file and should be listed. " + msg);
            testCase.verifyFalse(ismember('chunkdata.bin_1', fl), ...
                "members must not be expanded into the file list. " + msg);
            testCase.Narrative = narrative;
        end

        function testMembersAreIngestedLocally(testCase)
            % Members are copied into FileDir/<uid> and readable back by their
            % NAME_<i> names (VH-Lab/DID-matlab#183). It used to skip on that,
            % since nothing ingested a member; the skip is gone.
            %
            % RENAMED from testMembersSurviveTheRoundTrip, which is what it
            % was called for most of its life and is not what it does: it
            % reads from LocalDataset, never re-downloaded, so the bytes it
            % compares are the ones setup wrote to disk a moment earlier. No
            % transfer happens between the write and the read, so nothing a
            % server did could make this fail. The name is why the suite
            % looked like it covered the cloud round trip for members when
            % nothing did -- see VH-Lab/NDI-matlab#966, and
            % testMembersSurviveADownloadFromTheCloud below for the real one.
            %
            % Still worth keeping. When the round-trip test fails, this one
            % separates "the members were never ingested, so nothing was
            % uploaded" from "they were ingested and something happened in
            % transit", and those have different owners.
            narrative = testCase.Narrative;
            narrative(end+1) = "Begin testMembersAreIngestedLocally.";
            narrative(end+1) = "This is a LOCAL check: it reads back from " + ...
                "LocalDataset, which is never re-downloaded. It says members " + ...
                "were ingested, not that they survived the cloud.";
            testCase.Narrative = narrative;

            q = ndi.query('base.name', 'exact_string', 'test_series_doc');
            docs = testCase.LocalDataset.database_search(q);
            doc = docs{1};

            testCase.assertTrue(...
                testCase.LocalDataset.database_existbinarydoc(doc.id(), 'chunkdata.bin_1'), ...
                ['Series members were not ingested: addFileSeries records ' ...
                 'where they are, and VH-Lab/DID-matlab#183 is meant to copy ' ...
                 'them into FileDir/<uid> and give them a files-table row.']);

            for i = 1:testCase.MemberCount
                memberName = sprintf('chunkdata.bin_%d', i);
                fobj = testCase.LocalDataset.database_openbinarydoc(doc, memberName);
                fid = fopen(fobj.fullpathfilename, 'rb');
                got = fread(fid, inf, '*uint8')';
                fclose(fid);
                testCase.LocalDataset.database_closebinarydoc(fobj);

                testCase.verifyEqual(got, testCase.MemberContent{i}, ...
                    sprintf('member %d was ingested with different bytes', i));
            end
        end

        function testManifestSurvivesADownloadFromTheCloud(testCase)
            % The genuine round trip, and the only test here that reads the
            % series back out of the cloud rather than out of the local
            % dataset it was built in.
            %
            % The three tests above upload and then assert against
            % testCase.LocalDataset, which is never re-downloaded. That
            % establishes the cloud ACCEPTS a document carrying a series
            % manifest, which is worth knowing but is not a round trip: a
            % server that quietly dropped the manifest file, renamed it, or
            % returned different bytes would pass all three.
            %
            % This one downloads the dataset into a fresh folder and reads the
            % manifest from the downloaded copy, so the uids it checks are the
            % ones that actually made the journey. It needs SyncFiles so the
            % file contents come down and not just the document records.
            %
            % This covers the MANIFEST half only, on purpose. The member
            % half is testMembersSurviveADownloadFromTheCloud, below, which
            % shares this test's shape and downloads its own copy. Keeping
            % them apart costs a second download per run and buys a failure
            % that says which half broke: a manifest that arrived intact
            % while its members did not is a different bug from a manifest
            % that came back altered, and the manifest is the half a series
            % reader hits first.

            import matlab.unittest.fixtures.TemporaryFolderFixture

            narrative = testCase.Narrative;
            narrative(end+1) = "Begin testManifestSurvivesADownloadFromTheCloud.";
            narrative(end+1) = "This is the only test here that reads the series back " + ...
                "OUT of the cloud. The three above assert against the local dataset.";

            % The local manifest, to compare against.
            q = ndi.query('base.name', 'exact_string', 'test_series_doc');
            localDocs = testCase.LocalDataset.database_search(q);
            testCase.assertNumElements(localDocs, 1);
            localFobj = testCase.LocalDataset.database_openbinarydoc(localDocs{1}, 'chunkdata.bin');
            localManifest = did.file.readSeriesManifest(localFobj.fullpathfilename);
            testCase.LocalDataset.database_closebinarydoc(localFobj);
            narrative(end+1) = "Local manifest before download: count=" + ...
                localManifest.count + ".";

            % Two steps rather than chaining off applyFixture, matching the
            % setup above; indexing into a method's return value is not
            % something to rely on here.
            downloadFixture = testCase.applyFixture(TemporaryFolderFixture);
            narrative(end+1) = "Downloading dataset " + testCase.DatasetID + ...
                " with SyncFiles=true into a fresh folder.";
            downloaded = ndi.cloud.downloadDataset(testCase.DatasetID, downloadFixture.Folder, ...
                'SyncFiles', true, 'Verbose', false);
            msg = ndi.unittest.cloud.APIMessage(narrative, ~isempty(downloaded), ...
                "downloadDataset returned an ndi.dataset", ...
                matlab.net.http.ResponseMessage.empty, "ndi.cloud.downloadDataset");
            testCase.assertNotEmpty(downloaded, ...
                "downloadDataset returned nothing for the uploaded dataset. " + msg);

            remoteDocs = downloaded.database_search(q);
            narrative(end+1) = "Downloaded dataset returned " + numel(remoteDocs) + ...
                " document(s) matching base.name 'test_series_doc'.";
            msg = ndi.unittest.cloud.APIMessage(narrative, true, numel(remoteDocs), ...
                matlab.net.http.ResponseMessage.empty, "downloaded database_search");
            testCase.assertNumElements(remoteDocs, 1, ...
                "the series document did not come back from the cloud. " + msg);
            remoteDoc = remoteDocs{1};

            % On failure, show what actually came back rather than just the
            % number that did not match: whether series_info still has its
            % count and n_present fields, what else survived beside them, and
            % whether ingest_locations came back as [] or as a struct. That is
            % the difference between the server dropping fields and the JSON
            % round trip reshaping them. See VH-Lab/NDI-matlab#945, and
            % ndi.unittest.database.TestDocumentSeriesJsonRoundTrip for the
            % no-network half of the same question.
            testCase.onFailure(@() disp(remoteDoc.document_properties.files));

            [n, nPresent] = remoteDoc.seriesCount('chunkdata.bin');
            hasSeriesInfo = isfield(remoteDoc.document_properties.files, 'series_info') && ...
                ~isempty(remoteDoc.document_properties.files.series_info);
            narrative(end+1) = "Downloaded document: files.series_info present = " + ...
                string(hasSeriesInfo) + ", seriesCount reports count=" + n + ...
                ", n_present=" + nPresent + " (expected " + testCase.MemberCount + ").";
            narrative(end+1) = "If series_info is absent, the server dropped the whole " + ...
                "per-series record; if present with zeros, it kept the entry and zeroed " + ...
                "the numbers. seriesCount returns 0/0 for BOTH, which is why the struct " + ...
                "is reported below. See VH-Lab/NDI-matlab#945.";
            narrative(end+1) = "Note isFileSeries reads files.file_series (the CLASS " + ...
                "declaration, from the schema), not files.series_info, so it can pass " + ...
                "while the instance record is gone.";
            msg = ndi.unittest.cloud.APIMessage(narrative, true, ...
                remoteDoc.document_properties.files, ...
                matlab.net.http.ResponseMessage.empty, "downloaded document files struct");

            % The series declaration has to survive serialization, not just
            % the bytes of the manifest.
            testCase.verifyTrue(remoteDoc.isFileSeries('chunkdata.bin'), ...
                "the downloaded document no longer reports chunkdata.bin as a series. " + msg);
            testCase.verifyEqual(n, testCase.MemberCount, ...
                "downloaded series declares a different member count. " + msg);
            testCase.verifyEqual(nPresent, testCase.MemberCount, ...
                "downloaded series lost members from its manifest slots. " + msg);

            % And the members must still not be expanded into the file list
            % on the far side -- the bloat this design exists to avoid would
            % otherwise reappear on every reader that downloads a dataset.
            fl = remoteDoc.current_file_list();
            testCase.verifyTrue(ismember('chunkdata.bin', fl));
            testCase.verifyFalse(ismember('chunkdata.bin_1', fl), ...
                'members were expanded into the downloaded file list');

            % The manifest bytes themselves.
            remoteFobj = downloaded.database_openbinarydoc(remoteDoc, 'chunkdata.bin');
            remoteManifest = did.file.readSeriesManifest(remoteFobj.fullpathfilename);
            downloaded.database_closebinarydoc(remoteFobj);

            narrative(end+1) = "Downloaded manifest reports count=" + remoteManifest.count + ".";
            msg = ndi.unittest.cloud.APIMessage(narrative, true, remoteManifest, ...
                matlab.net.http.ResponseMessage.empty, "downloaded chunkdata.bin manifest");

            testCase.verifyEqual(remoteManifest.count, testCase.MemberCount, ...
                "downloaded manifest reports a different member count. " + msg);
            testCase.verifyEqual(remoteManifest.uids, localManifest.uids, ...
                "downloaded manifest uids differ from the ones uploaded; " + ...
                "a member would resolve to the wrong file. " + msg);
            testCase.Narrative = narrative;
        end

        function testMembersSurviveADownloadFromTheCloud(testCase)
            % THE acceptance test for the file series cloud path: the only
            % thing anywhere that proves a member's BYTES made the journey.
            % See VH-Lab/NDI-matlab#966 for why the suite was green without
            % it -- every other test either reads from LocalDataset, which no
            % transfer touches, or checks the manifest, which is an ordinary
            % document file. A server that accepted the member uploads and
            % then dropped, truncated or swapped their bytes passes all of
            % them.
            %
            % EXPECTED TO FAIL until VH-Lab/DID-matlab#188 lands, at the
            % member reachability assertion below. A member carries no
            % location of its own, so seriesMemberPath resolves the manifest,
            % looks the member up in the local cache and returns a miss --
            % which is the state of a dataset that has just been downloaded.
            % #188 adds the retrieval: the customFileHandler is called for the
            % member in 'open' mode, given the series manifest's location and
            % the member's uid. That failure is the evidence for #188, so do
            % not skip or delete this test to make CI green.
            %
            % If it still fails AFTER #188 lands, the next suspect is the
            % return half of class header item 3: a member uid has never been
            % through batchSignedUrlLookup on the way back, because nothing
            % has ever asked the cloud for a member's bytes. This test is the
            % first thing that will. Read the per-member diagnostic below
            % before assuming which of the two it is.

            import matlab.unittest.fixtures.TemporaryFolderFixture

            narrative = testCase.Narrative;
            narrative(end+1) = "Begin testMembersSurviveADownloadFromTheCloud.";
            narrative(end+1) = "Reading each member's bytes from the DOWNLOADED " + ...
                "copy, not from the local dataset they were written into.";

            downloadFixture = testCase.applyFixture(TemporaryFolderFixture);
            narrative(end+1) = "Downloading dataset " + testCase.DatasetID + ...
                " with SyncFiles=true into a fresh folder.";
            downloaded = ndi.cloud.downloadDataset(testCase.DatasetID, downloadFixture.Folder, ...
                'SyncFiles', true, 'Verbose', false);
            msg = ndi.unittest.cloud.APIMessage(narrative, ~isempty(downloaded), ...
                "downloadDataset returned an ndi.dataset", ...
                matlab.net.http.ResponseMessage.empty, "ndi.cloud.downloadDataset");
            testCase.assertNotEmpty(downloaded, ...
                "downloadDataset returned nothing for the uploaded dataset. " + msg);

            q = ndi.query('base.name', 'exact_string', 'test_series_doc');
            remoteDocs = downloaded.database_search(q);
            msg = ndi.unittest.cloud.APIMessage(narrative, true, numel(remoteDocs), ...
                matlab.net.http.ResponseMessage.empty, "downloaded database_search");
            testCase.assertNumElements(remoteDocs, 1, ...
                "the series document did not come back from the cloud. " + msg);
            remoteDoc = remoteDocs{1};

            % Reachability first, and slot by slot rather than in bulk. WHICH
            % slots arrived separates "the members never uploaded" from "the
            % members are on the cloud but cannot be reached from here", and
            % those are different bugs with different owners: none reachable
            % is DID-matlab#188, some reachable is a transfer that lost
            % members and is NDI's.
            present = false(1, testCase.MemberCount);
            for i = 1:testCase.MemberCount
                present(i) = downloaded.database_existbinarydoc(remoteDoc.id(), ...
                    sprintf('chunkdata.bin_%d', i));
            end
            narrative(end+1) = "Members reachable in the downloaded dataset: " + ...
                sum(present) + " of " + testCase.MemberCount + ", slots " + ...
                mat2str(find(present)) + ".";
            narrative(end+1) = "NONE reachable is VH-Lab/DID-matlab#188: a member " + ...
                "has no location of its own, and nothing asks the customFileHandler " + ...
                "for its bytes at open time. SOME reachable is not #188 -- the " + ...
                "transfer lost members, and that is NDI's bug.";
            testCase.Narrative = narrative;
            msg = ndi.unittest.cloud.APIMessage(narrative, all(present), present, ...
                matlab.net.http.ResponseMessage.empty, ...
                "downloaded database_existbinarydoc, per member");

            testCase.assertTrue(all(present), ...
                "a series member of the downloaded dataset could not be reached. " + msg);

            % The bytes, compared in full rather than by length. Setup gives
            % all four members the SAME 64 bytes' length and distinguishes
            % them by content, so a size check here would catch nothing at
            % all: two members swapped by a uid mixup -- the failure this
            % path is most prone to, since a member is addressed by uid the
            % whole way through -- come back the right size and the wrong
            % file.
            for i = 1:testCase.MemberCount
                memberName = sprintf('chunkdata.bin_%d', i);
                fobj = downloaded.database_openbinarydoc(remoteDoc, memberName);
                fid = fopen(fobj.fullpathfilename, 'rb');
                got = fread(fid, inf, '*uint8')';
                fclose(fid);
                downloaded.database_closebinarydoc(fobj);

                testCase.verifyEqual(got, testCase.MemberContent{i}, ...
                    sprintf(['member %d came back from the cloud with ' ...
                             'different bytes than were uploaded'], i));
            end
        end

    end
end
