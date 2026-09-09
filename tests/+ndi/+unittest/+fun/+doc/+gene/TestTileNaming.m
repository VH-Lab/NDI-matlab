classdef TestTileNaming < matlab.unittest.TestCase
    % Tile files are named from ONE, because a DID file series is one-based.
    %
    % did.document/addFileSeries takes "ONE-BASED member numbers" and rejects
    % anything else -- "Member indices must be positive integers
    % (one-based)". makePyramid named its first tile tile.bin_0, putting
    % every pyramid one step outside the convention its storage layer
    % assumes.
    %
    % The consequence was not cosmetic. ndi.database.internal.list_binary_files
    % walked a legacy NAME# series as NAME1, NAME2, ... and treated the first
    % absent name as the end of the series, so a zero-based pyramid began at a
    % name the walk never probed.
    %
    % The tile INDEX stays zero-based: it is a grid position, defined by the
    % parent's index_order as row*tile_columns + column. Only the file SUFFIX
    % moved, and the document records which origin it used so that pyramids
    % built earlier keep opening.

    properties
        testDir
        session
        subjectID
        pyr
        tiles
    end

    methods (TestClassSetup)
        function setupOnce(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            fixture = testCase.applyFixture(TemporaryFolderFixture);
            testCase.testDir = fullfile(fixture.Folder, 'gene_tilenaming');
            if ~isfolder(testCase.testDir), mkdir(testCase.testDir); end
            ndi.test.helper.initializeMksqliteNoOutput()
            testCase.session = ndi.session.dir('gene_tn', testCase.testDir);

            sub = ndi.document('subject', 'base.session_id', testCase.session.id(), ...
                'subject.local_identifier', 'tilenaming_subject@vhlab');
            testCase.session.database_add(sub);
            testCase.subjectID = sub.id();

            ids = arrayfun(@(k) sprintf('ENSL%04d',k), 1:4, 'UniformOutput', false);
            gl = ndi.fun.doc.gene.makeGeneList(testCase.session, ids, {'a','b','c','d'});

            % Two occupied cells of a 2x2 grid, diagonally opposite, so the
            % stored series has a HOLE in it. That is the normal case: a tile
            % with no data in it is not written.
            ox = 1000; oy = 2000;
            x = [ox+0; ox+1; ox+30; ox+31];
            y = [oy+0; oy+1; oy+10; oy+11];
            [testCase.pyr, testCase.tiles] = ndi.fun.doc.gene.makePyramid( ...
                testCase.session, x, y, [0;1;2;3], [2;3;5;7], gl, ...
                'binSizes', 1, 'grid', 2, 'basePixelSize', [0.5 0.5], ...
                'subjectID', testCase.subjectID);
        end
    end

    methods (Access = private)
        function lv = levelProps(testCase)
            d = testCase.tiles;
            if iscell(d), d = d{1}; end
            lv = d.document_properties.spatialGeneExpressionTiles;
        end

        function names = storedTiles(testCase)
            d = testCase.tiles;
            if iscell(d), d = d{1}; end
            names = d.current_file_list();
            names = names(startsWith(names, 'tile.bin_'));
            names = sort(names);
        end
    end

    methods (Test)

        % ---------------- the name for an index ----------------

        function testTheFirstTileOfANewDocumentIsFileOne(testCase)
            lv = struct('tile_index_origin', 1);
            testCase.verifyEqual(ndi.fun.doc.gene.tileFileName(lv, 0), 'tile.bin_1');
        end

        function testNoNewDocumentEverNamesAFileZero(testCase)
            lv = struct('tile_index_origin', 1);
            for k = 0:50
                testCase.verifyNotEqual(ndi.fun.doc.gene.tileFileName(lv, k), 'tile.bin_0');
            end
        end

        function testTheIndexIsStillTheGridPosition(testCase)
            % Row 3, column 4 of a 10-wide level is index 34, file 35.
            lv = struct('tile_index_origin', 1);
            testCase.verifyEqual(ndi.fun.doc.gene.tileFileName(lv, 3*10 + 4), 'tile.bin_35');
        end

        % ---------------- older pyramids ----------------

        function testADocumentWithNoOriginRecordedIsReadAsZeroBased(testCase)
            lv = struct('bin_size', 1);
            testCase.verifyEqual(ndi.fun.doc.gene.tileFileName(lv, 0), 'tile.bin_0');
            testCase.verifyEqual(ndi.fun.doc.gene.tileFileName(lv, 70), 'tile.bin_70');
        end

        function testAnExplicitZeroIsHonoured(testCase)
            lv = struct('tile_index_origin', 0);
            testCase.verifyEqual(ndi.fun.doc.gene.tileFileName(lv, 12), 'tile.bin_12');
        end

        function testAnUnusableOriginDoesNotStopARender(testCase)
            % A malformed document should not take down a viewer part way
            % through a layer; it reads as the legacy origin.
            testCase.verifyEqual(ndi.fun.doc.gene.tileIndexOrigin(struct('tile_index_origin', [])), 0);
            testCase.verifyEqual(ndi.fun.doc.gene.tileIndexOrigin(struct('tile_index_origin', 'x')), 0);
            testCase.verifyEqual(ndi.fun.doc.gene.tileIndexOrigin(struct('tile_index_origin', [1 2])), 0);
            testCase.verifyEqual(ndi.fun.doc.gene.tileIndexOrigin(struct('bin_size', 1)), 0);
        end

        % ---------------- the index for a name ----------------

        function testTheNameAndTheIndexAreInverses(testCase)
            for origin = [0 1]
                lv = struct('tile_index_origin', origin);
                for k = [0 1 7 70 4999]
                    n = ndi.fun.doc.gene.tileFileName(lv, k);
                    testCase.verifyEqual(ndi.fun.doc.gene.tileIndexFromName(lv, n), k);
                end
            end
        end

        function testReadingTheSuffixAsTheIndexWouldMoveEveryTile(testCase)
            % Pin why tileIndexFromName exists: with a one-based origin the
            % suffix is one MORE than the grid index, so a reader that used
            % the suffix directly would put every tile one cell along its row.
            lv = struct('tile_index_origin', 1);
            n = ndi.fun.doc.gene.tileFileName(lv, 34);
            parts = strsplit(n, '_');
            testCase.verifyEqual(str2double(parts{end}), 35);
            testCase.verifyEqual(ndi.fun.doc.gene.tileIndexFromName(lv, n), 34);
        end

        % ---------------- a real pyramid ----------------

        function testARealPyramidStartsAtOne(testCase)
            names = testCase.storedTiles();
            testCase.verifyTrue(any(strcmp(names, 'tile.bin_1')));
            testCase.verifyFalse(any(strcmp(names, 'tile.bin_0')));
        end

        function testTheDocumentRecordsTheOriginItUsed(testCase)
            lv = testCase.levelProps();
            testCase.verifyTrue(isfield(lv, 'tile_index_origin'));
            testCase.verifyEqual(double(lv.tile_index_origin), 1);
        end

        function testTheSeriesIsSparseWhichIsWhyWalkingItCannotTerminate(testCase)
            % The stored names are not a contiguous run. A walk that counts
            % 1, 2, ... and takes the first absent name as the end of the
            % series finds the HOLE, not the end -- which is how a real
            % pyramid reached the cloud as 24 of its 450 tile files.
            names = testCase.storedTiles();
            testCase.verifyEqual(numel(names), 2, ...
                'the fixture is meant to leave two of four cells occupied');

            walked = {};
            j = 1;
            while any(strcmp(names, sprintf('tile.bin_%d', j)))
                walked{end+1} = sprintf('tile.bin_%d', j); %#ok<AGROW>
                j = j + 1;
            end
            testCase.verifyLessThan(numel(walked), numel(names), ...
                'a counting walk must fall short of the stored set');
        end

        function testTheCountsComeBackThroughReadViewport(testCase)
            % rect and geneRows are POSITIONAL and come before the options;
            % [] takes the whole level and every gene.
            [img, info] = ndi.fun.doc.gene.readViewport(testCase.session, ...
                testCase.pyr, 1, [], [], 'density', false);
            testCase.verifyEqual(info.tilesRead, 2);
            testCase.verifyEqual(sum(img(:)), 2+3+5+7, 'AbsTol', 1e-9);
        end

    end
end
