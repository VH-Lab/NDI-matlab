classdef TestFromSPIMToCloud < matlab.unittest.TestCase
    % TestFromSPIMToCloud - fromSPIM streamed straight into a session of a cloud dataset.
    %
    % Streamed, level 0 is never kept on disk, so level 1 of each ladder
    % is reduced from the SmartSPIM slices themselves instead of from the
    % stored level 0. That must not change a single byte: every chunk the
    % fake cloud holds is compared with the same chunk of an ordinary local
    % fromSPIM ingest, which reduces level 1 from level 0. Uses NDR's
    % SmartSPIM fixture, as TestFromSPIM does, and filters without it.
    %
    % Authored without a local MATLAB runtime; needs MATLAB to validate/run.

    properties
        root
        cloud
        sessionId
        subjectId
    end

    methods (TestClassSetup)
        function needNdrSmartSpim(testCase)
            testCase.assumeTrue(~isempty(which('ndr.format.smartspim.readAllChannelsInfo')), ...
                'NDR-matlab with ndr.format.smartspim All_Channels support is not on the path.');
        end
    end

    methods (TestMethodSetup)
        function build(testCase)
            parent = tempname;
            mkdir(parent);
            testCase.addTeardown(@() rmdir(parent, 's'));
            testCase.root = ndr.test.format.smartspim.makeExampleFixture( ...
                fullfile(parent, 'spim'), 'AllChannels', true);
            testCase.cloud = ndi.test.helper.FakeCloudDataset();
            testCase.sessionId = testCase.cloud.addSession('exp1');
            testCase.subjectId = testCase.cloud.addSubject(testCase.sessionId, 'ferret@vhlab');
        end
    end

    methods (Test)

        function testEveryChunkMatchesALocalIngest(testCase)
            % Level 1 of both ladders folded into level 0: one read of the slices.
            testCase.streamAndCompare({}, ...
                'is built during this level, from the same reads of the slices');
        end

        function testSlicesReadInSlabsGiveTheSameBytes(testCase)
            % The parallel read's split along z (on reduction-block
            % boundaries) and join, without a pool.
            testCase.streamAndCompare({'readWorkers', 3, 'splitReadsWithoutPool', true}, ...
                'is built during this level, from the same reads of the slices');
        end

        function testUnfoldedTheLadderLevelOnesAreBuiltTogether(testCase)
            % Without folding: both ladders' level 1 from one more read.
            testCase.streamAndCompare({'foldLevel1', false}, ...
                'is built with it, from the same reads of the slices');
        end
    end

    methods
        function streamAndCompare(testCase, extra, expectedMessage)
            args = {'voxelSizeUm', [1 1 1], 'minLevelSize', 8, ...
                'chunks', [1 1 2 32 8], 'progressFcn', [], 'numWorkers', 0};

            W = ndi.cloud.upload.SessionWriter(testCase.cloud.DatasetId, ...
                testCase.sessionId, 'Api', testCase.cloud.api(), 'Verbose', false);
            P = []; L = {}; info = []; %#ok<NASGU> set by evalc below
            out = evalc(['[P, L, info] = ndi.fun.doc.lightsheet.fromSPIM(W, testCase.root, ' ...
                '''subjectID'', testCase.subjectId, args{:}, extra{:});']);
            testCase.verifySubstring(out, expectedMessage);
            testCase.verifyEqual(info.cloud.documents, 2 + numel(L));
            testCase.assertGreaterThan(numel(L), 2, ...
                'the fixture must give a ladder with a level 1 and below');

            pyr = testCase.cloud.docsOfClass('lightsheetZarrPyramid');
            testCase.verifyNumElements(pyr, 1);
            testCase.verifyEqual(pyr{1}.base.id, P.id());
            testCase.verifyFalse(contains(pyr{1}.lightsheetZarrPyramid.label, 'uploading'), ...
                'the "(uploading)" label is replaced once every chunk is in');

            d = fullfile(tempname, 'reference');
            mkdir(d);
            testCase.addTeardown(@() rmdir(fileparts(d), 's'));
            S = ndi.session.dir('reference', d);
            sub = ndi.document('subject', 'base.session_id', S.id(), ...
                'subject.local_identifier', 'ferret@vhlab');
            S.database_add(sub);
            [~, Lloc] = ndi.fun.doc.lightsheet.fromSPIM(S, testCase.root, ...
                'subjectID', sub.id(), args{:});

            nCompared = 0;
            for k = 1:numel(L)
                lp = L{k}.document_properties.lightsheetZarrLevel;
                match = cellfun(@(x) ...
                    x.document_properties.lightsheetZarrLevel.level == lp.level && ...
                    strcmp(x.document_properties.lightsheetZarrLevel.reduction_function, ...
                        lp.reduction_function), Lloc);
                testCase.assertEqual(nnz(match), 1);
                members = L{k}.document_properties.files.series_info(1).ingest_locations;
                testCase.verifyNumElements(members, prod(double(lp.chunk_grid)));
                for m = 1:numel(members)
                    f = S.database_openbinarydoc(Lloc{match}, ...
                        sprintf('chunk.bin_%d', members(m).index));
                    expected = readBytes(f.fullpathfilename);
                    S.database_closebinarydoc(f);
                    testCase.verifyEqual(testCase.cloud.fileBytes(members(m).uid), expected, ...
                        sprintf('level %d (%s) chunk %d', lp.level, ...
                            lp.reduction_function, members(m).index));
                    nCompared = nCompared + 1;
                end
            end
            testCase.verifyGreaterThan(nCompared, 0);
        end
    end
end

function b = readBytes(p)
    fid = fopen(p, 'r');
    b = fread(fid, Inf, '*uint8');
    fclose(fid);
end
