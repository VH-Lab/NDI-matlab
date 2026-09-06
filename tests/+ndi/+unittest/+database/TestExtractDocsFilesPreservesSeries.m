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
    % That is no longer what happens, and the last test here says so.
    % VH-Lab/DID-matlab#185 made the database refuse a document that declares
    % present series members while recording no way to locate any of them --
    % which is what an extract produces, because it copies the manifest and
    % not the members (DID#173). So the dataset copy of a series-carrying
    % session now ERRORS rather than storing zeroed counts. Losing the counts
    % was the bug; the refusal is the current answer to what replaces it.
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
            % THE BUG. Currently fails: series_info comes back empty.
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

        function testTheCopyCarriesNoPathIntoTheSourceSession(testCase)
            % The decision this fix records: an extract carries the series
            % RECORD (name, count, n_present, source_root) but not
            % ingest_locations, which name where the members sit in the
            % source session and are meaningless in the target.
            %
            % Today this also holds upstream -- the database strips
            % ingest_locations on the way into storage, so the documents the
            % extract reads never carry any. This pins it as a property of
            % the extract's output regardless, which is what matters for a
            % copy that gets stored somewhere else.
            extracted = testCase.findSeriesDoc(testCase.extractDocs());

            testCase.verifyEmpty(extracted.seriesIngestLocations(testCase.SeriesName), ...
                'the extracted copy should not carry the source session''s member paths');
        end

        function testCopyingASeriesIntoADatasetIsRefusedUntilMembersCanTravel(testCase)
            % Copying a session that holds a POPULATED series into a dataset
            % does not work today, and fails loudly rather than quietly. That
            % is the whole point of the guard, and it is worth pinning.
            %
            % HOW THIS GOT HERE. #946 was about the dataset's stored copy
            % losing its member counts, and this test originally asserted the
            % counts came back. They do -- out of the extract, which is what
            % the tests above check. But the extract copies the MANIFEST and
            % not the members (see extract_docs_files' own help, and
            % VH-Lab/DID-matlab#173: nothing ingests members yet, so there are
            % none in the source store to copy). So what reaches the dataset
            % is a document saying "4 present members" while recording no way
            % to find one.
            %
            % VH-Lab/DID-matlab#185 made did.implementations.sqlitedb refuse
            % exactly that, for a document the target database has never held:
            % storing it "produces a manifest full of uids whose bytes will
            % never arrive". The refusal is correct and it is upstream's call
            % to make. It also means ndi.dataset.add_ingested_session now
            % ERRORS for a session carrying a populated series, where before
            % NDI-matlab#947 it silently stored one with zeroed counts.
            %
            % Losing the counts was the bug. Refusing the copy is the current,
            % deliberate answer to what replaces it. When member copying lands
            % (DID#173, then the extract work its help text names), this test
            % should go back to asserting that the dataset's copy keeps its
            % four members -- the assertion is in the git history of this file.
            datasetPath = tempname;
            mkdir(datasetPath);
            testCase.addTeardown(@() rmdir(datasetPath, 's'));
            % Registered after the rmdir so it runs BEFORE it (teardowns are
            % LIFO). add_ingested_session closes the database itself as its
            % last act; erroring part way through means that never runs, and
            % an open handle should not be left for the next test.
            testCase.addTeardown(@() testCase.closeDatabasesQuietly());
            dataset = ndi.dataset.dir('ds_series', datasetPath);

            % The real entry point, the way ndi.unittest.dataset.buildDataset
            % uses it: add_ingested_session calls copySessionToDataset, which
            % is where the extract runs.
            testCase.verifyError(@() dataset.add_ingested_session(testCase.Session), ...
                'DID:SQLITEDB:FileSeries:MembersNotLocatable', ...
                ['Copying a session with a populated file series into a ' ...
                 'dataset should be refused while the extract cannot carry ' ...
                 'the members. See VH-Lab/DID-matlab#185 and #173.']);
        end

    end
end
