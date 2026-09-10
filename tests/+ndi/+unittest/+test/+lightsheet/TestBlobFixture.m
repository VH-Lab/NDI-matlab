classdef TestBlobFixture < matlab.unittest.TestCase
    % TestBlobFixture - end-to-end fixture + ingest smoke.
    %
    % Small shapes are used here (32x32x32 by default rather than the
    % public 300x300x300 default) so the test fixture stays fast.
    % Everything still exercises the real path -- .zattrs and .zarray
    % on disk, raw chunk bytes, mean and max ladder writing, ingest
    % into a session, and the pyramid + level document round-trip.

    properties
        parentDir
        zarrPath
        gt
    end

    methods (TestMethodSetup)
        function build(testCase)
            testCase.parentDir = tempname;
            mkdir(testCase.parentDir);
            testCase.addTeardown(@() rmdir(testCase.parentDir, 's'));
            [testCase.zarrPath, testCase.gt] = ...
                ndi.test.lightsheet.makeBlobFixture(testCase.parentDir, ...
                    'Shape', [32 32 32], ...
                    'NumLevels', 3, ...
                    'ChunkShape', [16 16 16]);
        end
    end

    methods (Test)

        function testFixtureDirectoryLooksLikeAnOMEZarr(testCase)
            testCase.verifyTrue(isfolder(testCase.zarrPath));
            testCase.verifyTrue(isfile(fullfile(testCase.zarrPath, '.zattrs')));
            testCase.verifyTrue(isfile(fullfile(testCase.zarrPath, '0', '.zarray')));
        end

        function testZattrsCarriesTwoPyramidsWithSharedLevel0(testCase)
            attrs = jsondecode(fileread( ...
                fullfile(testCase.zarrPath, '.zattrs')));
            testCase.verifyTrue(isfield(attrs, 'multiscales'));
            % multiscales may deserialise as a struct array or cell.
            n = numel(attrs.multiscales);
            testCase.verifyEqual(n, 2);
            names = collectPyramidNames(attrs.multiscales);
            testCase.verifyEqual(sort(names), {'max','mean'});
            % Both mean[0] and max[0] point at '0'.
            firsts = collectFirstPaths(attrs.multiscales);
            testCase.verifyEqual(firsts, {'0','0'});
        end

        function testEachLevelHasZArrayAndChunkFiles(testCase)
            gtLevels = testCase.gt.levels;
            for k = 1:numel(gtLevels)
                levelDir = fullfile(testCase.zarrPath, gtLevels(k).path);
                testCase.verifyTrue(isfolder(levelDir), ...
                    sprintf('level dir missing: %s', gtLevels(k).path));
                testCase.verifyTrue(isfile(fullfile(levelDir, '.zarray')), ...
                    sprintf('.zarray missing: %s', gtLevels(k).path));
                % At least one chunk file present (name starts with a
                % digit, the Zarr v2 flat layout).
                listing = dir(levelDir);
                names = {listing.name};
                digits = '0123456789';
                nChunks = 0;
                for m = 1:numel(names)
                    nm = names{m};
                    if ~isempty(nm) && any(nm(1) == digits)
                        nChunks = nChunks + 1;
                    end
                end
                testCase.verifyGreaterThan(nChunks, 0, ...
                    sprintf('no chunk files in: %s', gtLevels(k).path));
            end
        end

        function testChunkFileSizeMatchesRawBytes(testCase)
            % Zarr v2 raw chunk: size = prod(chunks) * bytesPerElement,
            % edge chunks padded with 0 up to the same size.
            chunkShape = testCase.gt.chunkShape;
            expected = prod(chunkShape) * 2;   % uint16
            path = fullfile(testCase.zarrPath, '0', '0.0.0');
            testCase.verifyTrue(isfile(path));
            info = dir(path);
            testCase.verifyEqual(info.bytes, expected);
        end

        function testFromOMEZarrIngestsTheFixture(testCase)
            % `exist(pkg.fun, 'file')` returns 0 for package functions
            % even when they resolve, so guard on `which` instead.
            if isempty(which('ndr.format.omezarr.listPyramids'))
                testCase.assumeFail(['NDR reader not on path; skipping ' ...
                    'end-to-end ingest.']);
            end
            sDir = fullfile(tempname, 'blobsession');
            mkdir(sDir);
            testCase.addTeardown(@() rmdir(fileparts(sDir), 's'));
            S = ndi.session.dir('blob', sDir);
            sub = ndi.document('subject', 'base.session_id', S.id(), ...
                'subject.local_identifier', 'blob@vhlab');
            S.database_add(sub);

            [pdoc, lds, info] = ndi.fun.doc.lightsheet.fromOMEZarr( ...
                S, testCase.zarrPath, 'subjectID', sub.id());
            testCase.verifyTrue(info.sharedLevel0);
            % 3 levels * 2 reductions, deduped on level 0 -> 5 docs.
            testCase.verifyEqual(numel(lds), 5);
            % Parent describes the source volume, axes zyx.
            p = pdoc.document_properties.lightsheetZarrPyramid;
            testCase.verifyEqual(char(p.axes_order), 'zyx');
            testCase.verifyEqual(reshape(p.shape_level0, 1, []), [32 32 32]);
        end

        function testMaxKeepsBrightSpikeMeanDoesNot(testCase)
            % At the spike's downsampled position, max preserves the
            % 60k spike and mean dilutes it (averages the one spike
            % voxel with factor^3-1 darker neighbours). Verified on
            % the ground-truth ladder so the assertion is about the
            % downsampler, not the on-disk writer.
            L0 = testCase.gt.volumes.level0;
            spikePos = max(1, round(testCase.gt.shape / 6));
            % The wide Gaussian bleeds a fraction of a unit into the
            % spike voxel, so L0 rounds to 60000 or 60001; a >= check
            % holds either way, and 60000 is the sensible lower bound.
            testCase.verifyGreaterThanOrEqual( ...
                L0(spikePos(1), spikePos(2), spikePos(3)), uint16(60000));
            top = testCase.gt.numLevels;
            factor = 2^(top - 1);
            blk = floor((spikePos - 1) / factor) + 1;
            maxTop  = testCase.gt.volumes.max{top};
            meanTop = testCase.gt.volumes.mean{top};
            testCase.verifyGreaterThanOrEqual( ...
                maxTop(blk(1), blk(2), blk(3)), uint16(60000));
            testCase.verifyLessThan( ...
                double(meanTop(blk(1), blk(2), blk(3))), ...
                double(maxTop(blk(1), blk(2), blk(3))));
        end

    end
end

% ---------------------------------------------------------------------

function names = collectPyramidNames(ms)
    if iscell(ms)
        names = cellfun(@(e) char(e.name), ms, 'UniformOutput', false);
    else
        names = arrayfun(@(e) char(e.name), ms, 'UniformOutput', false);
    end
    names = names(:).';
end

function firsts = collectFirstPaths(ms)
    n = numel(ms);
    firsts = cell(1, n);
    for k = 1:n
        if iscell(ms)
            entry = ms{k};
        else
            entry = ms(k);
        end
        ds = entry.datasets;
        if iscell(ds)
            first = ds{1};
        else
            first = ds(1);
        end
        firsts{k} = char(first.path);
    end
end

