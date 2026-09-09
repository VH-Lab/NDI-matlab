classdef TestLevelTable < matlab.unittest.TestCase
    % TestLevelTable - level enumeration + reduction filter.
    %
    % Exercises levelTable across the empty case, the mean+max ladder
    % with a shared level 0 (5 rows: 'none', mean/1, mean/2, max/1,
    % max/2), and the reduction filter that returns raw + one reduction.

    properties
        session
        subjectID
        pyramidDoc
    end

    methods (TestMethodSetup)
        function build(testCase)
            d = fullfile(tempname, 'leveltable');
            mkdir(d);
            testCase.addTeardown(@() rmdir(fileparts(d), 's'));
            S = ndi.session.dir('leveltable', d);
            sub = ndi.document('subject', 'base.session_id', S.id(), ...
                'subject.local_identifier', 'lightsheet@vhlab');
            S.database_add(sub);
            testCase.session = S;
            testCase.subjectID = sub.id();
        end
    end

    methods (Access = private)
        function buildTwoPyramidsWithLevels(testCase)
            pys = ndi.unittest.fun.doc.lightsheet.TestMakePyramid.twoPyramidsWithSharedLevel0();
            [pdoc, ~, ~] = ndi.fun.doc.lightsheet.makePyramid( ...
                testCase.session, pys, {'mean','max'}, ...
                'subjectID', testCase.subjectID);
            testCase.pyramidDoc = pdoc;
        end
    end

    methods (Test)

        function testEmptyPyramidReturnsEmptyTable(testCase)
            % Build a parent with NO levels, verify the table is empty
            % but has the expected columns and frame.
            L = ndi.unittest.fun.doc.lightsheet.TestMakePyramid.dyadicLevels( ...
                {'0'}, [16 32 32], [1 1 1], 'uint16');
            py = ndi.unittest.fun.doc.lightsheet.TestMakePyramid.pyramidEntry( ...
                'mean', 'box', L);
            [pdoc, ~, ~] = ndi.fun.doc.lightsheet.makePyramid( ...
                testCase.session, py, {'mean'}, ...
                'subjectID', testCase.subjectID);
            % Delete the single level, leaving the parent with no
            % children -- levelTable's empty path.
            docs = testCase.session.database_search( ...
                ndi.query('', 'isa', 'lightsheetZarrLevel') & ...
                ndi.query('depends_on', 'depends_on', ...
                    'lightsheetZarrPyramid_id', pdoc.id()));
            for k = 1:numel(docs)
                testCase.session.database_rm(docs{k});
            end
            t = ndi.fun.doc.lightsheet.levelTable(testCase.session, pdoc);
            testCase.verifyEqual(height(t), 0);
            testCase.verifyTrue(ismember('reduction_function', ...
                t.Properties.VariableNames));
            % UserData still carries the parent frame.
            f = t.Properties.UserData;
            testCase.verifyEqual(f.axes_order, 'zyx');
        end

        function testFullLadderReturnsFiveRowsSortedFinestFirst(testCase)
            testCase.buildTwoPyramidsWithLevels();
            t = ndi.fun.doc.lightsheet.levelTable( ...
                testCase.session, testCase.pyramidDoc);
            testCase.verifyEqual(height(t), 5);
            testCase.verifyEqual(t.level(1), 0);
            testCase.verifyEqual(t.reduction_function{1}, 'none');
            testCase.verifyTrue(all(diff(t.level) >= 0));
            % Frame carries the reductions present in the ladder.
            f = t.Properties.UserData;
            testCase.verifyEqual( ...
                sort(f.reductions(:).'), {'max','mean'});
        end

        function testAcceptsIDInsteadOfDoc(testCase)
            testCase.buildTwoPyramidsWithLevels();
            t = ndi.fun.doc.lightsheet.levelTable( ...
                testCase.session, testCase.pyramidDoc.id());
            testCase.verifyEqual(height(t), 5);
        end

        function testUnknownIDErrors(testCase)
            testCase.verifyError(@() ndi.fun.doc.lightsheet.levelTable( ...
                testCase.session, '00000000-0000-0000-0000-000000000000'), ...
                'NDI:lightsheet:levelTable:noParent');
        end

        function testReductionFilterKeepsSharedAndOneReduction(testCase)
            testCase.buildTwoPyramidsWithLevels();
            t = ndi.fun.doc.lightsheet.levelTable( ...
                testCase.session, testCase.pyramidDoc, ...
                'reduction', 'max');
            % raw level 0 + max/1 + max/2 = 3.
            testCase.verifyEqual(height(t), 3);
            testCase.verifyTrue(all( ...
                strcmp(t.reduction_function, 'none') | ...
                strcmp(t.reduction_function, 'max')));
            testCase.verifyFalse(any(strcmp(t.reduction_function, 'mean')));
        end

        function testTableColumnsMatchSchema(testCase)
            testCase.buildTwoPyramidsWithLevels();
            t = ndi.fun.doc.lightsheet.levelTable( ...
                testCase.session, testCase.pyramidDoc);
            expected = {'level','reduction_function','shape','chunks', ...
                'chunk_grid','n_chunks_stored','voxel_size', ...
                'translation','dtype','id'};
            testCase.verifyEqual(t.Properties.VariableNames, expected);
        end

    end
end
