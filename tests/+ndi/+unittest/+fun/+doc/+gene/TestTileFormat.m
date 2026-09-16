classdef TestTileFormat < matlab.unittest.TestCase
    % TestTileFormat - conformance and round-trip tests for the tile codec.
    %
    % The fixture conformance_tile.bin was written by the NDI-python
    % implementation, not by this one. Decoding it here is what makes the
    % two implementations agree on a format rather than each agreeing with
    % itself. Its records were chosen to fail loudly under the mistakes
    % that actually occur across a language boundary:
    %
    %   * a pixel at (x=1,y=5) with none at (x=5,y=1), so a transposed
    %     reader produces a different raster rather than a coincidentally
    %     equal one;
    %   * a count of 999, above what a uint8 count field could hold;
    %   * a gene row of 70000, above what a uint16 gene index could hold;
    %   * unsorted input with several genes on one pixel and a single gene
    %     on another, so the grouping and the row pointer are exercised.
    %
    % If this test fails after a change to either implementation, the two
    % have diverged and the format is no longer shared.

    properties
        fixtureDir
        expected
    end

    methods (TestClassSetup)
        function loadFixture(testCase)
            testCase.fixtureDir = fileparts(mfilename('fullpath'));
            txt = fileread(fullfile(testCase.fixtureDir,'conformance_tile.json'));
            testCase.expected = jsondecode(txt);
        end
    end

    methods (Test)

        function testDecodeMatchesPython(testCase)
            % Every array must match the values NDI-python decoded.
            f = fullfile(testCase.fixtureDir,'conformance_tile.bin');
            t = ndi.fun.doc.gene.readTileFile(f);
            e = testCase.expected;

            testCase.verifyEqual(t.n_pixels,  double(e.n_pixels), ...
                'n_pixels disagrees with the Python decode.');
            testCase.verifyEqual(t.n_nonzero, double(e.n_nonzero), ...
                'n_nonzero disagrees with the Python decode.');
            testCase.verifyEqual(double(t.x(:)),          double(e.x(:)), ...
                'x disagrees; a transposed reader fails here.');
            testCase.verifyEqual(double(t.y(:)),          double(e.y(:)), ...
                'y disagrees; a transposed reader fails here.');
            testCase.verifyEqual(double(t.offset(:)),     double(e.offset(:)), ...
                'The row pointer disagrees.');
            testCase.verifyEqual(double(t.gene_index(:)), double(e.gene_index(:)), ...
                'gene_index disagrees; a uint16 index truncates 70000.');
            testCase.verifyEqual(double(t.count(:)),      double(e.count(:)), ...
                'count disagrees; a uint8 count truncates 999.');
        end

        function testRenderMatchesPython(testCase)
            f = fullfile(testCase.fixtureDir,'conformance_tile.bin');
            t = ndi.fun.doc.gene.readTileFile(f);
            e = testCase.expected;
            H = double(e.height); W = double(e.width);

            img = ndi.fun.doc.gene.renderTile(t, [], H, W);
            testCase.verifyEqual(sum(img(:)), double(e.render_all_genes_sum), ...
                'AbsTol', 1e-9, 'Total counts disagree with the Python render.');

            % Each nonzero pixel must land where Python put it. This is the
            % assertion a transposed or off-by-one reader cannot pass.
            for i = 1:numel(e.render_all_genes_nonzero_pixels)
                p = e.render_all_genes_nonzero_pixels(i);
                testCase.verifyEqual(img(double(p.y)+1, double(p.x)+1), double(p.value), ...
                    'AbsTol', 1e-9, sprintf( ...
                    'Pixel at zero-based (x=%d,y=%d) should be %g.', ...
                    double(p.x), double(p.y), double(p.value)));
            end

            sel = ndi.fun.doc.gene.renderTile(t, 70000, H, W);
            testCase.verifyEqual(sum(sel(:)), double(e.render_gene_70000_sum), ...
                'AbsTol', 1e-9, 'Selecting one gene disagrees with Python.');

            dens = ndi.fun.doc.gene.renderTile(t, [], H, W, 'binSize', 4);
            testCase.verifyEqual(sum(dens(:)), double(e.render_binsize4_sum), ...
                'AbsTol', 1e-9, ...
                'Density normalization must divide by binSize^2, here 16.');
        end

        function testRoundTripIsByteIdentical(testCase)
            % Re-encoding the decoded records must reproduce the Python
            % bytes exactly. Decoding correctly is not enough: NDI-matlab
            % also has to be able to WRITE tiles NDI-python can read.
            f = fullfile(testCase.fixtureDir,'conformance_tile.bin');
            t = ndi.fun.doc.gene.readTileFile(f);

            % expand CSR back to flat, pixel-repeated records
            n = t.n_pixels;
            reps = double(t.offset(2:end)) - double(t.offset(1:end-1));
            xs = repelem(double(t.x(:)), reps);
            ys = repelem(double(t.y(:)), reps);

            tmp = [tempname '.bin'];
            cl = onCleanup(@() delete(tmp));
            ndi.fun.doc.gene.writeTileFile(tmp, xs, ys, ...
                double(t.gene_index(:)), double(t.count(:)));

            testCase.verifyEqual(dir(tmp).bytes, dir(f).bytes, ...
                'Re-encoded tile differs in length from the Python original.');
            testCase.verifyEqual(fileread_bytes(tmp), fileread_bytes(f), ...
                'Re-encoded tile is not byte-identical to the Python original.');
            testCase.verifyEqual(n, double(testCase.expected.n_pixels));
        end

        function testEmptyTileRoundTrips(testCase)
            tmp = [tempname '.bin'];
            cl = onCleanup(@() delete(tmp));
            ndi.fun.doc.gene.writeTileFile(tmp, [], [], [], []);
            t = ndi.fun.doc.gene.readTileFile(tmp);
            testCase.verifyEqual(t.n_pixels, 0);
            testCase.verifyEqual(t.n_nonzero, 0);
            img = ndi.fun.doc.gene.renderTile(t, [], 8, 8);
            testCase.verifyEqual(sum(img(:)), 0);
        end

        function testWriteSortsUnorderedRecords(testCase)
            % Records may arrive in any order; the writer must group them
            % by pixel in (y,x) order so both implementations agree.
            tmp = [tempname '.bin'];
            cl = onCleanup(@() delete(tmp));
            ndi.fun.doc.gene.writeTileFile(tmp, [3;1;3], [7;2;7], [5;6;9], [1;2;3]);
            t = ndi.fun.doc.gene.readTileFile(tmp);
            testCase.verifyEqual(t.n_pixels, 2);
            testCase.verifyEqual(double(t.x(:)), [1;3], ...
                'Pixels must be ordered by (y,x), so (1,2) precedes (3,7).');
            testCase.verifyEqual(double(t.y(:)), [2;7]);
            testCase.verifyEqual(double(t.offset(:)), [0;1;3]);
        end

    end
end

function b = fileread_bytes(f)
    fid = fopen(f,'rb'); c = onCleanup(@() fclose(fid));
    b = fread(fid, Inf, '*uint8');
end
