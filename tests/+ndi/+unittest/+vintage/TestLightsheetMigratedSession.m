classdef TestLightsheetMigratedSession < matlab.unittest.TestCase
%TESTLIGHTSHEETMIGRATEDSESSION The lightsheet readers over a V2 session holding a MIGRATED pyramid.
%
%   Writes, into a V2 (did2) session made by ndi.setup.V2.createSession and
%   reopened with the ordinary ndi.session.dir, one pyramid as DID-matlab's
%   lightsheet migration leaves it (ndi.unittest.vintage.LightsheetFixtures):
%   the intensity observation, its builder software entity, its OME-Zarr
%   store's unheld opaque_body, and three level sampled_bodies -- level 0
%   (two chunks, recorded by location as body_data_0 and body_data_1), and
%   one reduced level each of max and mean. Then asks the readers:
%   levelTable, chooseLevel, LightsheetZarrManager's rows and deletion plan,
%   and whether a level's member 0 resolves to its bytes.
%
%   Filtered (never passed) when did2.build or a V2 schema with `study` is
%   missing, as TestCreateSession is; test-import-v2.yml fails on a
%   filtered test, so a green run means these ran.
%
%   UNVERIFIED: written without MATLAB; test-import-v2.yml is the first run.

    properties
        Dir
        Session
        Member0
    end

    methods (TestClassSetup)
        function needV2(testCase)
            testCase.assumeTrue(~isempty(which('did2.build.document')), ...
                'did2.build (DID-matlab V2) is not on the path');
            schemaPath = getenv('DID_SCHEMA_PATH');
            testCase.assumeTrue(~isempty(schemaPath) && ...
                isfile(ndi.v2.schemaFile(schemaPath, 'entity.json')), ...
                'DID_SCHEMA_PATH does not hold a V2 schema with `entity` (did-schema #88)');
            % One method, not two: TestClassSetup methods run in no
            % guaranteed order, and the write needs the checks above first.
            F = ndi.unittest.vintage.LightsheetFixtures;
            testCase.Dir = tempname;
            mkdir(testCase.Dir);
            testCase.addTeardown(@() rmdir(testCase.Dir, 's'));
            bytes = fullfile(testCase.Dir, 'bytes');
            mkdir(bytes);
            testCase.Member0 = F.tempFile(bytes, 'uid_level0_chunk0', uint8(1:8));
            m1 = F.tempFile(bytes, 'uid_level0_chunk1', uint8(9:16));
            % A DECOY: an intensity observation with the same builder
            % software but no light-sheet method. The finder keys on the
            % method (Jess 2026-10-15), so it must NOT be listed.
            decoy = F.pyramid('obs_not_lightsheet', 'sw_ls_1');
            decoy.interaction = struct('method', struct('term', struct('node', '', 'name', '')));
            decoy.statement.notes = '';
            docs = {F.software('sw_ls_1'), ...
                F.pyramid('pyr_ls_1', 'sw_ls_1'), decoy, ...
                F.store('fref_store_1', 'pyr_ls_1'), ...
                F.level('lvl_0', 'pyr_ls_1', 1, '', {testCase.Member0, m1}), ...
                F.level('lvl_max1', 'pyr_ls_1', 2, 'max', {}), ...
                F.level('lvl_mean1', 'pyr_ls_1', 2, 'mean', {})};
            sessionDir = fullfile(testCase.Dir, 'session');
            mkdir(sessionDir);
            ndi.setup.V2.createSession(sessionDir, 'lightsheet migrated', ...
                'SessionId', F.sessionId(), 'Documents', docs, 'Validate', false);
            testCase.Session = ndi.session.dir(sessionDir);
        end
    end

    methods (Test)

        function testTheMigratedPyramidIsFound(testCase)
            docs = ndi.vintage.lightsheetPyramidDocs(testCase.Session);
            ids = cellfun(@(d) d.id(), docs, 'UniformOutput', false);
            testCase.verifyEqual(ids, {'pyr_ls_1'}, ...
                ['exactly the observation whose method is light-sheet ' ...
                 'microscopy, not every observation of the builder software']);
        end

        function testLevelTableReadsTheMigratedLevels(testCase)
            t = ndi.fun.doc.lightsheet.levelTable(testCase.Session, 'pyr_ls_1');
            testCase.verifyEqual(height(t), 3);
            testCase.verifyEqual(t.level.', [0 1 1]);
            testCase.verifyEqual(t.id{1}, 'lvl_0', 'the level keeps its v1 id');
            testCase.verifyEqual(sort(t.reduction_function(2:3)).', {'max', 'mean'});
            testCase.verifyEqual(t.reduction_function{1}, 'none');
            testCase.verifyEqual(t.shape{1}, [1 2 400 2048 2048]);
            testCase.verifyEqual(t.shape{2}, [1 2 200 1024 1024]);
            testCase.verifyEqual(t.chunks{1}, [1 1 64 256 256]);
            testCase.verifyEqual(t.chunk_grid{1}, [1 2 7 8 8]);
            testCase.verifyEqual(t.n_chunks_stored(1), 2);
            testCase.verifyEqual(t.voxel_size{1}, [1 1 2 0.5 0.5], 'AbsTol', 1e-12, ...
                'micrometre, as v1 -- not the canonical meter');
            testCase.verifyEqual(t.voxel_size{2}, [1 1 4 1 1], 'AbsTol', 1e-12);
            testCase.verifyEqual(t.translation{1}, [0 0 10 0 0], 'AbsTol', 1e-12);
            testCase.verifyEqual(t.dtype{1}, '<u2');

            f = t.Properties.UserData;
            testCase.verifyEqual(f.id, 'pyr_ls_1');
            testCase.verifyEqual(f.axes_order, 'tczyx');
            testCase.verifyEqual(f.dtype, '<u2');
            testCase.verifyEqual(f.pyramid_name, 'mean', 'parsed from the store body');
            testCase.verifyEqual(f.voxel_size_level0, [1 1 2 0.5 0.5], 'AbsTol', 1e-12);
            testCase.verifyEqual(f.translation_level0, [0 0 10 0 0], 'AbsTol', 1e-12);
            testCase.verifyEqual(sort(f.reductions(:)).', {'max', 'mean'});
        end

        function testTheReductionFilterKeepsLevelZero(testCase)
            t = ndi.fun.doc.lightsheet.levelTable(testCase.Session, 'pyr_ls_1', ...
                'reduction', 'max');
            testCase.verifyEqual(height(t), 2);
            testCase.verifyEqual(t.reduction_function.', {'none', 'max'});
        end

        function testChooseLevelOnTheMigratedTable(testCase)
            % INVERTED by [chooseLevel skips empty levels] (Jess Haley,
            % 2026-10-26): lvl_mean1 is written with no members, so it
            % stores no bytes and is never chosen while level 0 (two chunks)
            % is there. It was chosen for a 4 um target before.
            t = ndi.fun.doc.lightsheet.levelTable(testCase.Session, 'pyr_ls_1', ...
                'reduction', 'mean');
            testCase.assertEqual(t.n_chunks_stored.', [2 0], ...
                'the fixture: level 0 stores two chunks, the mean level none');
            [idx, row] = ndi.fun.doc.lightsheet.chooseLevel(t, 4);
            testCase.verifyEqual(idx, 0);
            testCase.verifyEqual(row.id{1}, 'lvl_0');
            idx = ndi.fun.doc.lightsheet.chooseLevel(t, 2);
            testCase.verifyEqual(idx, 0);
        end

        function testTheManagerListsTheMigratedPyramid(testCase)
            rows = ndi.gui.app.LightsheetZarrManager.pyramidRows(testCase.Session);
            testCase.verifyNumElements(rows, 1);
            testCase.verifyEqual(rows(1).id, 'pyr_ls_1');
            testCase.verifyEqual(rows(1).label, 'brain 7 cleared', ...
                'the label is the observation''s notes (Jess 2026-10-15)');
            testCase.verifyEqual(rows(1).subjectID, 'subj_ls_1');
            testCase.verifyEqual(rows(1).nLevels, 3);
            testCase.verifyEqual(rows(1).reduction, 'max/mean');
            testCase.verifyEqual(rows(1).shapeLevel0, [1 2 400 2048 2048]);
            testCase.verifyEqual(rows(1).dtype, '<u2');
        end

        function testTheDeletionPlanTakesTheLevelsAndTheStoreRecord(testCase)
            plan = ndi.gui.app.LightsheetZarrManager.deletionPlan( ...
                testCase.Session, 'pyr_ls_1');
            testCase.verifyEqual(plan.nLevels, 3);
            testCase.verifyEqual(plan.nStoreRecords, 1);
            ids = sort(cellfun(@(d) d.id(), plan.docsToRemove, 'UniformOutput', false));
            testCase.verifyEqual(ids(:).', sort({'lvl_0', 'lvl_max1', 'lvl_mean1', ...
                'fref_store_1', 'pyr_ls_1'}));
            msg = ndi.gui.app.LightsheetZarrManager.deletionMessage(plan, 'p');
            testCase.verifySubstring(msg, '5 document');
            testCase.verifySubstring(msg, '1 store record');
        end

        function testLevelZerosFirstChunkIsMemberZero(testCase)
            d = testCase.Session.database_search(ndi.query('base.id', 'exact_string', 'lvl_0'));
            testCase.assertNumElements(d, 1);
            name = ndi.vintage.lightsheetChunkName(d{1}, 1);
            testCase.verifyEqual(name, 'body_data_0');
            [tf, p] = testCase.Session.database_existbinarydoc('lvl_0', name);
            testCase.verifyTrue(tf, 'member 0 of the migrated level must resolve');
            testCase.verifyEqual(fileread(p), fileread(testCase.Member0), ...
                'and to the bytes chunk.bin_1 named');
        end

    end
end
