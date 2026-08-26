classdef TestGeneDocs < matlab.unittest.TestCase
    % TestGeneDocs - round-trip test for the ndi.fun.doc.gene document makers.
    %
    % Builds a small pyramid from known records, then reads it back through
    % readViewport and exportRegion and checks that what comes out is what
    % went in. The point is to exercise the NDI document API -- document
    % creation, add_file with numbered names, dependencies, and querying
    % levels back by dependency -- which no other test in this package
    % covers. TestTileFormat proves the binary layout; this proves the
    % documents around it.
    %
    % The assertions are chosen so that the failures that would actually
    % occur are caught rather than averaged away:
    %   * total counts must be conserved through binning, so a dropped or
    %     double-counted record fails rather than shifting a mean slightly;
    %   * a single known gene at a single known pixel must land at that
    %     pixel, so a transposed or origin-shifted reader fails;
    %   * density must equal counts divided by binSize^2 exactly.

    properties
        testDir
        session
    end

    methods (TestClassSetup)
        function setupOnce(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            fixture = testCase.applyFixture(TemporaryFolderFixture);
            testCase.testDir = fullfile(fixture.Folder, 'gene_unittest');
            if ~isfolder(testCase.testDir), mkdir(testCase.testDir); end
            ndi.test.helper.initializeMksqliteNoOutput()
            testCase.session = ndi.session.dir('gene_exp1', testCase.testDir);
        end
    end

    methods (Test)

        function testGeneListRecordsDuplicateSymbols(testCase)
            % Symbols are not unique in real annotations, so the count of
            % duplicated ones is computed rather than assumed. Here HOXA
            % appears on three rows and one symbol is blank.
            ids   = {'ENSX0001','ENSX0002','ENSX0003','ENSX0004','ENSX0005'};
            names = {'HOXA','HOXA','PAX6','HOXA',''};
            d = ndi.fun.doc.gene.makeGeneList(testCase.session, ids, names, ...
                'genomeAssembly','testAsm','geneIdNamespace','Ensembl');
            g = d.document_properties.geneList;
            testCase.verifyEqual(g.n_genes, 5);
            testCase.verifyEqual(g.n_duplicate_gene_names, 1, ...
                'Exactly one symbol (HOXA) is carried by more than one row.');
            testCase.verifyEqual(g.gene_name_completeness, 4/5, 'AbsTol', 1e-12, ...
                'One of five rows has no symbol.');
            testCase.verifyEqual(g.genome_assembly, 'testAsm');
        end

        function testPyramidRoundTrip(testCase)
            ids = arrayfun(@(k) sprintf('ENSY%04d',k), 1:6, 'UniformOutput', false);
            names = {'A','B','C','D','E','F'};
            gl = ndi.fun.doc.gene.makeGeneList(testCase.session, ids, names);

            % Records placed so that x and y are never interchangeable and
            % the origin is not zero.
            ox = 1000; oy = 2000;
            x = [ox+0; ox+0; ox+3; ox+9; ox+9; ox+9];
            y = [oy+0; oy+0; oy+1; oy+7; oy+7; oy+7];
            gi = [0; 1; 2; 3; 4; 5];             % ZERO-BASED
            c  = [5; 7; 11; 13; 17; 19];

            [pyr, tiles] = ndi.fun.doc.gene.makePyramid(testCase.session, ...
                x, y, gi, c, gl, 'binSizes', [1 2], 'grid', 2, ...
                'basePixelSize', [0.5 0.5]);

            testCase.verifyNumElements(tiles, 2, 'One tiles document per bin size.');
            p = pyr.document_properties.spatialGeneExpressionPyramid;
            testCase.verifyEqual(p.origin_x, 1000, 'Origin comes from the data.');
            testCase.verifyEqual(p.origin_y, 2000);
            testCase.verifyEqual(p.tile_rows, 2);
            testCase.verifyEqual(p.bin_sizes, [1 2]);

            % counts must survive binning at every level
            total = sum(c);
            for b = [1 2]
                img = ndi.fun.doc.gene.readViewport(testCase.session, pyr, b, [], [], ...
                    'density', false);
                testCase.verifyEqual(sum(img(:)), total, 'AbsTol', 1e-9, ...
                    sprintf('Counts must be conserved at bin%d.', b));
            end

            % a known gene at a known pixel must land at that pixel
            img = ndi.fun.doc.gene.readViewport(testCase.session, pyr, 1, [], 2, ...
                'density', false);
            testCase.verifyEqual(sum(img(:)), 11, 'AbsTol', 1e-9, ...
                'Gene row 2 carries 11 counts.');
            testCase.verifyEqual(img(1+1, 3+1), 11, 'AbsTol', 1e-9, ...
                ['Gene row 2 sits at zero-based (x=3,y=1); a transposed or ' ...
                 'origin-shifted reader puts it elsewhere.']);

            % density is exactly counts / binSize^2
            dens = ndi.fun.doc.gene.readViewport(testCase.session, pyr, 2, [], [], ...
                'density', true);
            testCase.verifyEqual(sum(dens(:)), total/4, 'AbsTol', 1e-9, ...
                'At bin2 the divisor must be 4.');
        end

        function testExportRegionReturnsRawCounts(testCase)
            ids = arrayfun(@(k) sprintf('ENSZ%04d',k), 1:4, 'UniformOutput', false);
            gl = ndi.fun.doc.gene.makeGeneList(testCase.session, ids, ...
                {'g1','g2','g3','g4'});
            x = [10; 10; 12; 40]; y = [20; 20; 21; 50];
            gi = [0; 1; 2; 3];  c = [2; 3; 4; 5];
            [pyr, ~] = ndi.fun.doc.gene.makePyramid(testCase.session, x, y, gi, c, gl, ...
                'binSizes', 1, 'grid', 2);

            [M, pixelXY] = ndi.fun.doc.gene.exportRegion(testCase.session, pyr, 1, []);
            testCase.verifySize(M, [3 4], ...
                'Three occupied pixels: two records share one pixel.');
            testCase.verifyEqual(full(sum(M(:))), 14, ...
                'Export must be RAW counts, with no density normalization.');
            testCase.verifySize(pixelXY, [3 2]);
            testCase.verifyTrue(all(pixelXY(:) >= 0), ...
                'Pixel coordinates are relative to the level origin.');
        end

    end
end
