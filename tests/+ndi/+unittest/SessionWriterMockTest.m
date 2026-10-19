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

        function testTheSessionLabelsNameReferenceAndId(testCase)
            s = struct('session_id', {'id1', 'id2'}, 'session_reference', {'a', 'b'});
            testCase.verifyEqual(ndi.gui.app.LightsheetZarrManager.sessionLabels(s), ...
                {'a  (id1)', 'b  (id2)'});
        end
    end

    methods
        function W = writer(testCase, varargin)
            W = ndi.cloud.upload.SessionWriter(testCase.cloud.DatasetId, ...
                testCase.sessionId, 'Api', testCase.cloud.api(), ...
                'Verbose', false, varargin{:});
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
