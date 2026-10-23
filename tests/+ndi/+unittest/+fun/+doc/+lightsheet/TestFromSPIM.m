classdef TestFromSPIM < matlab.unittest.TestCase
    % TestFromSPIM - lightsheet pyramid built straight from SmartSPIM All_Channels.
    %
    % Runs on NDR's SmartSPIM fixture with 'AllChannels', true: two
    % channels (ch0 = Ex_561_Em_561F_Ch2, ch1 = Ex_640_Em_640F_Ch3), four
    % 106x13 uint16 slices each, every pixel of slice z (0-based) in
    % channel k equal to 1000*(k+1) + z -- so 1-based slice z holds
    % 1000*(k+1) + z - 1. Constant slices make every level's expected
    % values easy to state.

    properties
        session
        subjectID
        root
    end

    methods (TestClassSetup)
        function needNdrSmartSpim(testCase)
            testCase.assumeTrue(~isempty(which('ndr.format.smartspim.readAllChannelsInfo')), ...
                'NDR-matlab with ndr.format.smartspim All_Channels support is not on the path.');
        end
    end

    methods (TestMethodSetup)
        function build(testCase)
            d = fullfile(tempname, 'fromspim');
            mkdir(d);
            testCase.addTeardown(@() rmdir(fileparts(d), 's'));
            S = ndi.session.dir('fromspim', d);
            sub = ndi.document('subject', 'base.session_id', S.id(), ...
                'subject.local_identifier', 'ferret@vhlab');
            S.database_add(sub);
            testCase.session = S;
            testCase.subjectID = sub.id();
            testCase.root = ndr.test.format.smartspim.makeExampleFixture( ...
                fullfile(fileparts(d), 'spim'), 'AllChannels', true);
        end
    end

    methods
        function [P, L, info] = ingest(testCase, varargin)
            arguments
                testCase (1,1) ndi.unittest.fun.doc.lightsheet.TestFromSPIM
            end
            arguments (Repeating)
                varargin
            end
            [P, L, info] = ndi.fun.doc.lightsheet.fromSPIM(testCase.session, ...
                testCase.root, 'subjectID', testCase.subjectID, ...
                'voxelSizeUm', [1 1 1], 'minLevelSize', 8, ...
                'chunks', [1 1 2 32 8], 'progressFcn', [], ...
                'numWorkers', 0, varargin{:});
        end

        function vol = readLevel(testCase, levelDoc)
            % Independent read-back: every stored chunk, decoded and placed.
            arguments
                testCase (1,1) ndi.unittest.fun.doc.lightsheet.TestFromSPIM
                levelDoc (1,1) ndi.document
            end
            p = levelDoc.document_properties.lightsheetZarrLevel;
            shape = double(p.shape(:).');
            chunks = double(p.chunks(:).');
            grid = double(p.chunk_grid(:).');
            vol = zeros(shape, p.dtype);
            nd = numel(shape);
            for i = 1:prod(grid)
                rem = i - 1;
                c = zeros(1, nd);
                for a = 1:nd
                    stride = prod(grid(a+1:end));
                    c(a) = floor(rem / stride) + 1;
                    rem = mod(rem, stride);
                end
                f = testCase.session.database_openbinarydoc(levelDoc, sprintf('chunk.bin_%d', i));
                fid = fopen(f.fullpathfilename, 'r');
                raw = fread(fid, Inf, '*uint8');
                fclose(fid);
                testCase.session.database_closebinarydoc(f);
                if strcmp(p.codec, 'blosc-zstd')
                    raw = ndr.format.blosc.decode(raw);
                end
                tile = permute(reshape(typecast(raw(:), p.dtype), fliplr(chunks)), nd:-1:1);
                lo = (c - 1) .* chunks + 1;
                hi = min(c .* chunks, shape);
                dst = arrayfun(@(a) lo(a):hi(a), 1:nd, 'UniformOutput', false);
                src = arrayfun(@(a) 1:(hi(a) - lo(a) + 1), 1:nd, 'UniformOutput', false);
                vol(dst{:}) = tile(src{:});
            end
        end

        function L = levelsOf(testCase, levelDocs, reduction)
            arguments
                testCase (1,1) ndi.unittest.fun.doc.lightsheet.TestFromSPIM %#ok<INUSA> selection reads only levelDocs
                levelDocs cell
                reduction {mustBeText}
            end
            keep = cellfun(@(d) any(strcmp(d.document_properties.lightsheetZarrLevel.reduction_function, ...
                {reduction, 'none'})), levelDocs);
            L = levelDocs(keep);
            lv = cellfun(@(d) d.document_properties.lightsheetZarrLevel.level, L);
            [~, order] = sort(lv);
            L = L(order);
        end
    end

    methods (Test)

        function testParentDescribesTheStitchedVolume(testCase)
            P = testCase.ingest();
            p = P.document_properties.lightsheetZarrPyramid;
            testCase.verifyEqual(p.axes_order, 'tczyx');
            testCase.verifyEqual(double(p.shape_level0(:).'), [1 2 4 106 13]);
            testCase.verifyEqual(p.n_channels, 2);
            testCase.verifyEqual(p.channel_names, 'Ex_561_Em_561F_Ch2,Ex_640_Em_640F_Ch3');
            testCase.verifyEqual(p.dtype, 'uint16');
        end

        function testLevelZeroIsTheAllChannelsData(testCase)
            [~, L] = testCase.ingest();
            l0 = testCase.levelsOf(L, 'mean');
            p0 = l0{1}.document_properties.lightsheetZarrLevel;
            testCase.verifyEqual(p0.reduction_function, 'none');
            vol = testCase.readLevel(l0{1});
            for k = 0:1
                for z = 1:4
                    plane = squeeze(vol(1, k + 1, z, :, :));
                    testCase.verifyTrue(all(plane(:) == 1000 * (k + 1) + z - 1), ...
                        sprintf('ch%d z=%d', k, z));
                end
            end
        end

        function testMeanAndMaxLaddersShareLevelZero(testCase)
            [~, L, info] = testCase.ingest();
            testCase.verifyTrue(info.sharedLevel0);
            reds = cellfun(@(d) d.document_properties.lightsheetZarrLevel.reduction_function, ...
                L, 'UniformOutput', false);
            testCase.verifyEqual(sum(strcmp(reds, 'none')), 1);
            testCase.verifyEqual(sum(strcmp(reds, 'mean')), sum(strcmp(reds, 'max')));
            testCase.verifyGreaterThan(sum(strcmp(reds, 'mean')), 0);
        end

        function testLevelOneMeanAndMax(testCase)
            [~, L] = testCase.ingest();
            for red = {'mean', 'max'}
                lv = testCase.levelsOf(L, red{1});
                p1 = lv{2}.document_properties.lightsheetZarrLevel;
                testCase.verifyEqual(double(p1.shape(:).'), [1 2 2 53 7]);
                testCase.verifyEqual(double(p1.voxel_size(:).'), [1 1 2 2 2]);
                vol = testCase.readLevel(lv{2});
                for k = 0:1
                    base = 1000 * (k + 1);
                    % Slices hold base + 0..3. Mean of {0,1} = 0.5 and of
                    % {2,3} = 2.5 round half away from zero to 1 and 3;
                    % max gives 1 and 3 too.
                    expect = base + [1 3];
                    for z = 1:2
                        plane = squeeze(vol(1, k + 1, z, :, :));
                        testCase.verifyTrue(all(plane(:) == expect(z)), ...
                            sprintf('%s ch%d z=%d', red{1}, k, z));
                    end
                end
            end
        end

        function testLadderStopsAtMinLevelSize(testCase)
            [~, ~, info] = testCase.ingest();
            meanLevels = info.levels(strcmp({info.levels.reduction}, 'mean'));
            last = meanLevels(end).shape;
            testCase.verifyLessThanOrEqual(max(last(3:5)), 8);
            % 106 -> 53 -> 27 -> 14 -> 7 along y.
            testCase.verifyEqual(numel(meanLevels), 4);
        end

        function testAnisotropicZIsNotHalvedFirst(testCase)
            [~, ~, info] = testCase.ingest('voxelSizeUm', [4 1 1]);
            first = info.levels(find(strcmp({info.levels.reduction}, 'mean'), 1));
            testCase.verifyEqual(first.factor, [1 1 1 2 2]);
        end

        function testChannelSubsetAndOrder(testCase)
            P = testCase.ingest('channels', {'Ex_640_Em_640F_Ch3'});
            p = P.document_properties.lightsheetZarrPyramid;
            testCase.verifyEqual(p.n_channels, 1);
            testCase.verifyEqual(p.channel_names, 'Ex_640_Em_640F_Ch3');
        end

        function testMeanOnlyLadder(testCase)
            [~, L] = testCase.ingest('reductions', {'mean'});
            reds = cellfun(@(d) d.document_properties.lightsheetZarrLevel.reduction_function, ...
                L, 'UniformOutput', false);
            testCase.verifyFalse(any(strcmp(reds, 'max')));
        end

        function testNoAllChannelsIsAClearError(testCase)
            plain = ndr.test.format.smartspim.makeExampleFixture( ...
                fullfile(tempname, 'plain'));
            testCase.addTeardown(@() rmdir(fileparts(plain), 's'));
            testCase.verifyError(@() ndi.fun.doc.lightsheet.fromSPIM( ...
                testCase.session, plain, 'subjectID', testCase.subjectID, ...
                'progressFcn', []), 'NDI:lightsheet:fromSPIM:noAllChannels');
        end

        function testSubjectIsRequired(testCase)
            testCase.verifyError(@() ndi.fun.doc.lightsheet.fromSPIM( ...
                testCase.session, testCase.root), 'NDI:lightsheet:fromSPIM:noSubject');
        end
    end
end
