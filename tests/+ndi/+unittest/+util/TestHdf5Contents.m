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

        function testTheListingCanBeCappedPerGroup(testCase)
            % An /obs group with thousands of columns is otherwise the
            % whole output, so maxChildren stops and SAYS it stopped --
            % a silently truncated listing is worse than a long one.
            f = ndi.unittest.util.TestHdf5Contents.newFile(testCase, 'many.h5');
            h5create(f, '/g/a', [1 1]);
            h5create(f, '/g/b', [1 1]);
            h5create(f, '/g/c', [1 1]);
            T = ndi.util.hdf5Contents(f, 'maxChildren', 2);
            testCase.verifyEqual(sum(T.kind == "dataset"), 2);
            note = T(T.kind == "note", :);
            testCase.verifyEqual(height(note), 1);
            testCase.verifyTrue(contains(note.path(1), '1 more dataset'));
        end

        function testTheCapCountsGroupsTooAndSaysHowManyWereLeft(testCase)
            f = ndi.unittest.util.TestHdf5Contents.newFile(testCase, 'manyg.h5');
            h5create(f, '/g1/a', [1 1]);
            h5create(f, '/g2/a', [1 1]);
            h5create(f, '/g3/a', [1 1]);
            T = ndi.util.hdf5Contents(f, 'maxChildren', 2);
            testCase.verifyEqual(sum(T.kind == "group"), 2);
            note = T(T.kind == "note", :);
            testCase.verifyEqual(height(note), 1);
            testCase.verifyTrue(contains(note.path(1), '1 more group'));
        end

        function testMaxDepthStopsTheDescentWhereItIsAsked(testCase)
            f = ndi.unittest.util.TestHdf5Contents.newFile(testCase, 'deep.h5');
            h5create(f, '/a/b/c/deep', [1 1]);
            shallow = ndi.util.hdf5Contents(f, 'maxDepth', 2);
            testCase.verifyFalse(any(shallow.path == "/a/b/c/deep"));
            deep = ndi.util.hdf5Contents(f, 'maxDepth', 6);
            testCase.verifyTrue(any(deep.path == "/a/b/c/deep"));
        end

        function testAShallowListingStillReachesAVerdict(testCase)
            % Cut the descent short of the bin group and the verdict must
            % say the depth is why, not claim the file is something else.
            f = ndi.unittest.util.TestHdf5Contents.newFile(testCase, 'shallow.gef');
            h5create(f, '/geneExp/bin1/expression', [4 1]);
            [~, verdict] = ndi.util.hdf5Contents(f, 'maxDepth', 1);
            testCase.verifyTrue(any(contains(verdict, 'Raise maxDepth')));
        end

        function testAttributesCanBeTurnedOff(testCase)
            f = ndi.unittest.util.TestHdf5Contents.newFile(testCase, 'noattrs.gef');
            h5create(f, '/geneExp/bin1/expression', [4 1]);
            h5writeatt(f, '/geneExp/bin1', 'resolution', 500);
            T = ndi.util.hdf5Contents(f, 'attributes', false);
            testCase.verifyEqual(sum(T.kind == "attribute"), 0);
            testCase.verifyTrue(any(T.path == "/geneExp/bin1/expression"));
        end

        function testALongAttributeIsTruncatedRatherThanFillingTheLine(testCase)
            % Six values is under the cap that switches to a shape, so this
            % goes through the value-joining path and comes out too long
            % for a line -- which is what the 60-character trim is for.
            f = ndi.unittest.util.TestHdf5Contents.newFile(testCase, 'long.h5');
            h5create(f, '/g/d', [1 1]);
            h5writeatt(f, '/g', 'wide', repmat(1.23456789e15, 1, 6));
            T = ndi.util.hdf5Contents(f);
            row = T(T.path == "/g/@wide", :);
            testCase.verifyEqual(height(row), 1);
            testCase.verifyLessThanOrEqual(strlength(row.size(1)), 61);
            testCase.verifyTrue(endsWith(row.size(1), '...'));
        end

        function testAWideNumericAttributeIsShownAsItsShape(testCase)
            % Six values or fewer read as values; more than that would be
            % a wall, so the shape is the useful thing to print.
            f = ndi.unittest.util.TestHdf5Contents.newFile(testCase, 'wide.h5');
            h5create(f, '/g/d', [1 1]);
            h5writeatt(f, '/g', 'few', [1 2 3]);
            h5writeatt(f, '/g', 'many', 1:8);
            T = ndi.util.hdf5Contents(f);
            few = T(T.path == "/g/@few", :);
            many = T(T.path == "/g/@many", :);
            testCase.verifyEqual(few.size(1), "1, 2, 3");
            testCase.verifyTrue(startsWith(many.size(1), "<"));
            testCase.verifyTrue(contains(many.size(1), "8"));
        end

        function testADatasetRowCarriesItsSizeAndClass(testCase)
            f = ndi.unittest.util.TestHdf5Contents.newFile(testCase, 'shape.h5');
            h5create(f, '/g/d', [7 3], 'Datatype', 'int32');
            T = ndi.util.hdf5Contents(f);
            row = T(T.path == "/g/d", :);
            testCase.verifyEqual(height(row), 1);
            testCase.verifyEqual(row.size(1), "7 x 3");
            testCase.verifyTrue(contains(row.class(1), "INTEGER"));
        end

        function testWithNoOutputRequestedTheListingIsPrinted(testCase)
            % The usual way this is called is at the prompt with no
            % semicolon-free output to catch, so the printing path is the
            % one a user actually sees.
            f = ndi.unittest.util.TestHdf5Contents.newFile(testCase, 'print.gef');
            h5create(f, '/geneExp/bin1/expression', [4 1]);
            h5writeatt(f, '/geneExp/bin1', 'resolution', 500);
            out = evalc('ndi.util.hdf5Contents(f)');
            testCase.verifyTrue(contains(out, 'print.gef'));
            testCase.verifyTrue(contains(out, '[group]'));
            testCase.verifyTrue(contains(out, '@resolution'));
            testCase.verifyTrue(contains(out, '= 500'));
            testCase.verifyTrue(contains(out, 'square-bin GEF'));
        end

        function testThePrintedListingShowsTheTruncationNote(testCase)
            f = ndi.unittest.util.TestHdf5Contents.newFile(testCase, 'printmany.h5');
            h5create(f, '/g/a', [1 1]);
            h5create(f, '/g/b', [1 1]);
            h5create(f, '/g/c', [1 1]);
            out = evalc('ndi.util.hdf5Contents(f, ''maxChildren'', 2)');
            testCase.verifyTrue(contains(out, '1 more dataset'));
        end

    end
end
