classdef TestNavigatorWriterV2 < matlab.unittest.TestCase
%TESTNAVIGATORWRITERV2 ndi.file.navigator writes the V2 epoch_file_pattern into a V2 database.
%
%   When a daq system is added to a session whose database is V2 (did2),
%   its file navigator's record is an `epoch_file_pattern` whose id is the
%   navigator's id, with the `software` entity its `software_id` names (the
%   shape DID-matlab's +migrators_j/filenavigator.m writes for a v1
%   `filenavigator`), not a v1 `filenavigator` document stamped did_v1. The
%   daq system loads again from it. A v1 database keeps the v1 document.
%
%   Decided by Jess Haley, 2026-10-29 [v1 writes into a V2 session]
%   (did-schema did_v2_go_forward_class_audit.md): "the end state is that
%   every NDI writer writes V2 documents and a V2 session accepts only V2
%   documents".
%
%   Filtered (never passed) when did2.build or a V2 schema with `entity` is
%   missing.

    properties
        Dir
    end

    methods (TestClassSetup)
        function needV2(testCase)
            testCase.assumeTrue(~isempty(which('did2.build.document')), ...
                'did2.build (DID-matlab V2) is not on the path');
            schemaPath = getenv('DID_SCHEMA_PATH');
            testCase.assumeTrue(~isempty(schemaPath) && ...
                isfile(ndi.v2.schemaFile(schemaPath, 'entity.json')), ...
                'DID_SCHEMA_PATH does not hold a V2 schema with `entity` (did-schema #88)');
        end
    end

    methods (TestMethodSetup)
        function makeDir(testCase)
            testCase.Dir = tempname;
            mkdir(testCase.Dir);
            testCase.addTeardown(@() rmdir(testCase.Dir, 's'));
        end
    end

    methods (Test)
        function testAV2DatabaseGetsTheEpochFilePattern(testCase)
            S = ndi.setup.V2.createSession(testCase.Dir, 'd1');
            testCase.assertTrue(S.writesV2(), 'createSession did not make a V2 session');
            nav = ndi.file.navigator(S, {'#.rhd', '#.epochprobemap.ndi'}, ...
                'ndi.epoch.epochprobemap_daqsystem', {'(.*)epochprobemap.ndi'});
            dev = ndi.daq.system.mfdaq('intan1', nav, ndi.daq.reader.mfdaq.intan());
            S.daqsystem_add(dev);

            % DENOMINATOR FIRST: what the database now holds
            stored = testCase.storedBodies(S.getpath());
            testCase.assertNotEmpty(stored, 'the V2 database holds nothing');
            classes = cellfun(@(s) s.document_class.class_name, stored, 'UniformOutput', false);
            testCase.verifyFalse(any(strcmp(classes, 'filenavigator')), sprintf( ...
                'a v1 `filenavigator` document was written into a V2 database (classes: %s)', ...
                strjoin(classes, ', ')));
            hit = cellfun(@(s) strcmp(s.base.id, nav.id()), stored);
            testCase.assertEqual(nnz(hit), 1, sprintf( ...
                'expected one document with the navigator''s id (classes: %s)', ...
                strjoin(classes, ', ')));
            efp = stored{find(hit, 1)};
            testCase.verifyEqual(efp.document_class.class_name, 'epoch_file_pattern');
            testCase.verifyTrue(did2.schema.isV2Stamp(efp), ...
                'the epoch_file_pattern is stamped V2 (not did_v1)');
            testCase.verifyEqual(asRow(efp.epoch_file_pattern.file_pattern), ...
                {'#.rhd', '#.epochprobemap.ndi'});
            testCase.verifyEqual(asRow(efp.epoch_file_pattern.epoch_map_pattern), ...
                {'(.*)epochprobemap.ndi'});
            testCase.verifyEqual(char(efp.epoch_file_pattern.epoch_map_format), ...
                'ndi.epoch.epochprobemap_daqsystem');

            % the software entity its software_id names holds the class
            swId = ndi.document(efp).dependency_value('software_id', 'ErrorIfNotFound', 0);
            testCase.assertNotEmpty(swId, 'the epoch_file_pattern names no software');
            sw = stored(cellfun(@(s) strcmp(s.base.id, swId), stored));
            testCase.assertNumElements(sw, 1);
            testCase.verifyEqual(sw{1}.document_class.class_name, 'entity');
            testCase.verifyEqual(char(sw{1}.entity.name), 'ndi.file.navigator');

            % and the daq system loads again with that navigator
            S2 = ndi.session.dir(S.getpath());
            d = S2.daqsystem_load('name', 'intan1');
            testCase.assertClass(d, 'ndi.daq.system.mfdaq');
            testCase.verifyClass(d.filenavigator, 'ndi.file.navigator');
            testCase.verifyEqual(d.filenavigator.id(), nav.id());
            testCase.verifyEqual(asRow(d.filenavigator.fileparameters.filematch), ...
                {'#.rhd', '#.epochprobemap.ndi'});
            testCase.verifyEqual(asRow(d.filenavigator.epochprobemap_fileparameters.filematch), ...
                {'(.*)epochprobemap.ndi'});
            testCase.verifyEqual(d.filenavigator.epochprobemap_class, ...
                'ndi.epoch.epochprobemap_daqsystem');
        end

        function testAV1DatabaseKeepsTheV1Navigator(testCase)
            S = ndi.session.dir('ref1', testCase.Dir);
            testCase.assertFalse(S.writesV2(), 'a new folder was given a V2 database');
            nav = ndi.file.navigator(S, {'#.rhd', '#.epochprobemap.ndi'}, ...
                'ndi.epoch.epochprobemap_daqsystem', {'(.*)epochprobemap.ndi'});
            d = nav.newdocument();
            testCase.verifyClass(d, 'ndi.document');
            testCase.verifyEqual(d.document_properties.document_class.class_name, 'filenavigator');
        end
    end

    methods
        function s = storedBodies(~, sessionPath)
            dbFile = fullfile(sessionPath, '.ndi', ...
                ndi.database.implementations.database.did2sqlite.DEFAULTFILENAME());
            db = did2.database.sqlitedb(dbFile);
            closer = onCleanup(@() db.close()); %#ok<NASGU>
            ids = db.allIds();
            s = cell(1, numel(ids));
            for k = 1:numel(ids)
                raw = db.get(ids{k});
                if iscell(raw)
                    raw = raw{1};
                end
                s{k} = raw.toStruct();
            end
        end
    end
end

function c = asRow(v)
% a stored or rebuilt list, as a 1-by-N cell array of char (a list read back
% from the database comes back as a column)
c = reshape(cellstr(v), 1, []);
end
