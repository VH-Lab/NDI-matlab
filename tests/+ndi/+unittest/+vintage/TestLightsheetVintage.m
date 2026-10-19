classdef TestLightsheetVintage < matlab.unittest.TestCase
%TESTLIGHTSHEETVINTAGE The lightsheet readers' vintage layer, without a database.
%
%   NDI's lightsheet readers (ndi.fun.doc.lightsheet.levelTable / chooseLevel,
%   makePyramid's chunk reads, ndi.gui.app.LightsheetZarrManager) read a
%   pyramid and its levels by v1 names. A MIGRATED pyramid is an intensity
%   `observation` and its levels `sampled_body` documents, with every value
%   moved: shape/voxel size into `keys`, the reduction into a condition, the
%   dtype onto the pyramid, the chunk series renamed and renumbered from 0.
%   ndi.vintage.lightsheetLevel / lightsheetLevels / lightsheetPyramid read
%   both back by v1 name; these tests hold that, one fact at a time, on
%   documents built by hand (ndi.unittest.vintage.LightsheetFixtures).
%
%   The other half is the series numbering every file walker shares
%   (ndi.vintage.seriesMemberBase), tested through
%   ndi.database.fun.extract_docs_files against a fake session.
%
%   See also: ndi.unittest.vintage.TestLightsheetMigratedSession,
%             ndi.unittest.vintage.TestLightsheetMigrated.

    properties
        Dir
    end

    methods (TestMethodSetup)
        function makeDir(testCase)
            testCase.Dir = tempname;
            mkdir(testCase.Dir);
            testCase.addTeardown(@() rmdir(testCase.Dir, 's'));
        end
    end

    methods (Test)

        % ===================== v1 is read exactly as before ============

        function testAV1LevelIsItsOwnBlockUntouched(testCase)
            F = ndi.unittest.vintage.LightsheetFixtures;
            s = F.v1Level('lvl_1', 'pyr_ls_1', 1, 'mean', {});
            d = ndi.document(s);
            [p, vintage] = ndi.vintage.lightsheetLevel(d);
            testCase.verifyEqual(vintage, 'v1');
            testCase.verifyEqual(p, d.document_properties.lightsheetZarrLevel, ...
                'a v1 level must be read as its own block, nothing recomputed');
            [recs, v] = ndi.vintage.lightsheetLevels({d}, []);
            testCase.verifyEqual(v, {'v1'});
            testCase.verifyEqual(recs{1}.level, 1, 'a v1 level keeps its own index');
        end

        function testAV1ChunkIsChunkBinFromOne(testCase)
            F = ndi.unittest.vintage.LightsheetFixtures;
            d = ndi.document(F.v1Level('lvl_0', 'pyr_ls_1', 0, 'none', {}));
            testCase.verifyEqual(ndi.vintage.seriesMemberBase(d), 1);
            testCase.verifyEqual(ndi.vintage.lightsheetChunkName(d, 1), 'chunk.bin_1');
            testCase.verifyEqual(ndi.vintage.lightsheetChunkName(d, 7), 'chunk.bin_7');
        end

        % ===================== a migrated level ========================

        function testAMigratedLevelZeroReadsBackByV1Name(testCase)
            F = ndi.unittest.vintage.LightsheetFixtures;
            pyr = ndi.document(F.pyramid('pyr_ls_1', 'sw_1'));
            d = ndi.document(F.level('lvl_0', 'pyr_ls_1', 1, '', {}));
            [p, vintage] = ndi.vintage.lightsheetLevel(d, pyr);
            testCase.verifyEqual(vintage, 'V_eta');
            testCase.verifyEqual(p.axes_order, 'tczyx');
            testCase.verifyEqual(p.shape, [1 2 400 2048 2048]);
            testCase.verifyEqual(p.chunks, [1 1 64 256 256]);
            testCase.verifyEqual(p.chunk_grid, [1 2 7 8 8]);
            testCase.verifyEqual(p.voxel_size, [1 1 2 0.5 0.5], 'AbsTol', 1e-12, ...
                'voxel size in the SOURCE unit (micrometre), as v1, not the canonical meter');
            testCase.verifyEqual(p.translation, [0 0 10 0 0], 'AbsTol', 1e-12);
            testCase.verifyEqual(p.voxel_size_units, 'micrometer');
            testCase.verifyEqual(p.dtype, '<u2', 'the pyramid''s source_data_type');
            testCase.verifyEqual(p.reduction_function, 'none');
            testCase.verifyFalse(p.redundant);
            testCase.verifyEqual(p.codec, 'raw');
            testCase.verifyEqual(p.chunk_order, 'C');
            testCase.verifyEqual(p.byte_order, 'little');
            testCase.verifyEqual(p.fill_value, 0);
            testCase.verifyEqual(p.chunk_index_origin, 0);
        end

        function testAReducedLevelReadsItsReductionFromItsCondition(testCase)
            F = ndi.unittest.vintage.LightsheetFixtures;
            dMax = ndi.document(F.level('lvl_max1', 'pyr_ls_1', 2, 'max', {}));
            dMean = ndi.document(F.level('lvl_mean1', 'pyr_ls_1', 2, 'mean', {}));
            dMin = ndi.document(F.level('lvl_min1', 'pyr_ls_1', 2, 'minimum', {}));
            pMax = ndi.vintage.lightsheetLevel(dMax);
            testCase.verifyEqual(pMax.reduction_function, 'max', 'NCIT:C25564');
            testCase.verifyTrue(pMax.redundant);
            testCase.verifyEqual(pMax.codec, 'blosc');
            testCase.verifyEqual(pMax.shape, [1 2 200 1024 1024]);
            testCase.verifyEqual(pMax.voxel_size, [1 1 4 1 1], 'AbsTol', 1e-12);
            pMean = ndi.vintage.lightsheetLevel(dMean);
            testCase.verifyEqual(pMean.reduction_function, 'mean', 'NCIT:C53319');
            pMin = ndi.vintage.lightsheetLevel(dMin);
            testCase.verifyEqual(pMin.reduction_function, 'min', ...
                'a name-only statistic is read by its name');
            testCase.verifyEqual(pMax.dtype, '', 'no pyramid given, no dtype');
        end

        function testLevelIndicesAreDerivedFromTheSet(testCase)
            % The migration drops `level`; level 0 is the non-redundant body
            % and each reduction's ladder is ranked finest-first.
            F = ndi.unittest.vintage.LightsheetFixtures;
            pyr = ndi.document(F.pyramid('pyr_ls_1', 'sw_1'));
            docs = {ndi.document(F.level('mean2', 'pyr_ls_1', 4, 'mean', {})), ...
                    ndi.document(F.level('max1', 'pyr_ls_1', 2, 'max', {})), ...
                    ndi.document(F.level('l0', 'pyr_ls_1', 1, '', {})), ...
                    ndi.document(F.level('mean1', 'pyr_ls_1', 2, 'mean', {})), ...
                    ndi.document(F.level('max2', 'pyr_ls_1', 4, 'max', {}))};
            recs = ndi.vintage.lightsheetLevels(docs, pyr);
            levels = cellfun(@(r) r.level, recs);
            testCase.verifyEqual(levels, [2 1 0 1 2]);
            red = cellfun(@(r) r.reduction_function, recs, 'UniformOutput', false);
            testCase.verifyEqual(red, {'mean', 'max', 'none', 'mean', 'max'});
        end

        function testAMigratedChunkIsBodyDataFromZero(testCase)
            F = ndi.unittest.vintage.LightsheetFixtures;
            d = ndi.document(F.level('lvl_0', 'pyr_ls_1', 1, '', {}));
            testCase.verifyEqual(ndi.vintage.seriesMemberBase(d), 0);
            testCase.verifyEqual(ndi.vintage.lightsheetChunkName(d, 1), 'body_data_0', ...
                'chunk.bin_1 of the v1 level is body_data_0 of the migrated one');
            testCase.verifyEqual(ndi.vintage.lightsheetChunkName(d, 7), 'body_data_6');
        end

        function testStoredChunksAreCountedFromTheBodysMembers(testCase)
            F = ndi.unittest.vintage.LightsheetFixtures;
            p1 = F.tempFile(testCase.Dir, 'uid_a', uint8(1:4));
            p2 = F.tempFile(testCase.Dir, 'uid_b', uint8(5:8));
            d = ndi.document(F.level('lvl_0', 'pyr_ls_1', 1, '', {p1, p2}));
            p = ndi.vintage.lightsheetLevel(d);
            testCase.verifyEqual(p.n_chunks_stored, 2);
            s = F.level('lvl_0', 'pyr_ls_1', 1, '', {p1, p2});
            s.files.series_info = struct('name', 'body_data', 'count', 112, ...
                'n_present', 112, 'source_root', '');
            p = ndi.vintage.lightsheetLevel(ndi.document(s));
            testCase.verifyEqual(p.n_chunks_stored, 112, 'the series record''s count wins');
        end

        % ===================== a migrated pyramid ======================

        function testAMigratedPyramidFrameComesFromLevelZeroWithoutASession(testCase)
            F = ndi.unittest.vintage.LightsheetFixtures;
            pyr = ndi.document(F.pyramid('pyr_ls_1', 'sw_1'));
            docs = {ndi.document(F.level('max1', 'pyr_ls_1', 2, 'max', {})), ...
                    ndi.document(F.level('l0', 'pyr_ls_1', 1, '', {}))};
            recs = ndi.vintage.lightsheetLevels(docs, pyr);
            [p, vintage] = ndi.vintage.lightsheetPyramid(pyr, [], recs);
            testCase.verifyEqual(vintage, 'V_eta');
            testCase.verifyEqual(p.axes_order, 'tczyx');
            testCase.verifyEqual(p.shape_level0, [1 2 400 2048 2048]);
            testCase.verifyEqual(p.voxel_size_level0, [1 1 2 0.5 0.5], 'AbsTol', 1e-12);
            testCase.verifyEqual(p.translation_level0, [0 0 10 0 0], 'AbsTol', 1e-12);
            testCase.verifyEqual(p.dtype, '<u2');
            testCase.verifyEqual(p.byte_order, 'little');
            testCase.verifyEqual(p.n_channels, 2);
        end

        function testAnAxisWithNoScaleReadsAsVoxelOneTranslationZero(testCase)
            % Jess 2026-10-15: the migrator writes a space/time axis the
            % source gave no scale as regular, origin 0, spacing 1, no unit
            % (DID-matlab jLightsheetKeys). It reads as v1's 1 and 0, with no
            % unit; a key with stored positions (`quantity`) reads the same.
            regular = @(name, n) struct('variable', struct('name', name), 'n', n, ...
                'regular', true, 'origin', struct('value', 0), 'spacing', struct('value', 1));
            k = {regular('time', 1), ...
                struct('variable', struct('name', 'channel'), 'n', 2, 'regular', false, ...
                    'quantity', struct('value', [0 1], 'source_value', [0 1])), ...
                regular('z', 400), regular('y', 2048), regular('x', 2048)};
            f = ndi.vintage.lightsheetKeys(k);
            testCase.verifyEqual(f.axes_order, 'tczyx');
            testCase.verifyEqual(f.shape, [1 2 400 2048 2048]);
            testCase.verifyEqual(f.voxel_size, [1 1 1 1 1]);
            testCase.verifyEqual(f.translation, [0 0 0 0 0]);
            testCase.verifyEqual(f.units, {'', '', '', '', ''});
            testCase.verifyEqual(f.voxel_size_units, '');
            testCase.verifyEqual(f.channel_names, '');
            old = k;
            for a = [1 3 4 5]
                old{a} = struct('variable', k{a}.variable, 'n', k{a}.n, 'regular', false, ...
                    'quantity', struct('value', 0:(k{a}.n - 1), 'source_value', 0:(k{a}.n - 1)));
            end
            g = ndi.vintage.lightsheetKeys(old);
            testCase.verifyEqual(g.voxel_size, f.voxel_size);
            testCase.verifyEqual(g.translation, f.translation);
        end

        function testAMigratedPyramidsLabelIsItsNotes(testCase)
            % Jess 2026-10-15: the label stays on the observation's notes;
            % pyramid_type is dropped. Notes the batch pass did not split
            % (label, separator, the store body's text) give the label alone.
            F = ndi.unittest.vintage.LightsheetFixtures;
            s = F.pyramid('pyr_ls_1', 'sw_1');
            p = ndi.vintage.lightsheetPyramid(ndi.document(s));
            testCase.verifyEqual(p.label, 'brain 7 cleared');
            testCase.verifyEqual(p.pyramid_type, '');
            s.statement.notes = sprintf('brain 7 cleared\n-- store body: NGFF multiscales name "mean"');
            p = ndi.vintage.lightsheetPyramid(ndi.document(s));
            testCase.verifyEqual(p.label, 'brain 7 cleared', 'only the part before the separator');
            s.statement = rmfield(s.statement, 'notes');
            p = ndi.vintage.lightsheetPyramid(ndi.document(s));
            testCase.verifyEqual(p.label, '', 'no notes, no label');
        end

        function testTheStoreKeysGiveChannelNamesAndUnits(testCase)
            F = ndi.unittest.vintage.LightsheetFixtures;
            k = ndi.vintage.lightsheetKeys(F.keys(1, false));
            testCase.verifyEqual(k.axes_order, 'tczyx');
            testCase.verifyEqual(k.channel_names, 'GCaMP6s,tdTomato');
            testCase.verifyEqual(k.units, {'second', '', 'micrometer', 'micrometer', 'micrometer'});
            testCase.verifyEmpty(k.chunks, 'a store body''s keys carry no chunk');
            % a struct-array key list (what a JSON round trip of uniform keys
            % makes) reads the same as the cell
            c = F.keys(1, true);
            names = unique([fieldnames(c{1}); fieldnames(c{2}); fieldnames(c{3})]);
            arr = repmat(cell2struct(cell(numel(names), 1), names, 1), 1, 5);
            for a = 1:5
                fn = fieldnames(c{a});
                for j = 1:numel(fn)
                    arr(a).(fn{j}) = c{a}.(fn{j});
                end
            end
            k2 = ndi.vintage.lightsheetKeys(arr);
            testCase.verifyEqual(k2.shape, [1 2 400 2048 2048]);
            testCase.verifyEqual(k2.chunks, [1 1 64 256 256]);
            testCase.verifyEqual(k2.voxel_size, [1 1 2 0.5 0.5], 'AbsTol', 1e-12);
        end

        % ===================== series member numbering =================

        function testSeriesMemberBaseFollowsTheVintage(testCase)
            testCase.verifyEqual(ndi.vintage.seriesMemberBase( ...
                struct('document_class', struct('class_name', 'x'))), 1, ...
                'no schema_version: v1');
            testCase.verifyEqual(ndi.vintage.seriesMemberBase( ...
                struct('document_class', struct('schema_version', ''))), 1);
            testCase.verifyEqual(ndi.vintage.seriesMemberBase( ...
                struct('document_class', struct('schema_version', 'V_delta'))), 1);
            testCase.verifyEqual(ndi.vintage.seriesMemberBase( ...
                struct('document_class', struct('schema_version', 'V_eta'))), 0);
            testCase.verifyEqual(ndi.vintage.seriesMemberBase(42), 1, ...
                'not a document: the v1 default');
        end

        function testExtractDocsFilesTakesAVEtaSeriesFromMemberZero(testCase)
            % A migrated level: manifest `body_data`, two members body_data_0
            % and body_data_1. The walker used to ask for body_data_1 and
            % body_data_2 -- missing member 0 and asking for one past the end.
            F = ndi.unittest.vintage.LightsheetFixtures;
            s = F.level('lvl_0', 'pyr_ls_1', 1, '', {});
            manifest = F.tempFile(testCase.Dir, 'uid_manifest', uint8(0));
            files = containers.Map( ...
                {'body_data', 'body_data_0', 'body_data_1'}, ...
                {manifest, F.tempFile(testCase.Dir, 'uid_m0', uint8(1)), ...
                 F.tempFile(testCase.Dir, 'uid_m1', uint8(2))});
            s.files = struct('file_list', {{'body_data'}}, 'file_series', {{'body_data'}}, ...
                'file_info', struct('name', 'body_data', ...
                    'locations', F.byLocation(manifest)), ...
                'series_info', struct('name', 'body_data', 'count', 2, ...
                    'n_present', 2, 'source_root', ''));
            docs = ndi.database.fun.extract_docs_files( ...
                ndi.unittest.vintage.TestLightsheetVintage.fakeSession(ndi.document(s), files));
            si = docs{1}.document_properties.files.series_info;
            testCase.verifyEqual([si.ingest_locations.index], [0 1], ...
                'members 0 and 1, numbered as their names are');
            testCase.verifyEqual({si.ingest_locations.uid}, {'uid_m0', 'uid_m1'});
        end

        function testExtractDocsFilesStillTakesAV1SeriesFromMemberOne(testCase)
            F = ndi.unittest.vintage.LightsheetFixtures;
            s = F.v1Level('lvl_0', 'pyr_ls_1', 0, 'none', {});
            manifest = F.tempFile(testCase.Dir, 'uid_manifest', uint8(0));
            files = containers.Map( ...
                {'chunk.bin', 'chunk.bin_1', 'chunk.bin_2'}, ...
                {manifest, F.tempFile(testCase.Dir, 'uid_c1', uint8(1)), ...
                 F.tempFile(testCase.Dir, 'uid_c2', uint8(2))});
            s.files = struct('file_list', {{'chunk.bin'}}, 'file_series', {{'chunk.bin'}}, ...
                'file_info', struct('name', 'chunk.bin', ...
                    'locations', F.byLocation(manifest)), ...
                'series_info', struct('name', 'chunk.bin', 'count', 2, ...
                    'n_present', 2, 'source_root', ''));
            docs = ndi.database.fun.extract_docs_files( ...
                ndi.unittest.vintage.TestLightsheetVintage.fakeSession(ndi.document(s), files));
            si = docs{1}.document_properties.files.series_info;
            testCase.verifyEqual([si.ingest_locations.index], [1 2]);
            testCase.verifyEqual({si.ingest_locations.uid}, {'uid_c1', 'uid_c2'});
        end

        % ===================== the routing stays in place ==============

        function testTheReadersRouteThroughTheVintageLayer(testCase)
            % STRUCTURAL, and said so: these lines are what a migrated
            % pyramid needs and nothing else here would notice them being
            % reverted to a direct `.lightsheetZarrLevel` read.
            % TestLightsheetMigratedSession is the behavioural check.
            root = ndi.unittest.vintage.TestLightsheetVintage.repoRoot();
            src = @(p) fileread(fullfile(root, p));
            lt = src(fullfile('src', 'ndi', '+ndi', '+fun', '+doc', '+lightsheet', 'levelTable.m'));
            testCase.verifySubstring(lt, 'ndi.vintage.lightsheetLevelDocs(session, parentDoc)');
            testCase.verifySubstring(lt, 'ndi.vintage.lightsheetLevels(docs, parentDoc)');
            mp = src(fullfile('src', 'ndi', '+ndi', '+fun', '+doc', '+lightsheet', 'makePyramid.m'));
            testCase.verifySubstring(mp, 'ndi.vintage.lightsheetChunkName(from, i)');
            testCase.verifySubstring(mp, 'ndi.vintage.lightsheetLevel(from)');
            for p = {fullfile('src', 'ndi', '+ndi', '+database', '+fun', 'extract_docs_files.m'), ...
                     fullfile('src', 'ndi', '+ndi', '+database', '+internal', 'list_binary_files.m')}
                testCase.verifySubstring(src(p{1}), 'ndi.vintage.seriesMemberBase(', p{1});
            end
        end

    end

    methods (Static)

        function s = fakeSession(doc, files)
            arguments
                doc
                files containers.Map
            end
            s = ndi.unittest.vintage.FakeFileSession({doc}, files);
        end

        function root = repoRoot()
            here = fileparts(mfilename('fullpath'));  % tests/+ndi/+unittest/+vintage
            root = fileparts(fileparts(fileparts(fileparts(here))));
        end

    end
end
