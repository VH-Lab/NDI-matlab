classdef TestLightsheetToCloudJob < matlab.unittest.TestCase
    % TestLightsheetToCloudJob - a streamed cloud build paused partway, then resumed.
    %
    % The job builds the blob OME-Zarr fixture into a fake cloud session
    % (ndi.test.helper.FakeCloudDataset) with chunks and reads small enough
    % that level 0 takes many super-blocks, is paused partway through it,
    % and is resumed from a fresh load of its job file, as a later MATLAB
    % would. The result must be one pyramid, each level once, every chunk
    % byte-identical to an ordinary local ingest, and the "(uploading)"
    % label gone. Filters when NDR is not on the path.
    %
    % Authored without a local MATLAB runtime; needs MATLAB to validate/run.

    properties
        zarrPath
        cloud
        choices
    end

    methods (TestMethodSetup)
        function build(testCase)
            if isempty(which('ndr.format.omezarr.listPyramids'))
                testCase.assumeFail('NDR reader not on path.');
            end
            import matlab.unittest.fixtures.TemporaryFolderFixture
            import matlab.unittest.fixtures.EnvironmentVariableFixture
            jobs = testCase.applyFixture(TemporaryFolderFixture);
            testCase.applyFixture(EnvironmentVariableFixture('NDI_JOBS_DIR', jobs.Folder));
            parent = testCase.applyFixture(TemporaryFolderFixture).Folder;
            testCase.zarrPath = ndi.test.lightsheet.makeBlobFixture(parent, ...
                'Shape', [32 32 32], 'NumChannels', 1, 'NumLevels', 2, ...
                'ChunkShape', [16 16 16]);

            testCase.cloud = ndi.test.helper.FakeCloudDataset();
            sid = testCase.cloud.addSession('exp1');
            c = ndi.gui.app.LightsheetManager.addChoices();
            c.destination = 'cloud';
            c.datasetId = testCase.cloud.DatasetId;
            c.datasetName = 'fake';
            c.sessionId = sid;
            c.sessionReference = 'exp1';
            c.subjectID = testCase.cloud.addSubject(sid, 'blob@vhlab');
            c.subjectName = 'blob@vhlab';
            c.sourcePath = testCase.zarrPath;
            c.sourceKind = 'omezarr';
            c.label = 'blob';
            c.numWorkers = 1;
            testCase.choices = c;
        end
    end

    methods (Test)

        function testPausedPartwayThenResumed(testCase)
            small = {'chunks', [8 8 8], 'prefetchBytes', 4 * 8^3 * 2};

            job = ndi.job.LightsheetToCloud.create(testCase.choices);
            job.Api = testCase.cloud.api();
            job.ExtraIngestArgs = small;
            job.PauseAfterBeats = 6;    % level 0 has 16 super-blocks
            job.run();
            testCase.assertEqual(job.state, 'paused', job.lastError);

            pyr = testCase.cloud.docsOfClass('lightsheetZarrPyramid');
            testCase.verifyNumElements(pyr, 1, 'the pyramid goes up before its chunks');
            testCase.verifySubstring(pyr{1}.lightsheetZarrPyramid.label, '(uploading)');

            % A later MATLAB: load the job from its file and resume.
            again = ndi.job.Job.load(job.id);
            again.Api = testCase.cloud.api();
            again.ExtraIngestArgs = small;
            again.run();
            testCase.assertEqual(again.state, 'done', again.lastError);

            pyr = testCase.cloud.docsOfClass('lightsheetZarrPyramid');
            testCase.verifyNumElements(pyr, 1, 'resuming does not make a second pyramid');
            testCase.verifyEqual(pyr{1}.lightsheetZarrPyramid.label, 'blob');
            levels = testCase.cloud.docsOfClass('lightsheetZarrLevel');

            % Reference: the same store, ingested locally in one go.
            d = fullfile(tempname, 'reference');
            mkdir(d);
            testCase.addTeardown(@() rmdir(fileparts(d), 's'));
            S = ndi.session.dir('reference', d);
            sub = ndi.document('subject', 'base.session_id', S.id(), ...
                'subject.local_identifier', 'blob@vhlab');
            S.database_add(sub);
            [~, Lloc] = ndi.fun.doc.lightsheet.fromOMEZarr(S, testCase.zarrPath, ...
                'subjectID', sub.id(), 'progressFcn', [], 'numWorkers', 0, ...
                'codec', 'blosc-zstd', 'clevel', testCase.choices.clevel, ...
                'materializeChunks', true, small{:});
            testCase.verifyNumElements(levels, numel(Lloc), 'each level once');

            % Every chunk, against the reference, through the uids the job
            % recorded for each declared level.
            saved = dir(fullfile(again.folder(), 'documents', '*.json'));
            nCompared = 0;
            for k = 1:numel(saved)
                props = jsondecode(fileread(fullfile(saved(k).folder, saved(k).name)));
                if ~strcmp(props.document_class.class_name, 'lightsheetZarrLevel'), continue; end
                lp = props.lightsheetZarrLevel;
                ref = Lloc{cellfun(@(x) ...
                    x.document_properties.lightsheetZarrLevel.level == lp.level && ...
                    strcmp(x.document_properties.lightsheetZarrLevel.reduction_function, ...
                        lp.reduction_function), Lloc)};
                locs = props.files.series_info(1).ingest_locations;
                for m = 1:numel(locs)
                    f = S.database_openbinarydoc(ref, sprintf('chunk.bin_%d', locs(m).index));
                    expected = readBytes(f.fullpathfilename);
                    S.database_closebinarydoc(f);
                    testCase.verifyEqual(testCase.cloud.fileBytes(locs(m).uid), expected, ...
                        sprintf('level %d (%s) chunk %d', lp.level, lp.reduction_function, locs(m).index));
                    nCompared = nCompared + 1;
                end
            end
            testCase.verifyGreaterThan(nCompared, 60);
            testCase.verifyFalse(isfolder(fullfile(again.folder(), 'cache')), ...
                'a finished job clears its cache');
        end
    end
end

function b = readBytes(p)
    fid = fopen(p, 'r');
    b = fread(fid, Inf, '*uint8');
    fclose(fid);
end
