classdef TestSeriesWithCloudOnlyManifestResolvesThroughHandler < matlab.unittest.TestCase
% A file series document downloaded with SyncFiles=false lands with its
% manifest's file_info entry naming an ndic:// address only -- ingest=0,
% location_type='ndicloud', no manifest bytes anywhere on this machine.
% Opening a member must offer the manifest's location to the
% customFileHandler with the manifest's own uid in the context, land the
% bytes at <filecachepath>/<manifestUid>, and go on to read the member.
% A second member open on the same series pays no network for the
% manifest again.
%
% This suite runs offline. The customFileHandler is a uid-keyed mock;
% the real ndic:// handler is exercised in
% ndi.unittest.cloud.FileSeriesRoundTripTest, which needs NDI Cloud
% credentials and only covers SyncFiles=true (the manifest arrives
% with its bytes). The path DID-matlab#202 opened -- fetching the
% manifest itself through the handler -- has no coverage against a real
% NDI shape until this test. See VH-Lab/NDI-matlab#986.
%
% Why the test uses did.implementations.sqlitedb directly rather than
% ndi.dataset.database_add + database_openbinarydoc: NDI's didsqlite
% hard-codes @download_file_from_cloud as the customFileHandler at both
% add and open time, which is right at runtime and exactly wrong here.
% ndi.session.database is not publicly reachable to swap. So the test
% goes through DID one layer down, still building the document with
% ndi.document and shaping it with ndi.cloud.sync.internal
% .updateFileInfoForRemoteFiles -- the two NDI-side pieces this test
% exists to cover.

    properties (Constant)
        SeriesName = 'chunkdata.bin';
        CloudDatasetId = 'demo-cloud-ds';
        DbFilename = 'cloudonlymanifest.sqlite';
    end

    properties
        WorkDir
        ManifestUid
    end

    methods (TestMethodSetup)
        function setupWorkingFolder(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
            testCase.WorkDir = pwd;
            testCase.ManifestUid = '';
        end
    end

    methods (TestMethodTeardown)
        function closeDatabase(testCase)
            % A test that only reads may leave the mksqlite handle open,
            % which then blocks the working folder fixture's cleanup on
            % Windows.
            try
                mksqlite('close'); %#ok<TRYNC>
            catch
            end

            % Drop the manifest we planted in the shared file cache: it
            % is keyed by a fresh did.ido.unique_id() so a lingering
            % entry is harmless in isolation, but this suite asserts the
            % cache placement itself, and leaving the entry behind would
            % let a broken setup pass on the next run by finding what a
            % previous run wrote. See DID-matlab#173.
            if ~isempty(testCase.ManifestUid)
                cached = fullfile( ...
                    did.common.PathConstants.filecachepath, ...
                    testCase.ManifestUid);
                if isfile(cached)
                    try
                        did.common.getCache().removeFile( ...
                            testCase.ManifestUid);
                    catch
                        try delete(cached); catch, end %#ok<TRYNC>
                    end
                end
            end
        end
    end

    methods (Access = private)
        function [db, doc, memberContents, srcByUid] = buildCloudOnlySeries(testCase)
            % Build a three-member series, then reshape its manifest's
            % file_info into the SyncFiles=false shape via NDI's own
            % helper. Members are ingested locally into the DID FileDir;
            % the manifest is not (ingest=0). Returns the DID database
            % the doc is in, the stored document, the member payloads,
            % and a uid-keyed byte map the mock handler serves from.

            memberDir = fullfile(testCase.WorkDir, 'members');
            mkdir(memberDir);
            memberContents = { uint8(1:8), uint8(11:18), uint8(21:28) };
            memberPaths = cell(1, numel(memberContents));
            for i = 1:numel(memberContents)
                memberPaths{i} = fullfile(memberDir, sprintf('m%d.bin', i));
                fid = fopen(memberPaths{i}, 'w');
                fwrite(fid, memberContents{i}, 'uint8');
                fclose(fid);
            end

            sessionId = did.ido.unique_id();
            doc = ndi.document('demoNDISeries', ...
                'base.name', 'cloud_only_series_doc', ...
                'demoNDISeries.value', 1, ...
                'base.session_id', sessionId);
            doc = doc.addFileSeries(testCase.SeriesName, memberPaths, ...
                'deleteOriginal', 0);

            % Save the manifest's bytes (the mock serves them by uid),
            % and grab the manifest's uid before reshaping. The reshape
            % preserves the uid: updateFileInfoForRemoteFiles builds the
            % ndic:// URL out of locations(1).uid.
            fi = doc.document_properties.files.file_info;
            k = find(strcmp({fi.name}, testCase.SeriesName), 1);
            testCase.assertNotEmpty(k, 'no file_info for the manifest');
            manifestPathOnDisk = fi(k).locations(1).location;
            manifestUid = fi(k).locations(1).uid;
            fidM = fopen(manifestPathOnDisk, 'r');
            manifestBytes = fread(fidM, Inf, '*uint8')';
            fclose(fidM);

            % updateFileInfoForRemoteFiles is what SyncFiles=false runs
            % on a downloaded document -- applying it here produces the
            % exact shape without hand-crafting the file_info entry.
            doc = ndi.cloud.sync.internal.updateFileInfoForRemoteFiles( ...
                doc, testCase.CloudDatasetId);

            % Sanity-check: any drift here would make the rest of the
            % test measure something else.
            fi = doc.document_properties.files.file_info;
            testCase.assertEqual(fi(k).locations(1).location_type, 'ndicloud');
            testCase.assertEqual(fi(k).locations(1).ingest, 0);
            testCase.assertEqual(fi(k).locations(1).uid, manifestUid, ...
                'the reshape must preserve the manifest uid');
            testCase.assertEqual(fi(k).locations(1).location, ...
                sprintf('ndic://%s/%s', testCase.CloudDatasetId, manifestUid));

            testCase.ManifestUid = manifestUid;

            % Grab the members' ingest_locations NOW: add_docs strips
            % series_info.ingest_locations at store time by design
            % (stripSeriesIngestLocations), so a doc read back
            % afterwards no longer names the members individually.
            entries = doc.seriesIngestLocations(testCase.SeriesName);

            % Store into a DID database directly (see the class header).
            % The manifest is ingest=0 so no manifest bytes are written
            % at add time; members are file/ingest=1 so they land in
            % FileDir/<uid>. No customFileHandler needed on the add path.
            db = did.implementations.sqlitedb( ...
                fullfile(testCase.WorkDir, testCase.DbFilename));
            db.add_branch('a');
            % Validate=false to keep the test focused: the schema-lookup
            % paths ndi.document validates against are not set up by
            % this suite's isolated working folder, and every question
            % this test asks is about the read path DID-matlab#201 opens,
            % not about NDI's schema validation.
            db.add_docs(doc, 'Validate', false);
            doc = db.get_docs(doc.id());

            % A uid-keyed store: the mock handler serves by context.uid,
            % which is the DID contract for a member fetch (the manifest
            % it addresses names the manifest, and the member's uid
            % arrives in ctx.uid). Include the members too, though they
            % are already local so the mock is never asked for them.
            srcByUid = containers.Map('KeyType', 'char', 'ValueType', 'any');
            srcByUid(manifestUid) = manifestBytes;
            for i = 1:numel(entries)
                fidC = fopen(memberPaths{entries(i).index}, 'r');
                srcByUid(entries(i).uid) = fread(fidC, Inf, '*uint8')';
                fclose(fidC);
            end
        end

        function bytes = readAll(~, binarydoc)
            % Open the DID readonly_fileobj and read every byte back.
            binarydoc.fopen();
            closer = onCleanup(@() binarydoc.fclose()); %#ok<NASGU>
            bytes = uint8(fread(binarydoc, Inf, 'uint8')');
        end
    end

    methods (Test)

        function testTheManifestIsFetchedThroughTheHandler(testCase)
            [db, doc, memberContents, srcByUid] = testCase.buildCloudOnlySeries();

            % Precondition: the manifest is NOT on this machine yet.
            testCase.assertFalse( ...
                isfile(fullfile( ...
                    did.common.PathConstants.filecachepath, ...
                    testCase.ManifestUid)), ...
                'precondition: filecachepath should not carry the manifest yet');

            % The handler is a NESTED function of this test method, not
            % returned from a helper: MATLAB nested functions share the
            % enclosing workspace, so the closure writes into this
            % method's own `calls` cell. Returning `calls` from a helper
            % would hand back a value copy, and the caller's cell would
            % stay empty even as the closure kept updating the copy the
            % helper's workspace retained.
            calls = {};
            function serve(destPath, sourcePath, context)
                thisCall = struct( ...
                    'destPath',   destPath, ...
                    'sourcePath', sourcePath, ...
                    'context',    context);
                calls{end+1} = thisCall;
                if isKey(srcByUid, context.uid)
                    fid = fopen(destPath, 'w');
                    fwrite(fid, srcByUid(context.uid), 'uint8');
                    fclose(fid);
                end
            end

            binarydoc = db.open_doc(doc.id(), ...
                sprintf('%s_%d', testCase.SeriesName, 2), ...
                'customFileHandler', @serve);

            testCase.verifyEqual(testCase.readAll(binarydoc), ...
                memberContents{2}, ...
                'the fetched member did not read back byte-for-byte');

            testCase.assertGreaterThanOrEqual(numel(calls), 1, ...
                'the handler was never asked');
            manifestCall = calls{1};
            testCase.verifyEqual(manifestCall.context.uid, ...
                testCase.ManifestUid, ...
                'the first call must be for the manifest by its own uid');
            testCase.verifyEqual(manifestCall.context.seriesName, '', ...
                'the manifest is an ordinary file of the doc, not a member');
            testCase.verifyEqual(manifestCall.context.mode, 'open');
            testCase.verifyEqual(manifestCall.sourcePath, ...
                sprintf('ndic://%s/%s', ...
                    testCase.CloudDatasetId, testCase.ManifestUid), ...
                'sourcePath is the ndic:// URL the file_info already carried');
        end

        function testTheManifestLandsAtFilecachepath(testCase)
            % The cache placement is the whole point of the lazy fetch:
            % the next series read against the same manifest is a
            % cached_path_for_uid hit and pays no network. Pin that end
            % state.
            [db, doc, ~, srcByUid] = testCase.buildCloudOnlySeries();

            function serve(destPath, ~, context)
                if isKey(srcByUid, context.uid)
                    fid = fopen(destPath, 'w');
                    fwrite(fid, srcByUid(context.uid), 'uint8');
                    fclose(fid);
                end
            end

            db.open_doc(doc.id(), ...
                sprintf('%s_1', testCase.SeriesName), ...
                'customFileHandler', @serve);

            cached = fullfile( ...
                did.common.PathConstants.filecachepath, ...
                testCase.ManifestUid);
            testCase.verifyTrue(isfile(cached), ...
                'the manifest must land at filecachepath/<manifestUid>');
        end

        function testDifferentMembersShareOneManifestFetch(testCase)
            % A 28,000-member level must not turn into 28,000 manifest
            % downloads. Open three different members; the mock is
            % asked for the manifest exactly once across the whole run.
            [db, doc, memberContents, srcByUid] = testCase.buildCloudOnlySeries();

            % Nested-function handler: see testTheManifestIsFetchedThroughTheHandler
            % on why this is defined inside the test method rather than
            % returned from a helper.
            calls = {};
            function serve(destPath, ~, context)
                thisCall = struct('uid', context.uid);
                calls{end+1} = thisCall;
                if isKey(srcByUid, context.uid)
                    fid = fopen(destPath, 'w');
                    fwrite(fid, srcByUid(context.uid), 'uint8');
                    fclose(fid);
                end
            end

            for i = 1:numel(memberContents)
                binarydoc = db.open_doc(doc.id(), ...
                    sprintf('%s_%d', testCase.SeriesName, i), ...
                    'customFileHandler', @serve);
                testCase.verifyEqual(testCase.readAll(binarydoc), ...
                    memberContents{i}, ...
                    sprintf('member %d bytes', i));
            end

            manifestCalls = 0;
            for i = 1:numel(calls)
                if strcmp(calls{i}.uid, testCase.ManifestUid)
                    manifestCalls = manifestCalls + 1;
                end
            end
            testCase.verifyEqual(manifestCalls, 1, ...
                'the manifest fetch must be shared across member opens');
        end

        function testAHandlerThatServesNothingRaisesManifestNotLocal(testCase)
            % Handler-refused case for the manifest: DID reports the
            % member as "not on this machine" through the same
            % DID:SQLITEDB:open shape callers already match on, so an
            % out-of-band failure stays visible.
            [db, doc, ~, ~] = testCase.buildCloudOnlySeries();

            function serveNothing(destPath, sourcePath, context) %#ok<INUSD>
                % write nothing at all
            end

            memberName = sprintf('%s_1', testCase.SeriesName);
            testCase.verifyError( ...
                @() db.open_doc(doc.id(), memberName, ...
                    'customFileHandler', @serveNothing), ...
                'DID:SQLITEDB:open');

            try
                db.open_doc(doc.id(), memberName, ...
                    'customFileHandler', @serveNothing);
                testCase.verifyFail('open_doc should have errored');
            catch err
                testCase.verifySubstring(err.message, ...
                    testCase.SeriesName, ...
                    'the message must name the series');
                testCase.verifySubstring(err.message, ...
                    'not on this machine', ...
                    'the current miss message is what callers pattern-match on');
            end
        end

    end
end
