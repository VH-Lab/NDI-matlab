classdef TestHdf5Contents < matlab.unittest.TestCase
    % TestHdf5Contents - what ndi.util.hdf5Contents says a file is.
    %
    % The listing is a convenience; the VERDICT is the part that can be
    % wrong, because it is what a user reads to decide which of several
    % similarly named files to ingest. A Stereo-seq run leaves
    % <chip>.tissue.gef beside <chip>.adjusted.cellbin.gef, both HDF5,
    % and picking the wrong one is answered by a reader error at best.
    %
    % Each case writes a real HDF5 file with the group that distinguishes
    % that layout, so the test exercises h5info rather than a stub.

    methods (Static)
        function f = newFile(testCase, name)
            d = tempname;
            mkdir(d);
            testCase.addTeardown(@() rmdir(d, 's'));
            f = fullfile(d, name);
        end
    end

    methods (Test)

        function testASquareBinGefIsNamedAsIngestable(testCase)
            f = ndi.unittest.util.TestHdf5Contents.newFile(testCase, 'x.tissue.gef');
            h5create(f, '/geneExp/bin1/expression', [10 1]);
            h5create(f, '/geneExp/bin1/gene', [3 1]);
            h5writeatt(f, '/geneExp/bin1', 'minX', 0);
            [T, verdict] = ndi.util.hdf5Contents(f);
            testCase.verifyTrue(any(contains(verdict, 'square-bin GEF')));
            testCase.verifyTrue(any(contains(verdict, 'fromGEF')));
            testCase.verifyTrue(any(T.path == "/geneExp/bin1/expression"));
        end

        function testACellBinGefIsNamedAsNotThatFile(testCase)
            % The trap this whole function exists for: same stem, same
            % extension, and fromGEF cannot read it.
            f = ndi.unittest.util.TestHdf5Contents.newFile(testCase, 'x.cellbin.gef');
            h5create(f, '/cellBin/cell', [10 1]);
            h5create(f, '/cellBin/cellExp', [10 1]);
            [~, verdict] = ndi.util.hdf5Contents(f);
            testCase.verifyTrue(any(contains(verdict, 'CellBin GEF')));
            testCase.verifyTrue(any(contains(verdict, 'NOT a square-bin GEF')));
            testCase.verifyFalse(any(contains(verdict, 'square-bin GEF:')));
        end

        function testAnAnnDataFileIsNamedAsTheCellbinReadersInput(testCase)
            f = ndi.unittest.util.TestHdf5Contents.newFile(testCase, 'cells.h5ad');
            h5create(f, '/X', [5 5]);
            h5create(f, '/obs/area', [5 1]);
            [~, verdict] = ndi.util.hdf5Contents(f);
            testCase.verifyTrue(any(contains(verdict, 'AnnData')));
            testCase.verifyTrue(any(contains(verdict, 'fromCellBin')));
        end

        function testAnUnrecognisedLayoutSaysSoRatherThanGuessing(testCase)
            f = ndi.unittest.util.TestHdf5Contents.newFile(testCase, 'other.h5');
            h5create(f, '/something/else', [2 2]);
            [~, verdict] = ndi.util.hdf5Contents(f);
            testCase.verifyTrue(any(contains(verdict, 'another kind')));
        end

        function testAttributesAreListedBecauseTheyHoldTheMetadata(testCase)
            % SAW puts the extent, the resolution and the chip serial in
            % attributes, so a listing without them hides what a caller
            % came to find.
            f = ndi.unittest.util.TestHdf5Contents.newFile(testCase, 'attrs.gef');
            h5create(f, '/geneExp/bin1/expression', [4 1]);
            h5writeatt(f, '/geneExp/bin1', 'resolution', 500);
            T = ndi.util.hdf5Contents(f);
            row = T(T.path == "/geneExp/bin1/@resolution", :);
            testCase.verifyEqual(height(row), 1);
            testCase.verifyEqual(row.kind(1), "attribute");
            testCase.verifyEqual(row.size(1), "500");
        end

        function testAFileThatIsNotHdf5IsRefusedWithAnExplanation(testCase)
            f = ndi.unittest.util.TestHdf5Contents.newFile(testCase, 'plain.gef');
            fid = fopen(f, 'w'); fwrite(fid, 'not hdf5 at all'); fclose(fid);
            testCase.verifyError(@() ndi.util.hdf5Contents(f), ...
                'NDI:util:hdf5Contents:notHDF5');
        end

    end
end
