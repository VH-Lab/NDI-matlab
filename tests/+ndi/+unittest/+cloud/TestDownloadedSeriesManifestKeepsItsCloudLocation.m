classdef TestDownloadedSeriesManifestKeepsItsCloudLocation < matlab.unittest.TestCase
% A downloaded series manifest must keep the cloud reference it came from.
%
% ndi.cloud.sync.internal.updateFileInfoForLocalFiles re-points a downloaded
% document's files at the local copies that came down with it. For a FILE
% SERIES that is not enough, and the gap is invisible until someone opens a
% member.
%
% A series' members are deliberately left on the cloud -- that laziness is
% the point, so that opening a dataset does not drag down a 28,000-member
% series -- and a member has no location of its own. DID resolves one by
% handing the MANIFEST's location to the customFileHandler with the member's
% uid in the context (VH-Lab/DID-matlab#188), so the manifest's location is
% the only thing telling the handler where to look.
%
% With the local path as its only location, the handler is given a path that
% does not start with 'ndic://' and
% ndi.database.implementations.database.didsqlite/download_file_from_cloud
% raises NDI:Didsqlite:UnsupportedFileLocationType. DID treats a handler that
% fails as a plain miss -- deliberately, since it resolves speculatively --
% so every member of a downloaded series reads as absent and nothing says
% why. See VH-Lab/NDI-matlab#966.
%
% So the manifest keeps both: the local copy, and the 'ndic://' reference
% under the uid the cloud knows it by.
%
% Offline. This is the half of #966 that needs no credentials and no network,
% and it is the half that was wrong.

    properties (Constant)
        SeriesName = 'chunkdata.bin';
        CloudDatasetId = "6a9de57dab55fb610de803d5";
    end

    properties
        Dataset
        DatasetPath
        FileDir
    end

    methods (TestMethodSetup)
        function setupWorkingFolder(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
            testCase.DatasetPath = fullfile(pwd, 'ds');
            mkdir(testCase.DatasetPath);
            % A dataset only so that base.session_id is a real id; nothing is
            % added to it. The subject here is a document, not a database.
            testCase.Dataset = ndi.dataset.dir('ds_manifest_location', testCase.DatasetPath);

            testCase.FileDir = fullfile(pwd, 'downloaded_files');
            mkdir(testCase.FileDir);
        end
    end

    methods (TestMethodTeardown)
        function closeDatabase(~)
            try
                mksqlite('close');
            catch
                % nothing open to close
            end
        end
    end

    methods (Access = private)
        function doc = seriesDocument(testCase)
            % A two-member series, then the state a SyncFiles download leaves
            % behind: the manifest's bytes present in FileDir under its uid,
            % the members nowhere on this machine.
            memberDir = fullfile(pwd, 'members');
            mkdir(memberDir);
            memberPaths = cell(1, 2);
            for i = 1:2
                p = fullfile(memberDir, sprintf('member%d.bin', i));
                fid = fopen(p, 'w');
                fwrite(fid, uint8(1:(8 + i)), 'uint8');
                fclose(fid);
                memberPaths{i} = p;
            end

            doc = ndi.document('demoNDISeries', ...
                'base.name', 'series_doc', ...
                'demoNDISeries.value', 1, ...
                'base.session_id', testCase.Dataset.id());
            doc = doc.addFileSeries(testCase.SeriesName, memberPaths);

            % The downloaded copy of the manifest, named by its uid, which is
            % what updateFileInfoForLocalFiles looks for.
            entry = testCase.entryNamed(doc, testCase.SeriesName);
            copyfile(entry.locations(1).location, ...
                fullfile(testCase.FileDir, entry.locations(1).uid));
        end

        function entry = entryNamed(testCase, doc, name)
            fi = doc.document_properties.files.file_info;
            idx = find(strcmp({fi.name}, name), 1);
            testCase.assertNotEmpty(idx, ['no file_info entry named ' name]);
            entry = fi(idx);
        end

        function loc = locationOfType(testCase, locations, wantedType)
            types = {locations.location_type};
            idx = find(strcmp(types, wantedType), 1);
            testCase.assertNotEmpty(idx, ...
                ['no location of type ' wantedType ' (have: ' ...
                 strjoin(types, ', ') ')']);
            loc = locations(idx);
        end
    end

    methods (Test)

        function testTheManifestKeepsItsLocalCopy(testCase)
            % Control. The existing behaviour must survive: the manifest is
            % here, and reading it must not require the network.
            doc = testCase.seriesDocument();
            out = ndi.cloud.sync.internal.updateFileInfoForLocalFiles( ...
                doc, string(testCase.FileDir), testCase.CloudDatasetId);

            entry = testCase.entryNamed(out, testCase.SeriesName);
            local = testCase.locationOfType(entry.locations, 'file');
            testCase.verifyTrue(isfile(local.location), ...
                'the manifest''s local location should resolve to a real file');
        end

        function testTheManifestAlsoKeepsItsCloudReference(testCase)
            % THE BUG (#966). Without this the handler is handed a local path
            % it cannot resolve, and every member of the series is
            % unreadable.
            doc = testCase.seriesDocument();
            % Two steps: indexing into a method's return value is not legal
            % MATLAB.
            beforeEntry = testCase.entryNamed(doc, testCase.SeriesName);
            expectedUid = beforeEntry.locations(1).uid;

            out = ndi.cloud.sync.internal.updateFileInfoForLocalFiles( ...
                doc, string(testCase.FileDir), testCase.CloudDatasetId);

            entry = testCase.entryNamed(out, testCase.SeriesName);
            remote = testCase.locationOfType(entry.locations, 'ndicloud');

            % The uid in the reference must be the one the CLOUD knows the
            % manifest by -- its ORIGINAL uid, not the fresh one add_file
            % mints for this location's own record. A reference built from
            % the wrong uid would ask the cloud for a file that is not there.
            testCase.verifyEqual(remote.location, ...
                char(sprintf('ndic://%s/%s', testCase.CloudDatasetId, expectedUid)), ...
                'the cloud reference names the wrong dataset or uid');

            % An ndic:// location is fetched on demand, never ingested at add
            % time and never deleted: that laziness is why the members stay
            % on the cloud in the first place.
            % double(): verifyEqual is strict about class, and these flags
            % are written as 0/1 by more than one path.
            testCase.verifyEqual(double(remote.ingest), 0, ...
                'the cloud reference must not be ingested at add time');
            testCase.verifyEqual(double(remote.delete_original), 0, ...
                'the cloud reference must not be marked delete_original');
        end

        function testAPlainFileGetsNoCloudReference(testCase)
            % Only manifests need one. Every other file came down with the
            % dataset and is already here, so a second location on each would
            % be rows to no purpose.
            filePath = fullfile(pwd, 'plain.ext');
            fid = fopen(filePath, 'w');
            fwrite(fid, uint8(1:16), 'uint8');
            fclose(fid);

            doc = ndi.document('demoNDI', ...
                'base.name', 'plain_doc', ...
                'demoNDI.value', 7, ...
                'base.session_id', testCase.Dataset.id());
            doc = doc.add_file('filename1.ext', filePath);

            entry = testCase.entryNamed(doc, 'filename1.ext');
            copyfile(filePath, fullfile(testCase.FileDir, entry.locations(1).uid));

            out = ndi.cloud.sync.internal.updateFileInfoForLocalFiles( ...
                doc, string(testCase.FileDir), testCase.CloudDatasetId);

            outEntry = testCase.entryNamed(out, 'filename1.ext');
            testCase.verifyNumElements(outEntry.locations, 1, ...
                'a plain file should keep exactly one location');
            testCase.verifyEqual(outEntry.locations(1).location_type, 'file');
        end

        function testNoCloudDatasetIdMeansNoCloudReference(testCase)
            % updateFileInfoForLocalFiles is also called without a cloud
            % dataset id, and there is no reference to build then. It must
            % leave the document as it found it rather than writing
            % 'ndic:///<uid>'.
            doc = testCase.seriesDocument();
            out = ndi.cloud.sync.internal.updateFileInfoForLocalFiles( ...
                doc, string(testCase.FileDir));

            entry = testCase.entryNamed(out, testCase.SeriesName);
            types = {entry.locations.location_type};
            testCase.verifyFalse(any(strcmp(types, 'ndicloud')), ...
                'no cloud dataset id was given, so no cloud reference is possible');
        end

    end
end
