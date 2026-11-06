classdef SessionWriterMockTest < matlab.unittest.TestCase
% SESSIONWRITERMOCKTEST - ndi.cloud.upload.SessionWriter against a fake cloud dataset.
%
% Covers what a live server cannot be made to do on demand: a session
% that is not in the dataset, a subject in the wrong session, an upload
% that arrives with the wrong bytes once or every time, and a cloud that
% recorded no checksum. The fake is ndi.test.helper.FakeCloudDataset.
%
% Authored without a local MATLAB runtime; needs MATLAB to validate/run.

    properties
        cloud
        sessionId
        subjectId
    end

    methods (TestMethodSetup)
        function build(testCase)
            testCase.cloud = ndi.test.helper.FakeCloudDataset();
            testCase.sessionId = testCase.cloud.addSession('exp1');
            testCase.subjectId = testCase.cloud.addSubject(testCase.sessionId, 'mouse1@lab');
        end
    end

    methods (Test)

        function testASessionNotInTheDatasetIsRefused(testCase)
            testCase.verifyError(@() ndi.cloud.upload.SessionWriter( ...
                testCase.cloud.DatasetId, 'not_a_session', ...
                'Api', testCase.cloud.api(), 'Verbose', false), ...
                'NDI:cloud:SessionWriter:noSuchSession');
        end

        function testListsSessionsAndTheirSubjects(testCase)
            other = testCase.cloud.addSession('exp2');
            testCase.cloud.addSubject(other, 'mouse2@lab');
            s = ndi.cloud.upload.SessionWriter.listSessions( ...
                testCase.cloud.DatasetId, 'Api', testCase.cloud.api());
            testCase.verifyEqual(sort({s.session_reference}), {'exp1', 'exp2'});
            subj = ndi.cloud.upload.SessionWriter.listSubjects( ...
                testCase.cloud.DatasetId, testCase.sessionId, 'Api', testCase.cloud.api());
            testCase.verifyEqual({subj.local_identifier}, {'mouse1@lab'}, ...
                'only the subjects of the asked-for session');
            testCase.verifyEqual(subj.id, testCase.subjectId);
        end

        function testNewDocumentsBelongToTheCloudSession(testCase)
            W = testCase.writer();
            testCase.verifyEqual(W.id(), testCase.sessionId);
            d = W.newdocument('base');
            testCase.verifyEqual(d.document_properties.base.session_id, testCase.sessionId);
        end

        function testRequireSubjectChecksTheSession(testCase)
            W = testCase.writer();
            W.requireSubject(testCase.subjectId);   % no error
            other = testCase.cloud.addSession('exp2');
            elsewhere = testCase.cloud.addSubject(other, 'mouse2@lab');
            testCase.verifyError(@() W.requireSubject(elsewhere), ...
                'NDI:cloud:SessionWriter:subjectInOtherSession');
            testCase.verifyError(@() W.requireSubject('nobody'), ...
                'NDI:cloud:SessionWriter:noSubject');
        end

        function testADocumentOnAnotherSessionsSubjectIsRefused(testCase)
            W = testCase.writer();
            other = testCase.cloud.addSession('exp2');
            elsewhere = testCase.cloud.addSubject(other, 'mouse2@lab');
            [d, ~] = testCase.seriesDoc(W, elsewhere, 3);
            testCase.verifyError(@() W.database_add(d), ...
                'NDI:cloud:SessionWriter:subjectInOtherSession');
            testCase.verifyEqual(testCase.cloud.singleUploads, 0, ...
                'nothing may be sent for a document that is refused');
        end

        function testADocumentOfAnotherSessionIsRefused(testCase)
            W = testCase.writer();
            d = ndi.document('base', 'base.session_id', 'some_other_session');
            testCase.verifyError(@() W.database_add(d), ...
                'NDI:cloud:SessionWriter:wrongSession');
        end

        function testFilesGoFirstAndDocumentsWaitForCommit(testCase)
            W = testCase.writer();
            [d, bytes] = testCase.seriesDoc(W, testCase.subjectId, 3);
            W.database_add(d);

            testCase.verifyEmpty(testCase.cloud.docsOfClass('lightsheetZarrLevel'), ...
                'the document must wait for commit');
            locs = d.document_properties.files.series_info(1).ingest_locations;
            for i = 1:numel(locs)
                testCase.verifyEqual(testCase.cloud.fileBytes(locs(i).uid), bytes{locs(i).index}, ...
                    'each member goes up under its own uid with its own bytes');
            end
            manifestUid = d.document_properties.files.file_info(1).locations(1).uid;
            testCase.verifyTrue(testCase.cloud.hasFile(manifestUid), ...
                'the series manifest is a file too');

            r = W.commit();
            testCase.verifyEqual(r.documents, 1);
            testCase.verifyEqual(r.files, 4);
            testCase.verifyEqual(r.resent, 0);
            stored = testCase.cloud.docsOfClass('lightsheetZarrLevel');
            testCase.verifyNumElements(stored, 1);
            testCase.verifyEqual(stored{1}.base.session_id, testCase.sessionId);
            testCase.verifyEmpty(stored{1}.files.series_info(1).ingest_locations, ...
                'member paths are stripped, as a local session stores them');
        end

        function testManyFilesGoInZipBatches(testCase)
            W = testCase.writer('BulkThreshold', 2);
            [d, ~] = testCase.seriesDoc(W, testCase.subjectId, 5);
            W.database_add(d);
            testCase.verifyEqual(testCase.cloud.batchUploads, 1);
            testCase.verifyEqual(testCase.cloud.singleUploads, 0);
        end

        function testAWrongUploadIsSentAgain(testCase)
            W = testCase.writer('BulkThreshold', 2);
            [d, bytes] = testCase.seriesDoc(W, testCase.subjectId, 3);
            bad = d.document_properties.files.series_info(1).ingest_locations(2);
            testCase.cloud.CorruptOnce = {bad.uid};
            W.database_add(d);
            testCase.verifyEqual(testCase.cloud.fileBytes(bad.uid), bytes{bad.index});
            testCase.verifyEqual(testCase.cloud.singleUploads, 1, ...
                'only the bad file is sent again');
            r = W.commit();
            testCase.verifyEqual(r.resent, 1);
        end

        function testSizeIsComparedWhenTheCloudHasNoChecksum(testCase)
            testCase.cloud.RecordCrc = false;
            W = testCase.writer();
            [d, bytes] = testCase.seriesDoc(W, testCase.subjectId, 2);
            bad = d.document_properties.files.series_info(1).ingest_locations(1);
            testCase.cloud.CorruptOnce = {bad.uid};
            W.database_add(d);
            testCase.verifyEqual(testCase.cloud.fileBytes(bad.uid), bytes{bad.index});
        end

        function testAnUploadThatStaysWrongIsAnError(testCase)
            W = testCase.writer();
            [d, ~] = testCase.seriesDoc(W, testCase.subjectId, 2);
            bad = d.document_properties.files.series_info(1).ingest_locations(1);
            testCase.cloud.CorruptAlways = {bad.uid};
            testCase.verifyError(@() W.database_add(d), ...
                'NDI:cloud:SessionWriter:uploadNotVerified');
            testCase.verifyEmpty(testCase.cloud.addedJson, ...
                'no document may be added when its files are not right');
        end

        function testAFailedAddIsAnError(testCase)
            W = testCase.writer();
            W.database_add(W.newdocument('base'));
            testCase.cloud.FailAdd = true;
            testCase.verifyError(@() W.commit(), ...
                'NDI:cloud:SessionWriter:addDocumentFailed');
        end

        function testOpenBinaryDocReadsTheLocalCopyOrDownloads(testCase)
            W = testCase.writer('KeepLocalCopies', true);
            testCase.addTeardown(@() rmdirIfThere(W.cacheDir));
            [d, bytes] = testCase.seriesDoc(W, testCase.subjectId, 2);
            W.database_add(d);
            f = W.database_openbinarydoc(d, 'chunk.bin_2');
            testCase.verifyEqual(readBytes(f.fullpathfilename), bytes{2});
            delete(f.fullpathfilename);
            f = W.database_openbinarydoc(d, 'chunk.bin_2');
            testCase.verifyEqual(readBytes(f.fullpathfilename), bytes{2}, ...
                'a file no longer cached is downloaded');
            testCase.verifyError(@() W.database_openbinarydoc(d, 'chunk.bin_9'), ...
                'NDI:cloud:SessionWriter:noSuchFile');
        end

        % -- streaming a series ------------------------------------------

        function testADeclaredDocumentGoesUpBeforeItsMembers(testCase)
            W = testCase.writer();
            [d, bytes] = testCase.seriesDoc(W, testCase.subjectId, 3);
            W.declare(d);
            testCase.verifyTrue(testCase.cloud.hasDocument(d.id()), ...
                'a declared document is in the cloud at once');
            manifestUid = d.document_properties.files.file_info(1).locations(1).uid;
            testCase.verifyTrue(testCase.cloud.hasFile(manifestUid), ...
                'its manifest is uploaded with it');
            locs = d.document_properties.files.series_info(1).ingest_locations;
            testCase.verifyFalse(testCase.cloud.hasFile(locs(1).uid), ...
                'members are not sent by declare');

            W.streamMembers(d, 'chunk.bin', [locs(1:2).index], {locs(1:2).location});
            W.streamMembers(d, 'chunk.bin', locs(3).index, {locs(3).location});
            r = W.commit();
            for i = 1:numel(locs)
                testCase.verifyEqual(testCase.cloud.fileBytes(locs(i).uid), ...
                    bytes{locs(i).index});
            end
            testCase.verifyEqual(r.documents, 1);
        end

        function testStreamedCopiesAreDeletedOnceChecked(testCase)
            W = testCase.writer('KeepLocalCopies', true);
            testCase.addTeardown(@() rmdirIfThere(W.cacheDir));
            [d, ~] = testCase.seriesDoc(W, testCase.subjectId, 2);
            W.declare(d);
            locs = d.document_properties.files.series_info(1).ingest_locations;
            W.streamMembers(d, 'chunk.bin', locs(1).index, {locs(1).location});
            W.streamMembers(d, 'chunk.bin', locs(2).index, {locs(2).location});
            testCase.verifyFalse(isfile(fullfile(W.cacheDir, locs(1).uid)), ...
                'a checked batch leaves the disk');
            testCase.verifyTrue(isfile(fullfile(W.cacheDir, locs(2).uid)), ...
                'the newest batch waits to be checked while the next is built');
            W.commit();
            testCase.verifyFalse(isfile(fullfile(W.cacheDir, locs(2).uid)));
        end

        function testRetainedMembersStayUntilReleased(testCase)
            W = testCase.writer('KeepLocalCopies', true);
            testCase.addTeardown(@() rmdirIfThere(W.cacheDir));
            [d, bytes] = testCase.seriesDoc(W, testCase.subjectId, 2);
            W.declare(d);
            locs = d.document_properties.files.series_info(1).ingest_locations;
            W.streamMembers(d, 'chunk.bin', [locs.index], {locs.location}, true);
            W.streamMembers(d, 'chunk.bin', [], {}, true);   % checks the batch
            f = W.database_openbinarydoc(d, 'chunk.bin_1');
            testCase.verifyTrue(isfile(f.fullpathfilename), 'retained for a later level');
            testCase.verifyEqual(readBytes(f.fullpathfilename), bytes{1});
            W.releaseMembers(d);
            testCase.verifyFalse(isfile(fullfile(W.cacheDir, locs(1).uid)), ...
                'released once that level is built');
        end

        function testCommitRefusesAMissingDeclaredMember(testCase)
            W = testCase.writer();
            [d, ~] = testCase.seriesDoc(W, testCase.subjectId, 3);
            W.declare(d);
            locs = d.document_properties.files.series_info(1).ingest_locations;
            W.streamMembers(d, 'chunk.bin', locs(1).index, {locs(1).location});
            testCase.verifyError(@() W.commit(), 'NDI:cloud:SessionWriter:membersMissing');
        end

        function testAnUndeclaredMemberIsRefused(testCase)
            W = testCase.writer();
            [d, ~] = testCase.seriesDoc(W, testCase.subjectId, 1);
            testCase.verifyError(@() W.streamMembers(d, 'chunk.bin', 1, {'x'}), ...
                'NDI:cloud:SessionWriter:notDeclared');
        end

        function testReplaceOnCommit(testCase)
            W = testCase.writer();
            d = W.newdocument('base', 'base.name', 'first (uploading)');
            W.declare(d);
            W.replaceOnCommit(d.setproperties('base.name', 'first'));
            stored = testCase.cloud.findDocuments('', ndi.query('base.id', 'exact_string', d.id()));
            testCase.verifyEqual(stored{1}.base.name, 'first (uploading)');
            W.commit();
            stored = testCase.cloud.findDocuments('', ndi.query('base.id', 'exact_string', d.id()));
            testCase.verifyEqual(stored{1}.base.name, 'first');
        end

        % -- sending in the background -------------------------------------

        function testASmallBatchIsSentInTheBackground(testCase)
            testCase.cloud.DeferSends = true;
            W = testCase.writer();
            [d, bytes] = testCase.seriesDoc(W, testCase.subjectId, 2);
            W.declare(d);
            locs = d.document_properties.files.series_info(1).ingest_locations;
            before = testCase.cloud.backgroundSends;
            W.streamMembers(d, 'chunk.bin', locs(1).index, {locs(1).location});
            testCase.verifyEqual(testCase.cloud.backgroundSends, before + 1);
            testCase.verifyFalse(testCase.cloud.hasFile(locs(1).uid), ...
                'streamMembers returns while the batch is still going up');
            W.streamMembers(d, 'chunk.bin', locs(2).index, {locs(2).location});
            testCase.verifyEqual(testCase.cloud.fileBytes(locs(1).uid), bytes{locs(1).index}, ...
                'the batch is waited for when it is checked, at the next call');
            r = W.commit();
            testCase.verifyEqual(testCase.cloud.fileBytes(locs(2).uid), bytes{locs(2).index});
            testCase.verifyEqual(testCase.cloud.singleUploads, 0, 'nothing sent one by one');
            testCase.verifyEqual(r.resent, 0);
        end

        function testAFailedBackgroundSendIsSentOneByOne(testCase)
            testCase.cloud.FailSends = true;
            W = testCase.writer();
            [d, bytes] = testCase.seriesDoc(W, testCase.subjectId, 3);
            W.database_add(d);
            locs = d.document_properties.files.series_info(1).ingest_locations;
            for i = 1:numel(locs)
                testCase.verifyEqual(testCase.cloud.fileBytes(locs(i).uid), bytes{locs(i).index});
            end
            testCase.verifyEqual(testCase.cloud.singleUploads, 4, ...
                'the three members and the manifest, each sent again on its own');
            r = W.commit();
            testCase.verifyEqual(r.resent, 4);
        end

        function testFilesCurlDidNotSendAreResentAtOnce(testCase)
            % curl names the files it could not send: those are sent again
            % straight away, without waiting out the cloud check for them.
            testCase.cloud.FailFirstSends = 1;
            W = testCase.writer();
            [d, bytes] = testCase.seriesDoc(W, testCase.subjectId, 3);
            W.database_add(d);
            locs = d.document_properties.files.series_info(1).ingest_locations;
            for i = 1:numel(locs)
                testCase.verifyEqual(testCase.cloud.fileBytes(locs(i).uid), bytes{locs(i).index});
            end
            testCase.verifyEqual(testCase.cloud.singleUploads, 1, 'only the one curl named');
            testCase.verifyEqual(W.commit().resent, 1);
        end

        function testOneParallelUploadSendsOneByOne(testCase)
            W = testCase.writer('ParallelUploads', 1);
            [d, ~] = testCase.seriesDoc(W, testCase.subjectId, 3);
            W.database_add(d);
            testCase.verifyEqual(testCase.cloud.backgroundSends, 0);
            testCase.verifyEqual(testCase.cloud.singleUploads, 4);
        end

        function testParallelUploadsComesFromThePreference(testCase)
            name = 'Cloud.Upload.Parallel_Uploads';
            was = ndi.preferences.get(name);
            testCase.addTeardown(@() ndi.preferences.set(name, was));
            ndi.preferences.set(name, 1);
            W = testCase.writer();
            [d, ~] = testCase.seriesDoc(W, testCase.subjectId, 3);
            W.database_add(d);
            testCase.verifyEqual(testCase.cloud.backgroundSends, 0, ...
                'the preference''s 1 means one by one');
            testCase.verifyEqual(testCase.cloud.singleUploads, 4);
        end

        function testTheBatchsUploadURLsComeAtOnce(testCase)
            W = testCase.writer();
            [d, ~] = testCase.seriesDoc(W, testCase.subjectId, 3);
            W.database_add(d);
            testCase.verifyEqual(testCase.cloud.urlBatches, 1, 'one request for all four');
            testCase.verifyGreaterThanOrEqual(W.timing.urls, 0);
        end

        function testABatchCanGoAsOneZip(testCase)
            testCase.cloud.DeferSends = true;
            W = testCase.writer('ZipBatches', true);
            [d, bytes] = testCase.seriesDoc(W, testCase.subjectId, 2);
            W.declare(d);
            locs = d.document_properties.files.series_info(1).ingest_locations;
            zipsBefore = testCase.cloud.zipSends;
            W.streamMembers(d, 'chunk.bin', [locs.index], {locs.location});
            testCase.verifyEqual(testCase.cloud.zipSends, zipsBefore + 1, 'the two chunks, one zip');
            testCase.verifyFalse(testCase.cloud.hasFile(locs(1).uid), 'still going up');
            W.commit();
            for i = 1:numel(locs)
                testCase.verifyEqual(testCase.cloud.fileBytes(locs(i).uid), bytes{locs(i).index});
            end
            testCase.verifyEqual(testCase.cloud.singleUploads, 0);
        end

        function testAStoredZipHoldsTheFilesUnderTheirNames(testCase)
            folder = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
            a = fullfile(folder, 'a.bin'); b = fullfile(folder, 'b.bin');
            fid = fopen(a, 'w'); fwrite(fid, zeros(1, 10000, 'uint8')); fclose(fid);
            fid = fopen(b, 'w'); fwrite(fid, uint8(200:-1:1)); fclose(fid);
            z = fullfile(folder, 'batch.zip');
            ndi.cloud.upload.SessionWriter.writeStoredZip(z, {a, b}, {'uid_a', 'uid_b'});
            out = fullfile(folder, 'out');
            names = unzip(z, out);
            testCase.verifyEqual(sort(cellfun(@(p) char(p(numel(out)+2:end)), names, ...
                'UniformOutput', false)), {'uid_a', 'uid_b'});
            testCase.verifyEqual(readBytes(fullfile(out, 'uid_a')), zeros(10000, 1, 'uint8'));
            testCase.verifyEqual(readBytes(fullfile(out, 'uid_b')), uint8(200:-1:1)');
            d = dir(z);
            testCase.verifyGreaterThan(d.bytes, 10200, ...
                'stored, not deflated (10000 zeros would deflate to almost nothing)');
        end

        % -- riding out failures ------------------------------------------

        function testAFailingLookupIsRetried(testCase)
            W = ndi.cloud.upload.SessionWriter(testCase.cloud.DatasetId, ...
                testCase.sessionId, 'Api', testCase.cloud.api(), ...
                'Verbose', false, 'RetrySeconds', 30);
            [d, bytes] = testCase.seriesDoc(W, testCase.subjectId, 2);
            testCase.cloud.FailLookups = 2;
            W.database_add(d);   % would error without the retries
            locs = d.document_properties.files.series_info(1).ingest_locations;
            testCase.verifyEqual(testCase.cloud.fileBytes(locs(1).uid), bytes{locs(1).index});
            testCase.verifyEqual(testCase.cloud.FailLookups, 0);
        end

        function testALostAddReplyMakesNoDuplicate(testCase)
            W = ndi.cloud.upload.SessionWriter(testCase.cloud.DatasetId, ...
                testCase.sessionId, 'Api', testCase.cloud.api(), ...
                'Verbose', false, 'RetrySeconds', 30);
            d = W.newdocument('base', 'base.name', 'once');
            testCase.cloud.LoseAddReply = true;
            W.declare(d);
            found = testCase.cloud.findDocuments('', ndi.query('base.id', 'exact_string', d.id()));
            testCase.verifyNumElements(found, 1, ...
                'the retry asks whether the document arrived before sending it again');
        end

        function testAdoptAndMissingMembersForAResume(testCase)
            W = testCase.writer();
            [d, ~] = testCase.seriesDoc(W, testCase.subjectId, 3);
            W.declare(d);
            locs = d.document_properties.files.series_info(1).ingest_locations;
            W.streamMembers(d, 'chunk.bin', locs(2).index, {locs(2).location});
            W.streamMembers(d, 'chunk.bin', [], {});
            % A new writer, as after a restart: the document is adopted, not re-sent.
            W2 = testCase.writer();
            W2.adopt(d);
            missing = W2.missingMembers(d, 'chunk.bin');
            testCase.verifyEqual(sort(missing), sort([locs([1 3]).index]));
            W2.streamMembers(d, 'chunk.bin', [locs([1 3]).index], {locs([1 3]).location});
            W2.commit();
            testCase.verifyNumElements(testCase.cloud.docsOfClass('lightsheetZarrLevel'), 1, ...
                'adopting does not upload the document again');
        end

        function testOnUploadSeesEachDocument(testCase)
            seen = {};
            function record(doc)
                seen{end+1} = doc.id();
            end
            W = testCase.writer('OnUpload', @record);
            a = W.newdocument('base');
            b = W.newdocument('base');
            W.database_add(a);
            W.declare(b);
            testCase.verifyEqual(seen, {a.id(), b.id()}, ...
                'held documents go up before a declared one, and each is reported');
        end

        function testTheSessionLabelsNameReferenceAndId(testCase)
            s = struct('session_id', {'id1', 'id2'}, 'session_reference', {'a', 'b'});
            testCase.verifyEqual(ndi.gui.app.LightsheetManager.sessionLabels(s), ...
                {'a  (id1)', 'b  (id2)'});
        end
    end

    methods
        function W = writer(testCase, varargin)
            % No retries: these tests inject failures and want them at once.
            W = ndi.cloud.upload.SessionWriter(testCase.cloud.DatasetId, ...
                testCase.sessionId, 'Api', testCase.cloud.api(), ...
                'Verbose', false, 'RetrySeconds', 0, 'ZipBatches', false, varargin{:});
        end

        function [d, bytes] = seriesDoc(testCase, W, subjectId, n)
        % A lightsheetZarrLevel with an N-member chunk.bin series of random bytes.
            src = tempname;
            mkdir(src);
            testCase.addTeardown(@() rmdirIfThere(src));
            paths = cell(1, n);
            bytes = cell(1, n);
            for i = 1:n
                bytes{i} = uint8(randi([0 255], 100 + i, 1));
                paths{i} = fullfile(src, sprintf('chunk_%d', i));
                fid = fopen(paths{i}, 'w');
                fwrite(fid, bytes{i});
                fclose(fid);
            end
            d = W.newdocument('lightsheetZarrLevel');
            d = d.set_dependency_value('subject_id', subjectId);
            d = d.addFileSeries('chunk.bin', paths);
        end
    end
end

function b = readBytes(p)
    fid = fopen(p, 'r');
    b = fread(fid, Inf, '*uint8');
    fclose(fid);
end

function rmdirIfThere(d)
    if isfolder(d)
        rmdir(d, 's');
    end
end
