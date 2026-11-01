classdef TestLightsheetMigrated < matlab.unittest.TestCase
%TESTLIGHTSHEETMIGRATED The lightsheet readers over documents the REAL migrator made.
%
%   ndi.unittest.vintage.TestLightsheetMigratedSession reads hand-built
%   documents, shaped from DID-matlab's migrators. This class removes the
%   "shaped from": it runs did2.convert.v1_to_v2 (TargetVersion V_eta) and
%   the did2.convert.foldGenericFiles batch pass over v1 documents shaped as
%   NDI's makePyramid writes them -- a pyramid, its OME-Zarr fileReference,
%   level 0 with two materialized chunks (chunk.bin_1, chunk.bin_2, recorded
%   by location), a reduced max level with one chunk, and a level that held
%   no bytes (kept as a file-less sampled_body, [compression block and
%   empty levels], Jess Haley 2026-10-26) -- writes what comes out into a V2 session, reopens it with
%   ndi.session.dir, and asks the same readers.
%
%   NEEDS DID-matlab's lightsheet migrators (DID-matlab #218, f363d98 and
%   later: the method and the label on notes, Jess 2026-10-15) and the
%   composition did-schema they target (did-schema #88).
%
%   UNVERIFIED: written without MATLAB; test-import-v2.yml is the first run.

    properties
        Dir
        Session
        Out
        Chunk1
    end

    methods (TestClassSetup)
        function migrateAndWrite(testCase)
            testCase.assumeTrue(~isempty(which('did2.build.document')), ...
                'did2.build (DID-matlab V2) is not on the path');
            schemaPath = getenv('DID_SCHEMA_PATH');
            testCase.assumeTrue(~isempty(schemaPath) && ...
                isfile(ndi.v2.schemaFile(schemaPath, 'entity.json')), ...
                'DID_SCHEMA_PATH does not hold a V2 schema with `entity` (did-schema #88)');
            testCase.assertTrue(~isempty(which('did2.convert.migrators_j.lightsheet_zarr_level')), ...
                'DID-matlab''s lightsheet migrators are not on the path');
            F = ndi.unittest.vintage.LightsheetFixtures;
            testCase.Dir = tempname;
            mkdir(testCase.Dir);
            testCase.addTeardown(@() rmdir(testCase.Dir, 's'));
            bytes = fullfile(testCase.Dir, 'bytes');
            mkdir(bytes);
            testCase.Chunk1 = F.tempFile(bytes, 'uid_l0_c1', uint8(1:8));
            c2 = F.tempFile(bytes, 'uid_l0_c2', uint8(9:16));
            m1 = F.tempFile(bytes, 'uid_l1_c1', uint8(17:24));

            batch = {ndi.unittest.vintage.TestLightsheetMigrated.v1Pyramid(), ...
                ndi.unittest.vintage.TestLightsheetMigrated.v1FileReference(), ...
                F.v1Level('lvl_ls_0', 'pyr_ls_1', 0, 'none', {testCase.Chunk1, c2}), ...
                F.v1Level('lvl_ls_1_max', 'pyr_ls_1', 1, 'max', {m1}), ...
                F.v1Level('lvl_ls_1_mean', 'pyr_ls_1', 1, 'mean', {})};
            out = did2.convert.v1_to_v2(batch, 'Validate', true, 'TargetVersion', 'did_v2');
            [out, ~] = did2.convert.foldGenericFiles(out, 'Validate', true, 'TargetVersion', 'did_v2');
            testCase.assertEmpty(out.quarantine, ...
                ndi.unittest.vintage.TestLightsheetMigrated.reasons(out));
            testCase.Out = cellfun(@(d) d.toStruct(), out.migrated, 'UniformOutput', false);

            sessionDir = fullfile(testCase.Dir, 'session');
            mkdir(sessionDir);
            ndi.setup.V2.createSession(sessionDir, 'lightsheet migrated', ...
                'SessionId', F.sessionId(), 'Documents', testCase.Out, 'Validate', false);
            testCase.Session = ndi.session.dir(sessionDir);
        end
    end

    methods (Test)

        function testTheMethodIsTheMigrators(testCase)
            % ndi.vintage.lightsheetPyramidDocs finds migrated pyramids by
            % this method node (Jess 2026-10-15), on the path
            % interaction.method.term.node; it must be the migrator's, character
            % for character, and at that path.
            obs = [];
            for k = 1:numel(testCase.Out)
                if strcmp(testCase.Out{k}.base.id, 'pyr_ls_1'), obs = testCase.Out{k}; end
            end
            testCase.assertNotEmpty(obs, 'the pyramid''s observation');
            m = ndi.v2.blockOf(obs, 'interaction', 'method', []);
            if iscell(m), m = m{1}; end
            testCase.assertTrue(isstruct(m) && isfield(m, 'term'), ...
                'the migrated pyramid carries interaction.method.term (did-schema #88)');
            m = m.term;
            M = ndi.vintage.lightsheetMethod();
            testCase.verifyEqual(char(m.node), M.node);
            testCase.verifyEqual(char(m.name), M.name);
        end

        function testTheLabelStaysOnTheObservation(testCase)
            % Jess 2026-10-15: the label is the observation's notes after the
            % batch pass, and the store body's description holds the NGFF
            % multiscales name only.
            d = testCase.Session.database_search(ndi.query('base.id', 'exact_string', 'pyr_ls_1'));
            testCase.assertNumElements(d, 1);
            testCase.verifyEqual(char(ndi.v2.blockOf(d{1}.document_properties, ...
                'statement', 'notes', '')), 'brain 7 cleared');
            [p, vintage] = ndi.vintage.lightsheetPyramid(d{1}, testCase.Session);
            testCase.verifyEqual(vintage, 'V_eta');
            testCase.verifyEqual(p.label, 'brain 7 cleared');
            testCase.verifyEqual(p.pyramid_name, 'mean');
            % [pyramid type kept as text] (Jess Haley, 2026-10-25): the writer's
            % NGFF multiscales type is kept verbatim in the store body's
            % description. INVERTED: it was dropped (Jess 2026-10-15).
            testCase.verifyEqual(p.pyramid_type, 'mean', 'pyramid_type is kept as text');
        end

        function testWithoutThePassTheReaderStillGetsTheLabel(testCase)
            % A bare v1_to_v2 call leaves the multiscales name after the
            % migrator's separator in notes; the reader's separator must be
            % the same literal, so the label it reads is the label alone.
            out = did2.convert.v1_to_v2({ndi.unittest.vintage.TestLightsheetMigrated.v1Pyramid()}, ...
                'Validate', true, 'TargetVersion', 'did_v2');
            testCase.assertEmpty(out.quarantine, ...
                ndi.unittest.vintage.TestLightsheetMigrated.reasons(out));
            obs = [];
            for k = 1:numel(out.migrated)
                d = out.migrated{k}.toStruct();
                if strcmp(d.base.id, 'pyr_ls_1'), obs = d; end
            end
            testCase.assertNotEmpty(obs);
            notes = char(ndi.v2.blockOf(obs, 'statement', 'notes', ''));
            testCase.verifySubstring(notes, 'NGFF multiscales name "mean"', ...
                'without the pass the name is still on the notes');
            p = ndi.vintage.lightsheetPyramid(obs);
            testCase.verifyEqual(p.label, 'brain 7 cleared');
        end

        function testTheMigratedPyramidIsFoundAndListed(testCase)
            docs = ndi.vintage.lightsheetPyramidDocs(testCase.Session);
            ids = cellfun(@(d) d.id(), docs, 'UniformOutput', false);
            testCase.verifyEqual(ids, {'pyr_ls_1'}, ...
                'the pyramid keeps its id, and is found by its method');
            rows = ndi.gui.app.LightsheetZarrManager.pyramidRows(testCase.Session);
            testCase.verifyNumElements(rows, 1);
            testCase.verifyEqual(rows(1).subjectID, 'subj_ls_1');
            % [compression block and empty levels] (Jess Haley, 2026-10-26),
            % part 2: a level that held no bytes becomes a file-less
            % sampled_body that keeps its id and metadata, so it is still
            % listed, as it is in v1. INVERTED: #73 L3(c) folded it to nothing.
            testCase.verifyEqual(rows(1).nLevels, 3, ...
                'the level that held no bytes is kept, file-less');
            testCase.verifyEqual(rows(1).reduction, 'max/mean');
            testCase.verifyEqual(rows(1).label, 'brain 7 cleared');
            testCase.verifyEqual(rows(1).dtype, '<u2');
        end

        function testLevelTableReadsTheMigratorsOutput(testCase)
            t = ndi.fun.doc.lightsheet.levelTable(testCase.Session, 'pyr_ls_1');
            % [compression block and empty levels] (Jess Haley, 2026-10-26),
            % part 2: the level that held no bytes (lvl_ls_1_mean) is a
            % file-less sampled_body with its id kept, read back with no
            % stored chunks. INVERTED: #73 L3(c) folded it to nothing. The two
            % level-1 rows share a level, so their order is not asserted.
            testCase.verifyEqual(height(t), 3);
            testCase.verifyEqual(t.level.', [0 1 1]);
            testCase.verifyEqual(t.id{1}, 'lvl_ls_0', 'level ids kept (point 11)');
            testCase.verifyEqual(sort(t.id(2:3)).', {'lvl_ls_1_max', 'lvl_ls_1_mean'}, ...
                'level ids kept (point 11)');
            iMax = find(strcmp(t.id, 'lvl_ls_1_max'));
            iMean = find(strcmp(t.id, 'lvl_ls_1_mean'));
            testCase.verifyEqual(t.reduction_function{1}, 'none');
            testCase.verifyEqual(t.reduction_function{iMax}, 'max');
            testCase.verifyEqual(t.reduction_function{iMean}, 'mean');
            testCase.verifyEqual(t.shape{1}, [1 2 400 2048 2048]);
            testCase.verifyEqual(t.shape{iMax}, [1 2 200 1024 1024]);
            testCase.verifyEqual(t.shape{iMean}, [1 2 200 1024 1024], ...
                'the empty level keeps its dimensions');
            testCase.verifyEqual(t.chunks{1}, [1 1 64 256 256]);
            testCase.verifyEqual(t.n_chunks_stored([1 iMax iMean]).', [2 1 0], ...
                'the empty level stores no chunks');
            testCase.verifyEqual(t.voxel_size{1}([3 4 5]), [2 0.5 0.5], 'AbsTol', 1e-9, ...
                'z/y/x voxel size in micrometre, as the v1 level said');
            testCase.verifyEqual(t.voxel_size{iMax}([3 4 5]), [4 1 1], 'AbsTol', 1e-9);
            testCase.verifyEqual(t.translation{1}(3), 10, 'AbsTol', 1e-9);
            testCase.verifyEqual(t.dtype{1}, '<u2');
            f = t.Properties.UserData;
            testCase.verifyEqual(f.axes_order, 'tczyx');
            testCase.verifyEqual(f.pyramid_name, 'mean');
            testCase.verifyEqual(f.voxel_size_level0([3 4 5]), [2 0.5 0.5], 'AbsTol', 1e-9);
            % Two level-1 rows tie on voxel size; a caller picks its
            % reduction first (levelTable's 'reduction' option).
            tMax = ndi.fun.doc.lightsheet.levelTable(testCase.Session, 'pyr_ls_1', ...
                'reduction', 'max');
            testCase.verifyEqual(tMax.id.', {'lvl_ls_0', 'lvl_ls_1_max'});
            [idx, row] = ndi.fun.doc.lightsheet.chooseLevel(tMax, 4);
            testCase.verifyEqual(idx, 1);
            testCase.verifyEqual(row.id{1}, 'lvl_ls_1_max');
        end

        function testChooseLevelSkipsTheEmptyLevelInATie(testCase)
            % [chooseLevel skips empty levels] (Jess Haley, 2026-10-26): on
            % the whole table, with no reduction picked first, the two
            % level-1 rows tie on voxel size and lvl_ls_1_mean stores no
            % bytes (the file-less sampled_body of [compression block and
            % empty levels]); the level that holds bytes is chosen, in either
            % order of the two level-1 rows.
            t = ndi.fun.doc.lightsheet.levelTable(testCase.Session, 'pyr_ls_1');
            testCase.assertEqual(height(t), 3);
            [idx, row] = ndi.fun.doc.lightsheet.chooseLevel(t, 4);
            testCase.verifyEqual(idx, 1);
            testCase.verifyEqual(row.id{1}, 'lvl_ls_1_max');
            [idx, row] = ndi.fun.doc.lightsheet.chooseLevel(t([1 3 2], :), 4);   % the two level-1 rows swapped
            testCase.verifyEqual(idx, 1);
            testCase.verifyEqual(row.id{1}, 'lvl_ls_1_max', 'with the two level-1 rows in either order');
        end

        function testALevelsUnitsAndChannelNamesCameFromItsPyramid(testCase)
            d = testCase.Session.database_search(ndi.query('base.id', 'exact_string', 'lvl_ls_0'));
            testCase.assertNumElements(d, 1);
            k = ndi.vintage.lightsheetKeys(ndi.v2.blockOf(d{1}.document_properties, 'data', 'dimensions'), ...
                ndi.v2.blockOf(d{1}.document_properties, 'data', 'covariates'));
            testCase.verifyEqual(k.units{1}, 'second', 'the t unit, from the pyramid (point 8)');
            testCase.verifyEqual(k.units{3}, 'micrometer');
            testCase.verifyEqual(k.channel_names, 'GCaMP6s,tdTomato');
        end

        function testLevelZerosMemberZeroIsChunkBinOne(testCase)
            d = testCase.Session.database_search(ndi.query('base.id', 'exact_string', 'lvl_ls_0'));
            testCase.assertNumElements(d, 1);
            name = ndi.vintage.lightsheetChunkName(d{1}, 1);
            testCase.verifyEqual(name, 'body_data_0');
            [tf, p] = testCase.Session.database_existbinarydoc('lvl_ls_0', name);
            testCase.verifyTrue(tf, 'member 0 of the migrated level must resolve');
            testCase.verifyEqual(fileread(p), fileread(testCase.Chunk1), ...
                'body_data_0 is the bytes chunk.bin_1 named');
            [tf, ~] = testCase.Session.database_existbinarydoc('lvl_ls_0', 'body_data_2');
            testCase.verifyFalse(tf, 'two chunks: there is no member 2');
        end

    end

    methods (Static)

        function v1 = v1Pyramid()
            %V1PYRAMID A lightsheetZarrPyramid as makePyramid writes one from
            %   an OME-Zarr store (fromOMEZarr). Shaped as DID-matlab's
            %   testMigratorsJLightsheet.m pyramidV1 fixture.
            v1 = struct();
            v1.document_class = struct('definition', '', 'validation', '', ...
                'class_name', 'lightsheetZarrPyramid', ...
                'property_list_name', 'lightsheetZarrPyramid', 'class_version', 1, ...
                'superclasses', struct('definition', '$NDIDOCUMENTPATH/base.json'));
            v1.depends_on = struct('name', {'subject_id', 'element_id', 'source_file_id'}, ...
                'value', {'subj_ls_1', 'elem_scope_1', 'fref_store_1'});
            v1.base = struct('id', 'pyr_ls_1', ...
                'session_id', ndi.unittest.vintage.LightsheetFixtures.sessionId(), ...
                'name', '', 'datestamp', '2026-10-01T12:00:00.000Z');
            v1.lightsheetZarrPyramid = struct( ...
                'label', 'brain 7 cleared', 'pyramid_name', 'mean', 'pyramid_type', 'mean', ...
                'axes_order', 'tczyx', ...
                'axes_units', 'second,,micrometer,micrometer,micrometer', ...
                'channel_names', 'GCaMP6s,tdTomato', 'n_channels', 2, ...
                'shape_level0', [1 2 400 2048 2048], ...
                'voxel_size_level0', [1 1 2 0.5 0.5], 'voxel_size_units', 'micrometer', ...
                'translation_level0', [0 0 10 0 0], 'dtype', '<u2', ...
                'pipeline_version', 'lightsheet-pipeline 0.3.1', 'byte_order', 'little');
        end

        function v1 = v1FileReference()
            v1 = struct();
            v1.document_class = struct('definition', '', 'validation', '', ...
                'class_name', 'fileReference', 'property_list_name', 'fileReference', ...
                'class_version', 1, ...
                'superclasses', struct('definition', '$NDIDOCUMENTPATH/base.json'));
            v1.depends_on = struct('name', {}, 'value', {});
            v1.base = struct('id', 'fref_store_1', ...
                'session_id', ndi.unittest.vintage.LightsheetFixtures.sessionId(), ...
                'name', '', 'datestamp', '2026-10-01T12:00:00.000Z');
            v1.fileReference = struct('filename', 'brain7.ome.zarr', ...
                'originalPath', '/data/stores/brain7.ome.zarr', 'formatOntology', '', ...
                'dateCreated', datenum(2024, 1, 2, 3, 4, 5), ...
                'dateUpdated', datenum(2024, 1, 3, 3, 4, 5), 'fileSize', 0, ...
                'checksum', '0123456789abcdef0123456789abcdef', 'checksumAlgorithm', 'MD5');
        end

        function msg = reasons(out)
            arguments
                out (1,1) struct
            end
            msg = 'no quarantined documents';
            if isempty(out.quarantine), return; end
            msg = '';
            for k = 1:numel(out.quarantine)
                msg = [msg sprintf('[%s] %s\n', out.quarantine(k).class_name, ...
                    out.quarantine(k).reason)]; %#ok<AGROW>
            end
        end

    end
end
