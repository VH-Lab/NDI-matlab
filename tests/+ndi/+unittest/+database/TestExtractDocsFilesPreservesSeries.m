classdef TestExtractDocsFilesPreservesSeries < matlab.unittest.TestCase
    % ndi.database.fun.extract_docs_files must not destroy files.series_info.
    %
    % This is NDI-matlab#946, the same shape of bug as #945 on a different
    % path. The extract loop copies a document's files to a target directory
    % and repoints the copy at them:
    %
    %     fl = docs{i}.current_file_list();
    %     docs{i} = docs{i}.reset_file_info;
    %     for f = 1:numel(fl)
    %         ... docs{i} = docs{i}.add_file(name, fullpathfilename);
    %     end
    %
    % did.document/reset_file_info clears file_info AND series_info -- its own
    % comment says "A series' per-instance record is reset with the rest". The
    % loop then repopulates file_info only, so series_info is left as the empty
    % struct the reset installed and the copy reports zero members for a
    % populated series.
    %
    % WHY THIS ONE WAS WORSE THAN #945. docs is a return value, and
    % ndi.dataset.copySessionToDataset stores it: adding a session to a dataset
    % runs the extract and then database_adds the result. So where #945
    % corrupted a document in memory after download, this wrote the stripped
    % document into a dataset as the stored copy.
    %
    % The extract now copies the series MEMBERS as well as the manifest, and
    % records them under their original uids, so the dataset copy carries a
    % series that can actually be read. That closes the loop: preserving the
    % counts (this issue) is only honest if the bytes the counts describe
    % travel with them. VH-Lab/DID-matlab#185 refuses a document that declares
    % present members while recording no way to locate any of them, which is
    % exactly what an extract produced before the members were copied.
    %
    % It is silent: isFileSeries reads files.file_series, the class declaration
    % from the schema, which the reset deliberately leaves alone. So a caller
    % gets "yes, this is a series" and "it has 0 members" together, with no
    % error. Only seriesCount notices, and it returns 0 rather than throwing.
    %
    % No credentials and no network: a session in a temporary directory, and
    % the function called directly.

    properties (Constant)
        MemberCount = 4;
        SeriesDocName = 'series_extract_doc';
        SeriesName = 'chunkdata.bin';
    end

    properties
        Session
        TargetPath
        SeriesDocId
        MemberPaths (1,:) cell = {}
    end

    methods (TestMethodSetup)
        function setupSessionWithASeries(testCase)
            % A session holding one demoNDISeries document with a populated
            % series. Built the way ndi.unittest.session.buildSession does:
            % a directory session with documents added straight to it, no
            % daq systems, so nothing here depends on example data.
            sessionPath = tempname;
            mkdir(sessionPath);
            testCase.Session = ndi.session.dir('exp_series', sessionPath);

            memberDir = fullfile(sessionPath, 'level0');
            mkdir(memberDir);
            testCase.MemberPaths = cell(1, testCase.MemberCount);
            for i = 1:testCase.MemberCount
                memberPath = fullfile(memberDir, sprintf('chunk_%04d.bin', i));
                fid = fopen(memberPath, 'w');
                fwrite(fid, uint8(mod((1:16) * i, 251)), 'uint8');
                fclose(fid);
                testCase.MemberPaths{i} = memberPath;
            end

            doc = ndi.document('demoNDISeries', ...
                'base.name', testCase.SeriesDocName, ...
                'demoNDISeries.value', 1, ...
                'base.session_id', testCase.Session.id());
            doc = doc.addFileSeries(testCase.SeriesName, testCase.MemberPaths);
            testCase.Session.database_add(doc);
            testCase.SeriesDocId = doc.id();

            % Where the extract puts its copies. Given explicitly so the test
            % can clean it up; extract_docs_files would otherwise pick a
            % folder under the NDI temp directory and leave it there.
            testCase.TargetPath = tempname;
            mkdir(testCase.TargetPath);
        end
    end

    methods (TestMethodTeardown)
        function teardownSession(testCase)
            if ~isempty(testCase.Session)
                sessionPath = testCase.Session.path();
                if isfolder(sessionPath)
                    rmdir(sessionPath, 's');
                end
            end
            if ~isempty(testCase.TargetPath) && isfolder(testCase.TargetPath)
                rmdir(testCase.TargetPath, 's');
            end
        end
    end

    methods (Access = private)
        function doc = findSeriesDoc(testCase, docs)
            % The extract returns every document in the session, so pick out
            % the one under test by name rather than by position.
            doc = [];
            for i = 1:numel(docs)
                if strcmp(docs{i}.document_properties.base.name, testCase.SeriesDocName)
                    doc = docs{i};
                    return;
                end
            end
            testCase.assertNotEmpty(doc, ...
                ['The extract did not return the series document (' ...
                 testCase.SeriesDocName ').']);
        end

        function docs = extractDocs(testCase)
            [docs, ~] = ndi.database.fun.extract_docs_files( ...
                testCase.Session, testCase.TargetPath);
        end

        function closeDatabasesQuietly(~)
            % Mirrors the mksqlite('close') that add_ingested_session does at
            % the end of a successful add. Failing to close is not worth
            % failing a teardown over, and there may be nothing open.
            try
                mksqlite('close');
            catch
                % nothing open, or no handle to close
            end
        end
    end

    methods (Test)

        function testTheStoredSessionDocumentHasItsMembers(testCase)
            % Control. The count has to survive the session's own database
            % round trip before the extract can be blamed for losing it; if
            % this fails the rest says nothing.
            q = ndi.query('base.name', 'exact_string', testCase.SeriesDocName);
            docs = testCase.Session.database_search(q);
            testCase.assertNumElements(docs, 1, ...
                'expected exactly one series document in the session');

            [n, nPresent] = docs{1}.seriesCount(testCase.SeriesName);
            testCase.verifyEqual(n, testCase.MemberCount);
            testCase.verifyEqual(nPresent, testCase.MemberCount);
        end

        function testExtractKeepsTheSeriesRecord(testCase)
            % THE BUG this suite was written for (#946): series_info came
            % back empty, because reset_file_info clears it and the copy loop
            % restored file_info only.
            extracted = testCase.findSeriesDoc(testCase.extractDocs());

            testCase.onFailure(@() disp(extracted.document_properties.files));

            hasSeriesInfo = isfield(extracted.document_properties.files, 'series_info') && ...
                ~isempty(extracted.document_properties.files.series_info);
            testCase.verifyTrue(hasSeriesInfo, ...
                ['files.series_info was emptied. reset_file_info clears it ' ...
                 'along with file_info, and the copy loop only restores ' ...
                 'file_info. See NDI-matlab#946.']);

            [n, nPresent] = extracted.seriesCount(testCase.SeriesName);
            testCase.verifyEqual(n, testCase.MemberCount, ...
                'series member count did not survive extract_docs_files');
            testCase.verifyEqual(nPresent, testCase.MemberCount, ...
                'series present-count did not survive extract_docs_files');
        end

        function testTheDeclarationSurvivesWhichIsWhyTheLossIsSilent(testCase)
            % isFileSeries reads files.file_series, the class declaration,
            % which reset_file_info deliberately leaves alone. So a caller
            % gets "yes this is a series" and "it has 0 members" together,
            % with no error anywhere. Pinning this explains the failure mode
            % to whoever reads it next.
            extracted = testCase.findSeriesDoc(testCase.extractDocs());

            testCase.verifyTrue(extracted.isFileSeries(testCase.SeriesName), ...
                'the class declaration should survive; it comes from the schema');
        end

        function testTheManifestIsCopiedAndFileInfoRepointed(testCase)
            % What the function is FOR. The series' manifest is an ordinary
            % document file, so it travels like one: copied into the target
            % directory, with file_info pointing at the copy.
            extracted = testCase.findSeriesDoc(testCase.extractDocs());

            fileInfo = extracted.document_properties.files.file_info;
            testCase.assertNotEmpty(fileInfo, 'file_info should have been repopulated');
            testCase.verifyTrue(any(strcmpi(testCase.SeriesName, {fileInfo.name})), ...
                'the manifest should still be among the copied files');

            index = find(strcmpi(testCase.SeriesName, {fileInfo.name}), 1);
            copiedPath = fileInfo(index).locations(1).location;
            testCase.verifyTrue(startsWith(copiedPath, testCase.TargetPath), ...
                'file_info should point into the extract target directory');
            testCase.verifyTrue(isfile(copiedPath), ...
                'the manifest should have been copied to the target directory');
        end

        function testTheCopiedMembersLiveInTheTargetDirectory(testCase)
            % The members travel with the manifest. Before this, the extract
            % copied the manifest only and the copy described members that
            % were nowhere -- which VH-Lab/DID-matlab#185 refuses to store,
            % rightly.
            extracted = testCase.findSeriesDoc(testCase.extractDocs());

            entries = extracted.seriesIngestLocations(testCase.SeriesName);
            testCase.assertNumElements(entries, testCase.MemberCount, ...
                'every present member should be recorded for ingestion');

            for i = 1:numel(entries)
                testCase.verifyTrue(startsWith(entries(i).location, testCase.TargetPath), ...
                    'a copied member should live in the extract target directory');
                testCase.verifyTrue(isfile(entries(i).location), ...
                    'a recorded member should actually have been copied');
                testCase.verifyEqual(entries(i).ingest, 1, ...
                    'a copied member has to be marked for ingestion or it will not travel');
            end
        end

        function testTheCopiedMembersKeepTheirOriginalUids(testCase)
            % The manifest is copied byte for byte and names its members by
            % uid, so ingestion has to write each member back to
            % FileDir/<same uid>. A fresh uid would leave the copy's manifest
            % pointing at files that do not exist -- and nothing would say so,
            % because the manifest is not read during add.
            sourceUids = cell(1, testCase.MemberCount);
            for i = 1:testCase.MemberCount
                memberName = sprintf('%s_%d', testCase.SeriesName, i);
                [tf, memberPath] = testCase.Session.database_existbinarydoc( ...
                    testCase.SeriesDocId, memberName);
                testCase.assertTrue(tf, ...
                    ['member ' memberName ' should be in the source session']);
                [~, sourceUids{i}, ~] = fileparts(memberPath);
            end

            extracted = testCase.findSeriesDoc(testCase.extractDocs());
            entries = extracted.seriesIngestLocations(testCase.SeriesName);
            copiedUids = {entries.uid};

            testCase.verifyEqual(sort(copiedUids), sort(sourceUids), ...
                'the copied members should carry the uids the manifest names');
        end

        function testASessionCopiedIntoADatasetKeepsItsMembers(testCase)
            % Why this bug is worse than #945: the extract's return value is
            % stored. copySessionToDataset runs the extract and database_adds
            % the result, so a stripped document becomes the dataset's copy
            % at rest. This is the end-to-end consequence #946 reasoned about
            % from the code path but had not confirmed.
            datasetPath = tempname;
            mkdir(datasetPath);
            testCase.addTeardown(@() rmdir(datasetPath, 's'));
            testCase.addTeardown(@() testCase.closeDatabasesQuietly());
            dataset = ndi.dataset.dir('ds_series', datasetPath);

            % The real entry point, the way ndi.unittest.dataset.buildDataset
            % uses it: add_ingested_session calls copySessionToDataset, which
            % is where the extract runs.
            dataset.add_ingested_session(testCase.Session);

            q = ndi.query('base.name', 'exact_string', testCase.SeriesDocName);
            docs = dataset.database_search(q);
            testCase.assertNumElements(docs, 1, ...
                'expected exactly one series document in the dataset');

            [n, nPresent] = docs{1}.seriesCount(testCase.SeriesName);
            testCase.verifyEqual(n, testCase.MemberCount, ...
                'the dataset''s stored copy lost the series member count');
            testCase.verifyEqual(nPresent, testCase.MemberCount, ...
                'the dataset''s stored copy lost the series present-count');
        end

        function testTheDatasetCopyKeepsReadableMembers(testCase)
            % The counts are only honest if the bytes arrived. Read each
            % member back out of the dataset and compare it to what went in.
            datasetPath = tempname;
            mkdir(datasetPath);
            testCase.addTeardown(@() rmdir(datasetPath, 's'));
            testCase.addTeardown(@() testCase.closeDatabasesQuietly());
            dataset = ndi.dataset.dir('ds_series_read', datasetPath);
            dataset.add_ingested_session(testCase.Session);

            q = ndi.query('base.name', 'exact_string', testCase.SeriesDocName);
            docs = dataset.database_search(q);
            testCase.assertNumElements(docs, 1);

            for i = 1:testCase.MemberCount
                memberName = sprintf('%s_%d', testCase.SeriesName, i);
                [tf, memberPath] = dataset.database_existbinarydoc(docs{1}, memberName);
                testCase.assertTrue(tf, ...
                    ['member ' memberName ' did not arrive in the dataset']);

                fid = fopen(memberPath, 'r');
                actual = fread(fid, inf, '*uint8')';
                fclose(fid);
                testCase.verifyEqual(actual, uint8(mod((1:16) * i, 251)), ...
                    ['member ' memberName ' arrived with different bytes']);
            end
        end

    end
end
