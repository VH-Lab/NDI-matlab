classdef TestGeneFromFiles < matlab.unittest.TestCase
    % TestGeneFromFiles - the .gef and .h5ad to documents path.
    %
    % These exercise the seam: NDR reads the vendor's file and returns
    % arrays, NDI turns arrays into documents. Before fromGEF and
    % fromCellBin the seam was only ever crossed inside
    % ndi.gui.app.GeneIngest, so nothing without a display could import a
    % section and nothing tested the sequence end to end.
    %
    % THE FIXTURES ARE NDR'S, not copies. They are located from the
    % reader's own path, so the two repos are held to one artifact rather
    % than each to its own -- the same discipline the cross-language
    % conformance fixtures follow. When NDR is not installed the tests
    % that need a real file are FILTERED rather than failed: an absent
    % dependency is not a defect in this code, and a fabricated .gef would
    % test our idea of the layout instead of the layout.

    properties
        session
        subjectID
    end

    methods (TestMethodSetup)
        function build(testCase)
            d = fullfile(tempname, 'fromfiles');
            mkdir(d);
            testCase.addTeardown(@() rmdir(fileparts(d), 's'));
            S = ndi.session.dir('fromfiles', d);
            sub = ndi.document('subject', 'base.session_id', S.id(), ...
                'subject.local_identifier', 'fromfiles@vhlab');
            S.database_add(sub);
            testCase.session = S;
            testCase.subjectID = sub.id();
        end
    end

    methods (Test)

        % ------------------------------------------------ makeSourceFile

        function testSourceFileDescribesWithoutIngestingAPayload(testCase)
            % The default is to DESCRIBE. A SAW .gef is ~9.4 GB; ingesting
            % a copy alongside the pyramid derived from it would roughly
            % double the storage to hold bytes the pyramid summarises.
            f = testCase.aFile('describe.txt', 'hello');
            doc = ndi.fun.doc.gene.makeSourceFile(testCase.session, f);
            g = doc.document_properties.generic_file;
            testCase.verifyEqual(g.filename, 'describe.txt');
            testCase.verifyNotEmpty(g.checksum);
            testCase.verifyEmpty(doc.current_file_list(), ...
                'The default must not attach the file itself.');
        end

        function testSourceFileCanAttachWhenAsked(testCase)
            f = testCase.aFile('attach.txt', 'hello');
            doc = ndi.fun.doc.gene.makeSourceFile(testCase.session, f, ...
                'attachFile', true);
            testCase.verifyEqual(doc.current_file_list(), {'generic_file.ext'});
        end

        function testSourceFileChecksumCanBeSkippedAndSaysNothing(testCase)
            % Skipping must leave the field EMPTY, not fill it with a
            % placeholder that would later read as a real hash.
            f = testCase.aFile('nosum.txt', 'hello');
            doc = ndi.fun.doc.gene.makeSourceFile(testCase.session, f, ...
                'checksum', false);
            testCase.verifyEmpty(doc.document_properties.generic_file.checksum);
        end

        function testSourceFileChecksumDistinguishesSameNamedFiles(testCase)
            % The whole point. Two SAW runs of one chip produce files with
            % the same name and different contents; a filename says what
            % somebody called it, a checksum says whether it is the file
            % the pyramid was built from.
            a = testCase.aFile('run.txt', 'first run');
            d1 = ndi.fun.doc.gene.makeSourceFile(testCase.session, a);
            b = testCase.aFile('run.txt', 'second run', 'sub2');
            d2 = ndi.fun.doc.gene.makeSourceFile(testCase.session, b);
            testCase.verifyEqual(d2.document_properties.generic_file.filename, ...
                d1.document_properties.generic_file.filename);
            testCase.verifyNotEqual(d2.document_properties.generic_file.checksum, ...
                d1.document_properties.generic_file.checksum);
        end

        % --------------------------------------------- source_file_id

        function testPyramidTilesCarryTheSourceFileDependency(testCase)
            % spatialGeneExpressionTiles has declared a source_file_id
            % dependency since it was written and nothing ever populated
            % it, so a pyramid could not say which file it came from.
            f = testCase.aFile('src.gef', 'not really a gef');
            src = ndi.fun.doc.gene.makeSourceFile(testCase.session, f);
            testCase.session.database_add(src);
            gl = ndi.fun.doc.gene.makeGeneList(testCase.session, ...
                {'E1','E2'}, {'a','b'});
            [~, tiles] = ndi.fun.doc.gene.makePyramid(testCase.session, ...
                [1000;1005], [2000;2003], [0;1], [2;3], gl, ...
                'subjectID', testCase.subjectID, 'binSizes', [1 2], ...
                'grid', 2, 'sourceFileID', src.id());
            for i = 1:numel(tiles)
                testCase.verifyEqual( ...
                    tiles{i}.dependency_value('source_file_id'), src.id());
            end
        end

        function testCellsCarryTheSourceFileDependency(testCase)
            f = testCase.aFile('src.h5ad', 'not really an h5ad');
            src = ndi.fun.doc.gene.makeSourceFile(testCase.session, f);
            testCase.session.database_add(src);
            gl = ndi.fun.doc.gene.makeGeneList(testCase.session, {'E1'}, {'a'});
            pyr = ndi.fun.doc.gene.makePyramid(testCase.session, 1000, 2000, ...
                0, 1, gl, 'subjectID', testCase.subjectID, ...
                'binSizes', 1, 'grid', 1);
            cells = ndi.fun.doc.gene.makeCells(testCase.session, {'c0'}, ...
                1000, 2000, pyr, 'sourceFileID', src.id());
            testCase.verifyEqual(cells.dependency_value('source_file_id'), ...
                src.id());
        end

        function testSourceFileIsOptionalAndLeavesTheSlotEmpty(testCase)
            % A pyramid built from arrays in memory has no source file and
            % must not claim one.
            gl = ndi.fun.doc.gene.makeGeneList(testCase.session, {'E1'}, {'a'});
            [~, tiles] = ndi.fun.doc.gene.makePyramid(testCase.session, ...
                1000, 2000, 0, 1, gl, 'subjectID', testCase.subjectID, ...
                'binSizes', 1, 'grid', 1);
            testCase.verifyEmpty(tiles{1}.dependency_value('source_file_id'));
        end

        % ------------------------------------------------------ readNotes

        function testReadNotesReportClampedCountsAndTheExtentSource(testCase)
            meta = struct('nCountsClamped', 1234567, 'boxSource', 'data');
            notes = ndi.fun.doc.gene.readNotes(meta, {'E1'});
            testCase.verifyTrue(any(contains(notes, '1,234,567')));
            testCase.verifyTrue(any(contains(notes, 'read low')));
            testCase.verifyTrue(any(contains(notes, 'data')));
        end

        function testReadNotesSayWhenGenesWereLeftBehind(testCase)
            % maxGenes trims silently: the pyramid is missing genes and
            % nothing in it records that.
            meta = struct('nCountsClamped', 0, 'boxSource', 'data', ...
                'nGenesInFile', 30434);
            notes = ndi.fun.doc.gene.readNotes(meta, {'E1','E2'});
            testCase.verifyTrue(any(contains(notes, '30434')));
        end

        function testReadNotesAreQuietWhenNothingIsWrong(testCase)
            meta = struct('nCountsClamped', 0, 'boxSource', 'data', ...
                'nGenesInFile', 1);
            notes = ndi.fun.doc.gene.readNotes(meta, {'E1'});
            testCase.verifyEqual(numel(notes), 1);   % just the extent
        end

        % --------------------------------------------------- fromGEF

        function testFromGefBuildsTheWholeLadder(testCase)
            gef = testCase.ndrFixture('gef_basic.gef');
            [pyr, tiles, gl, info] = ndi.fun.doc.gene.fromGEF( ...
                testCase.session, gef, 'subjectID', testCase.subjectID, ...
                'binSizes', [1 2], 'grid', 2, 'checksum', false);

            testCase.verifyClass(pyr, 'ndi.document');
            testCase.verifyEqual(numel(tiles), 2, 'One tiles doc per level.');
            testCase.verifyEqual(pyr.dependency_value('geneList_id'), gl.id());
            testCase.verifyEqual(pyr.dependency_value('subject_id'), ...
                testCase.subjectID);
            testCase.verifyNotEmpty(info.meta);
        end

        function testFromGefTakesTheChipAndPixelSizeFromTheFile(testCase)
            % Both are IN the .gef, so a caller should not have to repeat
            % them. resolutionNm is NANOMETRES and base_pixel_size is
            % micrometres, and SAW's usual 500 nm becomes 0.5 -- which is
            % also makePyramid's default, so a bad conversion here looks
            % exactly like the default and needs its own assertion.
            gef = testCase.ndrFixture('gef_basic.gef');
            [~,~,~,info] = ndi.fun.doc.gene.fromGEF(testCase.session, gef, ...
                'subjectID', testCase.subjectID, 'binSizes', 1, ...
                'grid', 1, 'checksum', false);
            pyrs = testCase.session.database_search( ...
                ndi.query('','isa','spatialGeneExpressionPyramid'));
            p = pyrs{1}.document_properties.spatialGeneExpressionPyramid;
            testCase.verifyEqual(p.base_pixel_size_x, ...
                info.meta.resolutionNm / 1000, 'AbsTol', 1e-12);
        end

        function testFromGefRecordsTheSourceFileByDefault(testCase)
            gef = testCase.ndrFixture('gef_basic.gef');
            [~, tiles, ~, info] = ndi.fun.doc.gene.fromGEF( ...
                testCase.session, gef, 'subjectID', testCase.subjectID, ...
                'binSizes', 1, 'grid', 1, 'checksum', false);
            testCase.verifyNotEmpty(info.sourceDoc);
            testCase.verifyEqual(tiles{1}.dependency_value('source_file_id'), ...
                info.sourceDoc.id());
            testCase.verifyEqual( ...
                info.sourceDoc.document_properties.generic_file.filename, ...
                'gef_basic.gef');
        end

        function testFromGefCanBeToldNotToRecordASource(testCase)
            gef = testCase.ndrFixture('gef_basic.gef');
            [~, tiles, ~, info] = ndi.fun.doc.gene.fromGEF( ...
                testCase.session, gef, 'subjectID', testCase.subjectID, ...
                'binSizes', 1, 'grid', 1, 'recordSource', false);
            testCase.verifyEmpty(info.sourceDoc);
            testCase.verifyEmpty(tiles{1}.dependency_value('source_file_id'));
        end

        function testFromGefReportsProgressThroughTheWholeRun(testCase)
            % ndi.gui.app.GeneIngest drives its bar from this. The
            % fractions must not go backwards and must reach 1, or the
            % dialog stalls short of the end on a read that takes minutes
            % and a user cannot tell a slow step from a hung one.
            %
            % The collector is a NESTED function rather than an anonymous
            % one because an anonymous function captures its workspace by
            % value and could not accumulate anything.
            gef = testCase.ndrFixture('gef_basic.gef');
            calls = {};
            ndi.fun.doc.gene.fromGEF( ...
                testCase.session, gef, 'subjectID', testCase.subjectID, ...
                'binSizes', 1, 'grid', 1, 'checksum', false, ...
                'progressFcn', @collect);

            testCase.assertNotEmpty(calls, 'progressFcn was never called.');
            fr = cellfun(@(c) c{1}, calls);
            testCase.verifyEqual(fr, sort(fr), ...
                'Progress must never move backwards.');
            testCase.verifyEqual(fr(1), 0, 'The first report is the read.');
            testCase.verifyEqual(fr(end), 1, 'The last report must reach 1.');
            testCase.verifyTrue(all(cellfun(@(c) ischar(c{2}), calls)), ...
                'Every report must carry text for the dialog.');

            function collect(f, t)
                calls{end+1} = {f, t};
            end
        end

        function testFromGefWithoutAProgressFcnIsSilentRatherThanBroken(testCase)
            % The default is no handle, because a script has no bar. This
            % is the path every other test here takes, asserted once
            % directly so a mistake in the tick helper cannot hide behind
            % them all passing for other reasons.
            gef = testCase.ndrFixture('gef_basic.gef');
            pyr = ndi.fun.doc.gene.fromGEF(testCase.session, gef, ...
                'subjectID', testCase.subjectID, 'binSizes', 1, ...
                'grid', 1, 'checksum', false);
            testCase.verifyClass(pyr, 'ndi.document');
        end

        function testFromGefRefusesWithoutASubject(testCase)
            % A .gef records a chip, not an animal, and the pyramid schema
            % declares subject_id mustbenotempty.
            gef = testCase.ndrFixture('gef_basic.gef');
            testCase.verifyError(@() ndi.fun.doc.gene.fromGEF( ...
                testCase.session, gef, 'binSizes', 1, 'grid', 1, ...
                'checksum', false), 'NDI:gene:makePyramid:subjectRequired');
        end

        % ------------------------------------------------ fromCellBin

        function testFromCellBinBuildsCellsAgainstThePyramid(testCase)
            [pyr, h5ad] = testCase.aPyramidAndCellbin();
            [cells, labels, info] = ndi.fun.doc.gene.fromCellBin( ...
                testCase.session, h5ad, pyr, 'checksum', false);
            testCase.verifyEmpty(labels, 'No labeling was asked for.');
            testCase.verifyEqual( ...
                cells.dependency_value('spatialGeneExpressionPyramid_id'), ...
                pyr.id());
            testCase.verifyEqual( ...
                cells.document_properties.spatialGeneExpressionCells.n_cells, 5);
            testCase.verifyNotEmpty(info.labelColumns, ...
                'The available labelings must be reported even when none is taken.');
        end

        function testFromCellBinRecordsWhatTheReaderConcludedNotWhatWasAsked(testCase)
            % contourReference 'auto' is a REQUEST; the document must
            % carry the answer. Storing 'auto' would make every reader
            % downstream infer it again, from a document whose whole job
            % is to have settled it.
            [pyr, h5ad] = testCase.aPyramidAndCellbin();
            cells = ndi.fun.doc.gene.fromCellBin(testCase.session, h5ad, ...
                pyr, 'contourReference', 'auto', 'checksum', false);
            ref = cells.document_properties.spatialGeneExpressionCells.contour_reference;
            testCase.verifyTrue(ismember(ref, {'centroid','absolute'}), ...
                sprintf('contour_reference is "%s", not a settled answer.', ref));
        end

        function testFromCellBinIngestsARequestedLabeling(testCase)
            [pyr, h5ad] = testCase.aPyramidAndCellbin();
            sel = struct('name', 'subclass_nn_column', 'isUnsupervised', false);
            [cells, labels] = ndi.fun.doc.gene.fromCellBin(testCase.session, ...
                h5ad, pyr, 'labelings', sel, 'checksum', false);
            testCase.verifyEqual(numel(labels), 1);
            L = labels{1}.document_properties.cellTypeLabels;
            testCase.verifyEqual(L.label_name, 'subclass_nn_column');
            testCase.verifyFalse(logical(L.is_unsupervised));
            testCase.verifyEqual(labels{1}.dependency_value('cells_document_id'), ...
                cells.id());
        end

        function testFromCellBinTakesUnsupervisedFromTheCallerNotTheFile(testCase)
            % The file does not say which labelings are clusterings, and
            % reading a cluster index as a cell type is a scientific error
            % rather than a display one. The caller settles it.
            [pyr, h5ad] = testCase.aPyramidAndCellbin();
            sel = struct('name', 'leiden', 'isUnsupervised', true);
            [~, labels] = ndi.fun.doc.gene.fromCellBin(testCase.session, ...
                h5ad, pyr, 'labelings', sel, 'checksum', false);
            testCase.verifyTrue(logical( ...
                labels{1}.document_properties.cellTypeLabels.is_unsupervised));
        end

    end

    methods (Access = private)

        function f = aFile(testCase, name, contents, sub)
            arguments
                testCase
                name (1,:) char
                contents (1,:) char
                sub (1,:) char = 'src'
            end
            d = fullfile(tempname, sub);
            mkdir(d);
            testCase.addTeardown(@() rmdir(fileparts(d), 's'));
            f = fullfile(d, name);
            fid = fopen(f, 'w');
            fwrite(fid, contents);
            fclose(fid);
        end

        function f = ndrFixture(testCase, name)
            % NDR's own test fixtures, found from the reader's path so the
            % two repos share one artifact.
            w = which('ndr.format.stereoseq.readGEF');
            testCase.assumeNotEmpty(w, ...
                'NDR-matlab is not installed; the file readers are its.');
            root = extractBefore(w, [filesep '+ndr' filesep]);
            f = fullfile(root, 'tools', 'tests', '+ndr', '+unittest', ...
                '+format', '+stereoseq', name);
            testCase.assumeTrue(isfile(f), sprintf( ...
                'NDR fixture %s not found at %s.', name, f));
        end

        function [pyr, h5ad] = aPyramidAndCellbin(testCase)
            h5ad = testCase.ndrFixture('cellbin_basic.h5ad');
            gl = ndi.fun.doc.gene.makeGeneList(testCase.session, {'E1'}, {'a'});
            % The fixture's centroids are ~10^4, so the pyramid must cover
            % that ground or the cells would sit outside their own frame.
            pyr = ndi.fun.doc.gene.makePyramid(testCase.session, ...
                [10000; 21000], [20000; 21000], [0; 0], [1; 1], gl, ...
                'subjectID', testCase.subjectID, 'binSizes', 1, 'grid', 1);
        end

    end
end
