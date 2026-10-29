classdef TestFromOMEZarrToCloud < matlab.unittest.TestCase
    % TestFromOMEZarrToCloud - fromOMEZarr straight into a session of a cloud dataset.
    %
    % The cloud is ndi.test.helper.FakeCloudDataset; what is checked is
    % that the documents land in the chosen session, depend on its
    % subject, and that every chunk the cloud holds is byte-identical to
    % the same chunk from an ordinary local ingest of the same store.
    % Filters when NDR is not on the path, as TestFromOMEZarr does.
    %
    % Authored without a local MATLAB runtime; needs MATLAB to validate/run.

    properties
        zarrPath
        cloud
        sessionId
        subjectId
    end

    methods (TestMethodSetup)
        function build(testCase)
            if isempty(which('ndr.format.omezarr.listPyramids'))
                testCase.assumeFail(['NDR reader not on path; skipping ' ...
                    'OME-Zarr cloud ingest tests.']);
            end
            parent = tempname;
            mkdir(parent);
            testCase.addTeardown(@() rmdir(parent, 's'));
            testCase.zarrPath = ndi.test.lightsheet.makeBlobFixture(parent, ...
                'Shape', [32 32 32], 'NumChannels', 1, ...
                'NumLevels', 2, 'ChunkShape', [16 16 16]);
            testCase.cloud = ndi.test.helper.FakeCloudDataset();
            testCase.sessionId = testCase.cloud.addSession('exp1');
            testCase.subjectId = testCase.cloud.addSubject(testCase.sessionId, 'blob@vhlab');
        end
    end

    methods (Test)

        function testDocumentsLandInTheSessionWithIdenticalChunks(testCase)
            W = testCase.writer();
            [P, L, info] = ndi.fun.doc.lightsheet.fromOMEZarr(W, testCase.zarrPath, ...
                'subjectID', testCase.subjectId, 'progressFcn', [], ...
                'numWorkers', 0, 'chunks', [8 8 8]);

            % source fileReference + pyramid + one per level
            testCase.verifyEqual(info.cloud.documents, 2 + numel(L));
            pyr = testCase.cloud.docsOfClass('lightsheetZarrPyramid');
            testCase.verifyNumElements(pyr, 1);
            testCase.verifyEqual(pyr{1}.base.id, P.id());
            levels = testCase.cloud.docsOfClass('lightsheetZarrLevel');
            testCase.verifyNumElements(levels, numel(L));
            for k = 1:numel(levels)
                testCase.verifyEqual(levels{k}.base.session_id, testCase.sessionId);
                lv = levels{k}.lightsheetZarrLevel;
                testCase.verifyEqual(double(lv.n_chunks_stored), prod(double(lv.chunk_grid)), ...
                    'a cloud target always materializes the chunks');
                deps = levels{k}.depends_on;
                subj = deps(strcmp({deps.name}, 'subject_id'));
                testCase.verifyEqual(subj.value, testCase.subjectId);
            end

            % The same store ingested locally is the reference.
            S = testCase.localSession();
            sub = ndi.document('subject', 'base.session_id', S.id(), ...
                'subject.local_identifier', 'blob@vhlab');
            S.database_add(sub);
            [~, Lloc] = ndi.fun.doc.lightsheet.fromOMEZarr(S, testCase.zarrPath, ...
                'subjectID', sub.id(), 'progressFcn', [], 'numWorkers', 0, ...
                'chunks', [8 8 8], 'materializeChunks', true);

            nCompared = 0;
            for k = 1:numel(L)
                lp = L{k}.document_properties.lightsheetZarrLevel;
                match = cellfun(@(x) ...
                    x.document_properties.lightsheetZarrLevel.level == lp.level && ...
                    strcmp(x.document_properties.lightsheetZarrLevel.reduction_function, ...
                        lp.reduction_function), Lloc);
                testCase.assertEqual(nnz(match), 1);
                localDoc = Lloc{match};
                members = L{k}.document_properties.files.series_info(1).ingest_locations;
                for m = 1:numel(members)
                    f = S.database_openbinarydoc(localDoc, ...
                        sprintf('chunk.bin_%d', members(m).index));
                    expected = readBytes(f.fullpathfilename);
                    S.database_closebinarydoc(f);
                    testCase.verifyEqual(testCase.cloud.fileBytes(members(m).uid), expected);
                    nCompared = nCompared + 1;
                end
            end
            testCase.verifyGreaterThan(nCompared, 8);
        end

        function testASubjectOfAnotherSessionIsRefusedBeforeAnyWork(testCase)
            other = testCase.cloud.addSession('exp2');
            elsewhere = testCase.cloud.addSubject(other, 'other@vhlab');
            W = testCase.writer();
            testCase.verifyError(@() ndi.fun.doc.lightsheet.fromOMEZarr(W, ...
                testCase.zarrPath, 'subjectID', elsewhere, 'progressFcn', []), ...
                'NDI:cloud:SessionWriter:subjectInOtherSession');
            testCase.verifyEqual(testCase.cloud.singleUploads + testCase.cloud.batchUploads, 0);
            testCase.verifyEmpty(testCase.cloud.addedJson);
        end
    end

    methods
        function W = writer(testCase)
            W = ndi.cloud.upload.SessionWriter(testCase.cloud.DatasetId, ...
                testCase.sessionId, 'Api', testCase.cloud.api(), 'Verbose', false);
        end

        function S = localSession(testCase)
            d = fullfile(tempname, 'reference');
            mkdir(d);
            testCase.addTeardown(@() rmdir(fileparts(d), 's'));
            S = ndi.session.dir('reference', d);
        end
    end
end

function b = readBytes(p)
    fid = fopen(p, 'r');
    b = fread(fid, Inf, '*uint8');
    fclose(fid);
end
