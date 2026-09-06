classdef TestListBinaryFilesIncludesSeriesMembers < matlab.unittest.TestCase
    % ndi.database.internal.list_binary_files must enumerate file series
    % members, not just the series manifest.
    %
    % This is the upload half of NDI-matlab#956. list_binary_files builds the
    % manifest that ndi.cloud.sync.internal.uploadFilesForDatasetDocuments
    % hands to the uploader, so a file the manifest does not name is a file
    % that never reaches the cloud.
    %
    % It walked files.file_list, expanding a series only under the LEGACY
    % convention -- a name ending in '#', expanded NAME1, NAME2, ... A
    % new-style series (files.file_series) records its members in a binary
    % manifest rather than in file_list and names them NAME_<i>, with an
    % underscore, so it never matched. A series therefore reached the cloud as
    % its manifest alone: a document declaring N members, none of whose bytes
    % had been uploaded. The download then had nothing to fetch, which is what
    % made ndi.unittest.cloud.FileSeriesRoundTripTest's download test fail.
    %
    % These tests need no credentials and no network: list_binary_files takes
    % a local dataset and reads it, so the upload half can be checked in the
    % fast workflow rather than only in Cloud CI.

    properties (Constant)
        MemberCount = 4;
        SeriesDocName = 'series_upload_doc';
        SeriesName = 'chunkdata.bin';
    end

    properties
        Dataset
        DatasetPath
    end

    methods (TestMethodSetup)
        function setupDataset(testCase)
            testCase.DatasetPath = tempname;
            mkdir(testCase.DatasetPath);
            testCase.Dataset = ndi.dataset.dir('ds_upload_series', testCase.DatasetPath);
        end
    end

    methods (TestMethodTeardown)
        function teardownDataset(testCase)
            try
                mksqlite('close');
            catch
                % nothing open to close
            end
            if ~isempty(testCase.DatasetPath) && isfolder(testCase.DatasetPath)
                rmdir(testCase.DatasetPath, 's');
            end
        end
    end

    methods (Access = private)
        function doc = addSeriesDocument(testCase, docName, indices)
            % Adds a demoNDISeries document whose series has a member at each
            % of INDICES. Empty INDICES means a dense series of MemberCount.
            memberDir = fullfile(testCase.DatasetPath, ['members_' docName]);
            mkdir(memberDir);

            if isempty(indices)
                indices = 1:testCase.MemberCount;
            end
            memberPaths = cell(1, numel(indices));
            for i = 1:numel(indices)
                p = fullfile(memberDir, sprintf('chunk_%04d.bin', indices(i)));
                fid = fopen(p, 'w');
                % Distinct lengths per slot, so a manifest entry that pointed
                % at the wrong member would show up as a wrong byte count.
                fwrite(fid, uint8(1:(8 + indices(i))), 'uint8');
                fclose(fid);
                memberPaths{i} = p;
            end

            doc = ndi.document('demoNDISeries', ...
                'base.name', docName, ...
                'demoNDISeries.value', 1, ...
                'base.session_id', testCase.Dataset.id());
            doc = doc.addFileSeries(testCase.SeriesName, memberPaths, ...
                'indices', indices);
            testCase.Dataset.database_add(doc);
        end

        function manifest = listFiles(testCase)
            docs = testCase.Dataset.database_search(ndi.query('', 'isa', 'base'));
            manifest = ndi.database.internal.list_binary_files( ...
                testCase.Dataset, docs, false);
        end
    end

    methods (Test)

        function testTheSeriesManifestIsListed(testCase)
            % Control: the series' own manifest file is an ordinary document
            % file and was always listed. If this fails the rest says nothing.
            testCase.addSeriesDocument(testCase.SeriesDocName, []);
            manifest = testCase.listFiles();

            testCase.verifyTrue(any(strcmp({manifest.name}, testCase.SeriesName)), ...
                'the series manifest file should be in the upload manifest');
        end

        function testEveryMemberIsListed(testCase)
            % THE BUG (#956): members were never named, so they never
            % uploaded.
            testCase.addSeriesDocument(testCase.SeriesDocName, []);
            manifest = testCase.listFiles();

            names = {manifest.name};
            for i = 1:testCase.MemberCount
                expected = sprintf('%s_%d', testCase.SeriesName, i);
                testCase.verifyTrue(any(strcmp(names, expected)), ...
                    ['member ' expected ' is missing from the upload ' ...
                     'manifest, so its bytes would never reach the cloud']);
            end
        end

        function testEachMemberCarriesItsOwnUidAndSize(testCase)
            % A member is uploaded by uid and located by file_path, so an
            % entry that named the right member with another member's uid
            % would upload the wrong bytes under the right name.
            testCase.addSeriesDocument(testCase.SeriesDocName, []);
            manifest = testCase.listFiles();

            for i = 1:testCase.MemberCount
                entry = testCase.entryNamed(manifest, ...
                    sprintf('%s_%d', testCase.SeriesName, i));
                testCase.verifyNotEmpty(entry.uid, 'a member needs its uid to be uploaded');
                testCase.verifyTrue(isfile(entry.file_path), ...
                    'a member''s file_path should resolve to a real file');
                % Slot i was written with 8+i bytes.
                testCase.verifyEqual(entry.bytes, 8 + i, ...
                    'the manifest entry has the wrong member''s size');
            end

            memberUids = cell(1, testCase.MemberCount);
            for i = 1:testCase.MemberCount
                uidEntry = testCase.entryNamed(manifest, ...
                    sprintf('%s_%d', testCase.SeriesName, i));
                memberUids{i} = uidEntry.uid;
            end
            testCase.verifyNumElements(unique(memberUids), testCase.MemberCount, ...
                'each member must have a distinct uid');
        end

        function testASparseSeriesListsOnlyItsPresentMembers(testCase)
            % Slots 1 and 3 written, slot 2 never was. The absent slot must
            % be skipped rather than producing an entry with an empty path,
            % which the uploader would report as a missing file.
            testCase.addSeriesDocument('series_upload_sparse', [1 3]);
            manifest = testCase.listFiles();

            names = {manifest.name};
            testCase.verifyTrue(any(strcmp(names, [testCase.SeriesName '_1'])), ...
                'present slot 1 should be listed');
            testCase.verifyTrue(any(strcmp(names, [testCase.SeriesName '_3'])), ...
                'present slot 3 should be listed');
            testCase.verifyFalse(any(strcmp(names, [testCase.SeriesName '_2'])), ...
                'absent slot 2 should not be listed');

            for k = 1:numel(manifest)
                testCase.verifyNotEmpty(manifest(k).file_path, ...
                    'no manifest entry may have an empty file_path');
            end
        end

        function testADocumentWithoutASeriesIsUnaffected(testCase)
            % The ordinary path has to keep working: a plain document's file
            % is listed exactly once, and no phantom member entries appear.
            filePath = fullfile(testCase.DatasetPath, 'plain.ext');
            fid = fopen(filePath, 'w');
            fwrite(fid, uint8(1:32), 'uint8');
            fclose(fid);

            doc = ndi.document('demoNDI', ...
                'base.name', 'plain_doc', ...
                'demoNDI.value', 7, ...
                'base.session_id', testCase.Dataset.id());
            doc = doc.add_file('filename1.ext', filePath);
            testCase.Dataset.database_add(doc);

            manifest = testCase.listFiles();

            matches = strcmp({manifest.name}, 'filename1.ext');
            testCase.verifyEqual(sum(matches), 1, ...
                'a plain document file should be listed exactly once');
        end

    end

    methods (Access = private)
        function entry = entryNamed(testCase, manifest, name)
            index = find(strcmp({manifest.name}, name), 1);
            testCase.assertNotEmpty(index, ...
                ['no manifest entry named ' name]);
            entry = manifest(index);
        end
    end
end
