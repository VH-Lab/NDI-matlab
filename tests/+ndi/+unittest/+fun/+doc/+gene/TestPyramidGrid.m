classdef TestPyramidGrid < matlab.unittest.TestCase
% TESTPYRAMIDGRID - the tile grid is sized from the data, and reported
%
%   makePyramid used to tile every section 9x9. A grid is a fixed FRACTION
%   of the extent, so the same 9x9 that gives a mouse section 20 MB tiles
%   gave a ferret hemisphere 257 MB ones -- measured, on a real file. The
%   default is now [], which picks the grid from where the records
%   actually are, against a per-tile byte budget.
%
%   What is worth holding here is the CONTRACT, not the particular number:
%   a denser section gets a finer grid than a sparse one of the same
%   extent, the bounds are respected, an explicit grid still wins, and the
%   pyramid document records whatever was chosen so a reader never has to
%   guess. The exact grid depends on an estimate of tile bytes and is
%   allowed to move.
%
%   See also: ndi.fun.doc.gene.makePyramid

    properties
        session
        testDir
        subjectID
        geneList
    end

    methods (TestClassSetup)
        function setupOnce(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            fixture = testCase.applyFixture(TemporaryFolderFixture);
            testCase.testDir = fullfile(fixture.Folder, 'gene_pyrgrid');
            if ~isfolder(testCase.testDir), mkdir(testCase.testDir); end
            ndi.test.helper.initializeMksqliteNoOutput()
            testCase.session = ndi.session.dir('gene_pg', testCase.testDir);

            sub = ndi.document('subject', 'base.session_id', testCase.session.id(), ...
                'subject.local_identifier', 'pyrgrid_subject@vhlab');
            testCase.session.database_add(sub);
            testCase.subjectID = sub.id();

            ids = arrayfun(@(k) sprintf('ENSG%04d',k), 1:8, 'UniformOutput', false);
            nm  = arrayfun(@(k) sprintf('g%d',k), 1:8, 'UniformOutput', false);
            testCase.geneList = ndi.fun.doc.gene.makeGeneList( ...
                testCase.session, ids, nm);
        end
    end

    methods (Access = private)
        function [x, y, gi, c] = records(~, nPix, span)
            % nPix pixels spread over a SPAN x SPAN box, 8 genes each.
            [px, py] = meshgrid(round(linspace(0, span-1, nPix)));
            x = repmat(px(:), 8, 1);
            y = repmat(py(:), 8, 1);
            gi = repelem((0:7)', numel(px), 1);
            c = ones(size(x));
        end

        function p = pyrProps(~, doc)
            p = doc.document_properties.spatialGeneExpressionPyramid;
        end
    end

    methods (Test)

        function testAutoGridIsUsedByDefault(testCase)
            % No 'grid', so it is chosen. It must land inside gridRange and
            % be recorded on the document, because that is where every
            % reader (readViewport, exportRegion, levelTable) gets it from.
            [x, y, gi, c] = testCase.records(40, 4000);
            pyr = ndi.fun.doc.gene.makePyramid(testCase.session, x, y, gi, c, ...
                testCase.geneList, 'binSizes', 1, ...
                'subjectID', testCase.subjectID);
            p = testCase.pyrProps(pyr);
            testCase.verifyGreaterThanOrEqual(p.tile_rows, 3);
            testCase.verifyLessThanOrEqual(p.tile_rows, 64);
            testCase.verifyEqual(p.tile_rows, p.tile_columns, ...
                'The grid is square; readViewport reads tile_rows and tile_columns separately.');
        end

        function testDenserSectionGetsAFinerGrid(testCase)
            % THE POINT OF THE CHANGE. Same extent, more records, so the
            % tiles a fixed grid would produce are bigger and the grid has
            % to be finer to hold the same byte budget. A fixed 9x9 gives
            % these two the same answer, which is the bug.
            [x1, y1, g1, c1] = testCase.records(20, 4000);
            [x2, y2, g2, c2] = testCase.records(120, 4000);
            budget = 12 * 1024;     % small, so both sides of it are reachable
            sparse_ = ndi.fun.doc.gene.makePyramid(testCase.session, ...
                x1, y1, g1, c1, testCase.geneList, 'binSizes', 1, ...
                'tileBudgetBytes', budget, 'subjectID', testCase.subjectID);
            dense = ndi.fun.doc.gene.makePyramid(testCase.session, ...
                x2, y2, g2, c2, testCase.geneList, 'binSizes', 1, ...
                'tileBudgetBytes', budget, 'subjectID', testCase.subjectID);
            testCase.verifyGreaterThan(testCase.pyrProps(dense).tile_rows, ...
                testCase.pyrProps(sparse_).tile_rows, ...
                'A denser section of the same extent must be tiled more finely.');
        end

        function testGridRangeIsRespected(testCase)
            % An impossible budget must clamp at the top of the range
            % rather than run the grid away: every extra row of the grid is
            % another 2*GRID+1 files per level to write and upload.
            [x, y, gi, c] = testCase.records(60, 4000);
            pyr = ndi.fun.doc.gene.makePyramid(testCase.session, x, y, gi, c, ...
                testCase.geneList, 'binSizes', 1, 'tileBudgetBytes', 1, ...
                'gridRange', [2 5], 'subjectID', testCase.subjectID);
            testCase.verifyEqual(testCase.pyrProps(pyr).tile_rows, 5);
        end

        function testExplicitGridStillWins(testCase)
            [x, y, gi, c] = testCase.records(40, 4000);
            pyr = ndi.fun.doc.gene.makePyramid(testCase.session, x, y, gi, c, ...
                testCase.geneList, 'binSizes', 1, 'grid', 7, ...
                'subjectID', testCase.subjectID);
            testCase.verifyEqual(testCase.pyrProps(pyr).tile_rows, 7);
        end

        function testBadExplicitGridIsRejected(testCase)
            [x, y, gi, c] = testCase.records(10, 1000);
            f = @(g) ndi.fun.doc.gene.makePyramid(testCase.session, ...
                x, y, gi, c, testCase.geneList, 'binSizes', 1, 'grid', g, ...
                'subjectID', testCase.subjectID);
            testCase.verifyError(@() f(2.5), 'NDI:gene:makePyramid:badGrid');
            testCase.verifyError(@() f(0), 'NDI:gene:makePyramid:badGrid');
            testCase.verifyError(@() f([2 3]), 'NDI:gene:makePyramid:badGrid');
        end

        function testProgressReportsWithinTheBuild(testCase)
            % The pyramid is the slow half of an ingest and used to report
            % only at its ends, so minutes of it looked like a hang. Every
            % level, and every tile within a level, must report -- and the
            % fractions must stay inside [0 1] and never go backwards,
            % because a progress bar that jumps back reads as a bug.
            [x, y, gi, c] = testCase.records(20, 4000);
            fracs = []; texts = {};
            fcn = @recordTick;
            ndi.fun.doc.gene.makePyramid(testCase.session, x, y, gi, c, ...
                testCase.geneList, 'binSizes', [1 2], 'grid', 2, ...
                'subjectID', testCase.subjectID, 'progressFcn', fcn);

            testCase.verifyGreaterThan(numel(fracs), 4, ...
                'A two-level build must report more than its two endpoints.');
            testCase.verifyGreaterThanOrEqual(min(fracs), 0);
            testCase.verifyLessThanOrEqual(max(fracs), 1);
            testCase.verifyTrue(issorted(fracs), ...
                'Progress must not go backwards.');
            testCase.verifyTrue(any(contains(texts, 'Level 1 of 2')));
            testCase.verifyTrue(any(contains(texts, 'Level 2 of 2')));
            testCase.verifyTrue(any(contains(texts, 'tile row')), ...
                'A level reports its bands: they are where the minutes go.');

            function recordTick(f, t)
                fracs(end+1) = f; %#ok<AGROW>
                texts{end+1} = t; %#ok<AGROW>
            end
        end

        function testBandsPartitionTheRecords(testCase)
            % A level is now built ONE BAND OF TILE ROWS AT A TIME, so the
            % sort's working set is the section divided by the grid rather
            % than the whole section. Bands that overlapped would
            % double-count and bands that left a gap would drop records,
            % and neither would raise anything -- so the total is checked.
            % 8 genes over a 37x37 lattice, counts 1..N, tiled 5x5 so the
            % band bounds land mid-lattice rather than on it.
            [x, y, gi, ~] = testCase.records(37, 4000);
            c = (1:numel(x))';
            [~, tiles] = ndi.fun.doc.gene.makePyramid(testCase.session, ...
                x, y, gi, c, testCase.geneList, 'binSizes', [1 8], ...
                'grid', 5, 'subjectID', testCase.subjectID);
            for k = 1:numel(tiles)
                total = 0;
                d = tiles{k};
                stored = d.current_file_list();
                for j = 1:numel(stored)
                    if ~startsWith(stored{j}, 'tile.bin_'), continue; end
                    t = ndi.fun.doc.gene.readTileFile( ...
                        ndi.fun.doc.gene.tilePath(testCase.session, d, stored{j}));
                    total = total + sum(double(t.count));
                end
                testCase.verifyEqual(total, sum(c), ...
                    sprintf('Level %d lost or duplicated counts across its bands.', k));
            end
        end

        function testSilentWithNoProgressHandle(testCase)
            % The default has to stay silent: most callers have no display
            % and should not have to pass a do-nothing handle.
            [x, y, gi, c] = testCase.records(10, 1000);
            testCase.verifyWarningFree(@() ndi.fun.doc.gene.makePyramid( ...
                testCase.session, x, y, gi, c, testCase.geneList, ...
                'binSizes', 1, 'grid', 2, 'subjectID', testCase.subjectID));
        end

        function testIntegerTypedRecordsGiveTheSamePyramid(testCase)
            % fromGEF now passes the reader's own int32/uint16 arrays
            % straight through instead of promoting them to double, which
            % on a 7.7e8-record section is 14 GB held for the whole build.
            % The floor arithmetic must not become integer division on the
            % way: minX is forced to double for exactly this reason.
            [x, y, gi, c] = testCase.records(12, 3000);
            asDouble = ndi.fun.doc.gene.makePyramid(testCase.session, ...
                x, y, gi, c, testCase.geneList, 'binSizes', [1 4], 'grid', 3, ...
                'subjectID', testCase.subjectID);
            asNative = ndi.fun.doc.gene.makePyramid(testCase.session, ...
                int32(x), int32(y), int32(gi), uint16(c), testCase.geneList, ...
                'binSizes', [1 4], 'grid', 3, 'subjectID', testCase.subjectID);
            a = testCase.pyrProps(asDouble);
            b = testCase.pyrProps(asNative);
            testCase.verifyEqual([b.origin_x b.origin_y b.extent_x b.extent_y], ...
                [a.origin_x a.origin_y a.extent_x a.extent_y]);
            testCase.verifyEqual(class(b.origin_x), 'double', ...
                'The origin is written as a double whatever the records were.');
        end

    end
end
