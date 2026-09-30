classdef TestMakePyramid < matlab.unittest.TestCase
    % TestMakePyramid - the pyramid/level document writer.
    %
    % Exercises makePyramid over synthetic listPyramids-style structs so
    % the whole schema-level path (parent doc, per-level doc, dedupe of
    % shared level 0, dependency wiring, chunk-shape choice) is covered
    % without a real OME-Zarr store. Also drives the auto tile-shape
    % chooser through makePyramid to catch integration regressions that
    % the standalone TestChooseTileShape suite would miss.

    properties
        session
        subjectID
    end

    methods (TestMethodSetup)
        function build(testCase)
            d = fullfile(tempname, 'makepyramid');
            mkdir(d);
            testCase.addTeardown(@() rmdir(fileparts(d), 's'));
            S = ndi.session.dir('makepyramid', d);
            sub = ndi.document('subject', 'base.session_id', S.id(), ...
                'subject.local_identifier', 'lightsheet@vhlab');
            S.database_add(sub);
            testCase.session = S;
            testCase.subjectID = sub.id();
        end
    end

    methods (Static)
        function ax = axes3D()
            ax = struct('name', {'z','y','x'}, 'type', {'space','space','space'}, ...
                'unit', {'micrometer','micrometer','micrometer'});
        end

        function levels = dyadicLevels(paths, shape0, vox0, dtype)
            n = numel(paths);
            levels = repmat(struct( ...
                'path', '', 'shape', [], 'chunks', [], 'dtype', dtype, ...
                'scale', [], 'translation', [0 0 0]), n, 1);
            for k = 1:n
                levels(k).path = paths{k};
                levels(k).shape = max(1, floor(shape0 / 2^(k-1)));
                % Source zarr's own chunks are irrelevant to the doc --
                % makePyramid re-chooses them -- but supply something
                % plausible so the input struct is well-formed.
                levels(k).chunks = min(levels(k).shape, [64 64 64]);
                levels(k).scale = vox0 * 2^(k-1);
                levels(k).translation = [0 0 0];
            end
        end

        function py = pyramidEntry(name, typ, levels)
            py = struct('name', name, 'type', typ, ...
                'axes', ndi.unittest.fun.doc.lightsheet.TestMakePyramid.axes3D(), ...
                'levels', levels);
        end

        function pys = twoPyramidsWithSharedLevel0()
            L0 = ndi.unittest.fun.doc.lightsheet.TestMakePyramid.dyadicLevels( ...
                {'0','mean/1','mean/2'}, [128 512 512], [1 1 1], 'uint16');
            L1 = ndi.unittest.fun.doc.lightsheet.TestMakePyramid.dyadicLevels( ...
                {'0','max/1','max/2'}, [128 512 512], [1 1 1], 'uint16');
            pys = [ndi.unittest.fun.doc.lightsheet.TestMakePyramid.pyramidEntry( ...
                    'mean', 'box', L0); ...
                ndi.unittest.fun.doc.lightsheet.TestMakePyramid.pyramidEntry( ...
                    'max', 'max', L1)];
        end
    end

    methods (Test)

        function testOnePyramidOneLevelWritesTwoDocs(testCase)
            L = ndi.unittest.fun.doc.lightsheet.TestMakePyramid.dyadicLevels( ...
                {'0'}, [64 128 128], [1 1 1], 'uint16');
            py = ndi.unittest.fun.doc.lightsheet.TestMakePyramid.pyramidEntry( ...
                'raw', 'box', L);
            [pdoc, lds, shared] = ndi.fun.doc.lightsheet.makePyramid( ...
                testCase.session, py, {'mean'}, ...
                'subjectID', testCase.subjectID);
            testCase.verifyFalse(shared);
            testCase.verifyClass(pdoc, 'ndi.document');
            testCase.verifyEqual(numel(lds), 1);
            % The level document is written with reduction_function =
            % the entry's reduction, since only one pyramid uses this
            % path.
            p = lds{1}.document_properties.lightsheetZarrLevel;
            testCase.verifyEqual(p.reduction_function, 'mean');
            testCase.verifyEqual(p.level, 0);
        end

        function testTwoPyramidsSharedLevel0DedupesToFiveDocs(testCase)
            pys = ndi.unittest.fun.doc.lightsheet.TestMakePyramid.twoPyramidsWithSharedLevel0();
            [pdoc, lds, shared] = ndi.fun.doc.lightsheet.makePyramid( ...
                testCase.session, pys, {'mean','max'}, ...
                'subjectID', testCase.subjectID);
            testCase.verifyTrue(shared);
            % 5 unique paths: shared '0', mean/1, mean/2, max/1, max/2.
            testCase.verifyEqual(numel(lds), 5);
            reductions = cellfun(@(d) ...
                d.document_properties.lightsheetZarrLevel.reduction_function, ...
                lds, 'UniformOutput', false);
            testCase.verifyEqual(sum(strcmp(reductions, 'none')), 1);
            testCase.verifyEqual(sum(strcmp(reductions, 'mean')), 2);
            testCase.verifyEqual(sum(strcmp(reductions, 'max')), 2);
        end

        function testChunksAutoChosenByBudget(testCase)
            % Level 0 shape 128 x 512 x 512 uint16 with 8 MB budget
            % lands on ~128^3 * 2 ~= 4 MB (Z clamps to 128 which is
            % well below the ideal cube, so the redistribution kicks in
            % to push XY up). The stamped chunks should be within the
            % budget.
            pys = ndi.unittest.fun.doc.lightsheet.TestMakePyramid.twoPyramidsWithSharedLevel0();
            [~, lds] = ndi.fun.doc.lightsheet.makePyramid( ...
                testCase.session, pys, {'mean','max'}, ...
                'subjectID', testCase.subjectID);
            for k = 1:numel(lds)
                p = lds{k}.document_properties.lightsheetZarrLevel;
                bytes = prod(p.chunks) * 2;
                testCase.verifyLessThanOrEqual(bytes, 1.3 * 8 * 2^20);
                testCase.verifyEqual(numel(p.chunks), numel(p.shape));
                testCase.verifyEqual(p.chunk_grid, ceil(p.shape ./ p.chunks));
            end
        end

        function testExplicitChunksOverrideBudget(testCase)
            L = ndi.unittest.fun.doc.lightsheet.TestMakePyramid.dyadicLevels( ...
                {'0','1'}, [64 128 128], [1 1 1], 'uint16');
            py = ndi.unittest.fun.doc.lightsheet.TestMakePyramid.pyramidEntry( ...
                'mean', 'box', L);
            [~, lds] = ndi.fun.doc.lightsheet.makePyramid( ...
                testCase.session, py, {'mean'}, ...
                'subjectID', testCase.subjectID, ...
                'chunks', [32 32 32]);
            % Explicit chunks used verbatim on every level (clamped by
            % shape).
            p0 = lds{1}.document_properties.lightsheetZarrLevel;
            p1 = lds{2}.document_properties.lightsheetZarrLevel;
            testCase.verifyEqual(p0.chunks, [32 32 32]);
            testCase.verifyEqual(p1.chunks, [32 32 32]);
        end

        function testExplicitChunksClampToShape(testCase)
            L = ndi.unittest.fun.doc.lightsheet.TestMakePyramid.dyadicLevels( ...
                {'0'}, [16 32 32], [1 1 1], 'uint16');
            py = ndi.unittest.fun.doc.lightsheet.TestMakePyramid.pyramidEntry( ...
                'mean', 'box', L);
            [~, lds] = ndi.fun.doc.lightsheet.makePyramid( ...
                testCase.session, py, {'mean'}, ...
                'subjectID', testCase.subjectID, ...
                'chunks', [64 64 64]);
            % Explicit chunks larger than shape are clamped to shape.
            p = lds{1}.document_properties.lightsheetZarrLevel;
            testCase.verifyEqual(p.chunks, [16 32 32]);
        end

        function testExplicitChunksArityMismatchErrors(testCase)
            L = ndi.unittest.fun.doc.lightsheet.TestMakePyramid.dyadicLevels( ...
                {'0'}, [16 32 32], [1 1 1], 'uint16');
            py = ndi.unittest.fun.doc.lightsheet.TestMakePyramid.pyramidEntry( ...
                'mean', 'box', L);
            testCase.verifyError(@() ndi.fun.doc.lightsheet.makePyramid( ...
                testCase.session, py, {'mean'}, ...
                'subjectID', testCase.subjectID, ...
                'chunks', [32 32]), ...
                'NDI:lightsheet:makePyramid:chunksArity');
        end

        function testReductionCellArityIsChecked(testCase)
            L = ndi.unittest.fun.doc.lightsheet.TestMakePyramid.dyadicLevels( ...
                {'0'}, [16 32 32], [1 1 1], 'uint16');
            py = ndi.unittest.fun.doc.lightsheet.TestMakePyramid.pyramidEntry( ...
                'mean', 'box', L);
            testCase.verifyError(@() ndi.fun.doc.lightsheet.makePyramid( ...
                testCase.session, py, {'mean','max'}, ...
                'subjectID', testCase.subjectID), ...
                'NDI:lightsheet:makePyramid:reductionArity');
        end

        function testParentCarriesLevel0Frame(testCase)
            pys = ndi.unittest.fun.doc.lightsheet.TestMakePyramid.twoPyramidsWithSharedLevel0();
            [pdoc, ~, ~] = ndi.fun.doc.lightsheet.makePyramid( ...
                testCase.session, pys, {'mean','max'}, ...
                'subjectID', testCase.subjectID, ...
                'pipelineVersion', 'unit-test-1', ...
                'label', 'my volume');
            p = pdoc.document_properties.lightsheetZarrPyramid;
            testCase.verifyEqual(p.axes_order, 'zyx');
            testCase.verifyEqual(reshape(p.shape_level0, 1, []), [128 512 512]);
            testCase.verifyEqual(reshape(p.voxel_size_level0, 1, []), [1 1 1]);
            testCase.verifyEqual(char(p.dtype), 'uint16');
            testCase.verifyEqual(char(p.pipeline_version), 'unit-test-1');
            testCase.verifyEqual(char(p.label), 'my volume');
        end

        function testDependencyWiringSubjectAndPyramid(testCase)
            pys = ndi.unittest.fun.doc.lightsheet.TestMakePyramid.twoPyramidsWithSharedLevel0();
            [pdoc, lds, ~] = ndi.fun.doc.lightsheet.makePyramid( ...
                testCase.session, pys, {'mean','max'}, ...
                'subjectID', testCase.subjectID);
            testCase.verifyEqual( ...
                pdoc.dependency_value('subject_id'), testCase.subjectID);
            for k = 1:numel(lds)
                testCase.verifyEqual( ...
                    lds{k}.dependency_value('lightsheetZarrPyramid_id'), ...
                    pdoc.id());
                testCase.verifyEqual( ...
                    lds{k}.dependency_value('subject_id'), testCase.subjectID);
            end
        end

        function testPyramidTypeCarried(testCase)
            % The parent's pyramid_type is the FIRST entry's type. Two
            % pyramids with different types don't collide (they share
            % the parent, since a store is one source volume).
            pys = ndi.unittest.fun.doc.lightsheet.TestMakePyramid.twoPyramidsWithSharedLevel0();
            [pdoc, ~, ~] = ndi.fun.doc.lightsheet.makePyramid( ...
                testCase.session, pys, {'mean','max'}, ...
                'subjectID', testCase.subjectID);
            p = pdoc.document_properties.lightsheetZarrPyramid;
            testCase.verifyEqual(char(p.pyramid_type), 'box');
        end

        function testLevelDocsWrittenToDatabase(testCase)
            L = ndi.unittest.fun.doc.lightsheet.TestMakePyramid.dyadicLevels( ...
                {'0','1'}, [64 128 128], [1 1 1], 'uint16');
            py = ndi.unittest.fun.doc.lightsheet.TestMakePyramid.pyramidEntry( ...
                'mean', 'box', L);
            [~, lds] = ndi.fun.doc.lightsheet.makePyramid( ...
                testCase.session, py, {'mean'}, ...
                'subjectID', testCase.subjectID);
            for k = 1:numel(lds)
                back = testCase.session.database_search( ...
                    ndi.query('base.id', 'exact_string', lds{k}.id()));
                testCase.verifyEqual(numel(back), 1);
            end
        end

    end
end
