classdef TestUpdateFileInfoForRemoteFilesShape < matlab.unittest.TestCase
% Offline coverage for ndi.cloud.sync.internal.updateFileInfoForRemoteFiles.
%
% Covers the shape work and the reconstruction path without touching NDI
% Cloud. The reconstruction path is exercised through the same DID
% customFileHandler contract DID#201 uses on the read side, so a mock
% handler stands in for a real cloud fetch and the two sides share their
% fetcher. The real cloud round trip lives in
% tests/+ndi/+unittest/+cloud/FileSeriesRoundTripTest.

    properties (Constant)
        MemberCount = 3;
    end

    properties
        MemberPaths (1,:) cell = {}
    end

    methods (TestMethodSetup)
        function setupWorkingFolder(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
            testCase.MemberPaths = cell(1, testCase.MemberCount);
            for i = 1:testCase.MemberCount
                p = fullfile(pwd, sprintf('member_%d.bin', i));
                fid = fopen(p, 'w');
                fwrite(fid, uint8((1:8) * i), 'uint8');
                fclose(fid);
                testCase.MemberPaths{i} = p;
            end
        end
    end

    methods (Access = private)
        function doc = makeAuthoredSeriesDoc(testCase)
            % A demoNDISeries document with one series and one ordinary
            % file alongside. addFileSeries populates series_info.
            % ingest_locations, so needsReconstruction returns false here
            % -- the point of this fixture.
            manifestPath = fullfile(pwd, 'chunkdata.bin');
            fid = fopen(manifestPath, 'w'); fwrite(fid, uint8(1:8)); fclose(fid);
            doc = ndi.document('demoNDISeries', ...
                'base.name', 'authored_series_doc', ...
                'demoNDISeries.value', 1, ...
                'base.session_id', did.ido.unique_id());
            doc = doc.addFileSeries('chunkdata.bin', testCase.MemberPaths);
        end

        function doc = makePlainDocWithOneFile(~)
            % A demoNDISeries document with no file series -- the series
            % info branch must be skipped entirely.
            filePath = fullfile(pwd, 'plain.bin');
            fid = fopen(filePath, 'w'); fwrite(fid, uint8(1:16)); fclose(fid);
            doc = ndi.document('demoNDISeries', ...
                'base.name', 'plain_doc', ...
                'demoNDISeries.value', 2, ...
                'base.session_id', did.ido.unique_id());
            doc = doc.add_file('plain.bin', filePath);
        end
    end

    methods (Test)

        function testFileInfoReshapedToNdicloud(testCase)
            % Every file_info location must come out with location_type
            % 'ndicloud', ingest 0, delete_original 0, and its location
            % rewritten to ndic://<datasetId>/<uid>. The uid itself must
            % survive unchanged -- the ndic:// URL is built out of it.
            doc = testCase.makeAuthoredSeriesDoc();
            fiBefore = doc.document_properties.files.file_info;
            uidsBefore = cell(1, numel(fiBefore));
            for i = 1:numel(fiBefore)
                uidsBefore{i} = fiBefore(i).locations(1).uid;
            end

            out = ndi.cloud.sync.internal.updateFileInfoForRemoteFiles( ...
                doc, "test-dataset");

            fi = out.document_properties.files.file_info;
            testCase.assertEqual(numel(fi), numel(fiBefore));
            for i = 1:numel(fi)
                testCase.verifyEqual(fi(i).locations(1).location_type, ...
                    'ndicloud');
                testCase.verifyEqual(fi(i).locations(1).ingest, 0);
                testCase.verifyEqual(fi(i).locations(1).delete_original, 0);
                testCase.verifyEqual(fi(i).locations(1).uid, uidsBefore{i}, ...
                    'uid must survive the reshape');
                testCase.verifyEqual(fi(i).locations(1).location, ...
                    sprintf('ndic://test-dataset/%s', uidsBefore{i}));
            end
        end

        function testPopulatedIngestLocationsSkipsReconstruction(testCase)
            % A freshly-authored doc still has its ingest_locations, so
            % needsReconstruction returns false. The function must not
            % touch series_info -- no fetch, no reconstruction, and
            % (critically) no network. If it did, this test would hang or
            % error trying to reach a cloud dataset that does not exist.
            doc = testCase.makeAuthoredSeriesDoc();
            siBefore = doc.document_properties.files.series_info;

            out = ndi.cloud.sync.internal.updateFileInfoForRemoteFiles( ...
                doc, "test-dataset");

            si = out.document_properties.files.series_info;
            testCase.assertEqual(numel(si), numel(siBefore));
            for k = 1:numel(si)
                testCase.verifyEqual(si(k).ingest_locations, ...
                    siBefore(k).ingest_locations, ...
                    ['ingest_locations must survive unchanged when it ' ...
                     'is already populated -- the reconstruction ' ...
                     'branch must not fire']);
                testCase.verifyEqual(si(k).n_present, siBefore(k).n_present, ...
                    'n_present must survive unchanged');
            end
        end

        function testDocWithoutSeriesInfoSkipsTheBlock(testCase)
            % A document that carries only ordinary files has no
            % series_info branch to guard. The function must not error
            % on hasSeriesInfo == false, and must still reshape file_info.
            doc = testCase.makePlainDocWithOneFile();
            testCase.assertFalse( ...
                isfield(doc.document_properties.files, 'series_info') && ...
                ~isempty(doc.document_properties.files.series_info), ...
                'fixture: this doc should carry no populated series_info');

            out = ndi.cloud.sync.internal.updateFileInfoForRemoteFiles( ...
                doc, "another-dataset");

            fi = out.document_properties.files.file_info;
            testCase.assertNotEmpty(fi, ...
                'file_info should have been reshaped, not emptied');
            testCase.verifyEqual(fi(1).locations(1).location_type, 'ndicloud');
            testCase.verifyEqual(fi(1).locations(1).ingest, 0);
        end

        function testReconstructsIngestLocationsThroughAMockHandler(testCase)
            % The reconstruction path end-to-end, but offline: build a
            % doc, add it to a DID, read it back (which strips
            % ingest_locations, giving the SyncFiles=false shape), reshape
            % again through updateFileInfoForRemoteFiles with a MOCK
            % handler that serves the manifest bytes by uid. The
            % rebuilt ingest_locations must name every present member's
            % uid with an ndic:// location and ingest=0.
            %
            % This is the SAME mock-handler shape DID#201's read path
            % exercises in TestSeriesWithCloudOnlyManifestResolvesThroughHandler
            % on the read side. The point here is that both sides can
            % share one handler and one set of bytes.

            doc = testCase.makeAuthoredSeriesDoc();

            % Snapshot the manifest bytes and every uid the doc knows
            % about BEFORE the round trip through DID -- these are what
            % the mock handler will serve, and what the reconstructed
            % ingest_locations must name.
            fi = doc.document_properties.files.file_info;
            k = find(strcmp({fi.name}, 'chunkdata.bin'), 1);
            manifestUid = fi(k).locations(1).uid;
            manifestPathOnDisk = fi(k).locations(1).location;
            fidM = fopen(manifestPathOnDisk, 'r');
            manifestBytes = fread(fidM, Inf, '*uint8')';
            fclose(fidM);

            % Now walk the doc through the local-DID store/read cycle so
            % ingest_locations gets stripped (stripSeriesIngestLocations),
            % producing the exact shape a cloud round trip returns.
            db = did.implementations.sqlitedb( ...
                fullfile(pwd, 'localtest.sqlite'));
            db.add_branch('a');
            db.add_docs(doc, 'Validate', false);
            docBack = db.get_docs(doc.id());
            si = docBack.document_properties.files.series_info;
            testCase.assertTrue( ...
                ~isfield(si, 'ingest_locations') || isempty(si(1).ingest_locations), ...
                ['fixture: DID store should have stripped ingest_locations ' ...
                 'so this test is exercising the reconstruction, not a shortcut']);

            % A uid-keyed store served by the mock handler. Includes the
            % members too, though only the manifest is needed for
            % reconstruction (members are opened separately, which is
            % covered by DID#201's own tests). The call log is a handle
            % class instance so the anonymous function closes over it by
            % REFERENCE -- otherwise MATLAB copies struct-valued closure
            % state and appends land in the copy the test never sees.
            srcByUid = containers.Map('KeyType', 'char', 'ValueType', 'any');
            srcByUid(manifestUid) = manifestBytes;
            callLog = containers.Map('KeyType', 'char', 'ValueType', 'any');
            callLog('uids') = {};
            callLog('seriesNames') = {};
            callLog('modes') = {};
            handler = @(destPath, sourcePath, ctx) mockHandler( ...
                destPath, sourcePath, ctx, srcByUid, callLog);

            % Trip through updateFileInfoForRemoteFiles with the mock
            % handler. It should reconstruct ingest_locations without
            % writing anything durable outside the temp dir it manages.
            testDatasetId = 'mock-dataset';
            docReshaped = ndi.cloud.sync.internal.updateFileInfoForRemoteFiles( ...
                docBack, testDatasetId, 'customFileHandler', handler);

            % The reconstructed struct must have one entry per present
            % member (three, from testCase.MemberCount), each with an
            % ndic:// location, ingest=0, and a uid.
            siNew = docReshaped.document_properties.files.series_info;
            testCase.assertTrue(isfield(siNew, 'ingest_locations'));
            il = siNew(1).ingest_locations;
            testCase.assertNumElements(il, testCase.MemberCount, ...
                'one ingest_locations entry per present member is expected');
            for i = 1:numel(il)
                testCase.verifyEqual(il(i).ingest, 0);
                testCase.verifyEqual(il(i).delete_original, 0);
                testCase.verifyEqual(il(i).location_type, 'ndicloud');
                testCase.verifyTrue(startsWith(il(i).location, ...
                    ['ndic://' testDatasetId '/']), ...
                    'each ingest_locations entry must be an ndic:// URL');
                testCase.verifyNotEmpty(il(i).uid, ...
                    'each reconstructed entry must carry a member uid');
            end

            % One handler call, for the manifest uid, seriesName '' (a
            % manifest, not a member). Multiple present slots in the
            % same series must NOT provoke multiple manifest fetches --
            % that guarantee is what makes reconstruction cheap for a
            % 28,000-member series.
            uids = callLog('uids');
            seriesNames = callLog('seriesNames');
            modes = callLog('modes');
            testCase.verifyEqual(uids, {manifestUid}, ...
                'exactly one manifest fetch expected');
            testCase.verifyEqual(seriesNames{1}, '', ...
                'the manifest fetch must carry seriesName='''' in its context');
            testCase.verifyEqual(modes{1}, 'open');

            % Try closing the DID handle so the working folder fixture's
            % cleanup does not stumble on Windows.
            try
                mksqlite('close'); %#ok<TRYNC>
            catch
            end
        end

    end
end


function mockHandler(destPath, sourcePath, context, srcByUid, callLog)
    % Uid-keyed mock. Same shape as
    % TestSeriesWithCloudOnlyManifestResolvesThroughHandler's mock, plus
    % a call log so the test can pin how many times, with what
    % context, the handler was invoked. callLog is a containers.Map
    % (handle class) so appending here is visible in the enclosing
    % test.
    uid = '';
    seriesName = '';
    mode = '';
    if isstruct(context)
        if isfield(context, 'uid') && ~isempty(context.uid)
            uid = char(context.uid);
        end
        if isfield(context, 'seriesName') && ~isempty(context.seriesName)
            seriesName = char(context.seriesName);
        end
        if isfield(context, 'mode') && ~isempty(context.mode)
            mode = char(context.mode);
        end
    end
    if isempty(uid)
        cloudPath = split(extractAfter(sourcePath, 'ndic://'), "/");
        uid = char(cloudPath{2});
    end

    callLog('uids')        = [callLog('uids')        {uid}];
    callLog('seriesNames') = [callLog('seriesNames') {seriesName}];
    callLog('modes')       = [callLog('modes')       {mode}];

    if ~isKey(srcByUid, uid)
        error('mockHandler:unknownUid', ...
            'the mock has no bytes for uid %s', uid);
    end
    bytes = srcByUid(uid);
    fid = fopen(destPath, 'w');
    fwrite(fid, bytes, 'uint8');
    fclose(fid);
end
