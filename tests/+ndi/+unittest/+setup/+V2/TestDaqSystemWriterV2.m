classdef TestDaqSystemWriterV2 < matlab.unittest.TestCase
%TESTDAQSYSTEMWRITERV2 ndi.daq.system writes the v2 acquisition_system into a v2 database.
%
%   When a daq system is added to a session whose database is v2 (did2),
%   the system's own record is an `acquisition_system` whose id is the
%   system's id and whose `name` is its name, with `software_id` naming the
%   `software` entity of its class and `reader_id`, `epoch_file_pattern_id`
%   and `epoch_parameter_reader_id` naming its components (the shape
%   DID-matlab's +migrators_j/daqsystem.m writes for a v1 `daqsystem`), not
%   a v1 `daqsystem` document stamped did_v1. With the navigator, reader
%   and metadata reader moved before it, the whole set is v2, and the daq
%   system loads again from it. A v1 database keeps the v1 documents.
%
%   Decided by Jess Haley, 2026-10-29 [v1 writes into a V2 session]
%   (did-schema did_v2_go_forward_class_audit.md): "the end state is that
%   every NDI writer writes V2 documents and a V2 session accepts only V2
%   documents".
%
%   Filtered (never passed) when did2.build or a v2 schema with `entity` is
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
                'DID_SCHEMA_PATH does not hold a v2 schema with `entity` (did-schema #88)');
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
        function testAV2DatabaseGetsOnlyV2AcquisitionDocuments(testCase)
            S = ndi.setup.V2.createSession(testCase.Dir, 'd1');
            testCase.assertTrue(S.writesV2(), 'createSession did not make a v2 session');
            nStart = numel(testCase.storedBodies(S.getpath()));
            nav = ndi.file.navigator(S, {'#.rhd', '#.epochprobemap.ndi', 'stims.tsv'}, ...
                'ndi.epoch.epochprobemap_daqsystem', {'(.*)epochprobemap.ndi'});
            rdr = ndi.daq.reader.mfdaq.intan();
            md = ndi.daq.metadatareader('stims.tsv');
            dev = ndi.daq.system.mfdaq('intan1', nav, rdr, {md});
            S.daqsystem_add(dev);

            % DENOMINATOR FIRST: what the database now holds
            stored = testCase.storedBodies(S.getpath());
            testCase.assertGreaterThan(numel(stored), nStart, 'daqsystem_add stored nothing');
            classes = cellfun(@(s) s.document_class.class_name, stored, 'UniformOutput', false);
            v1 = {'daqsystem', 'filenavigator', 'daqreader', 'daqreader_ndr', 'daqmetadatareader'};
            testCase.verifyFalse(any(ismember(classes, v1)), sprintf( ...
                'a v1 acquisition document was written into a v2 database (classes: %s)', ...
                strjoin(classes, ', ')));
            stamps = cellfun(@(s) did2.schema.isV2Stamp(s), stored);
            testCase.verifyTrue(all(stamps), sprintf( ...
                '%d of %d stored documents are not stamped v2 (classes: %s)', ...
                nnz(~stamps), numel(stamps), strjoin(classes(~stamps), ', ')));

            % the class the loaded schema holds ([acquisition configuration
            % renamed], Jess Haley, 2026-11-19)
            cls = ndi.vintage.acquisitionConfigurationClass();
            a = testCase.onlyDoc(stored, dev.id(), cls);
            testCase.verifyEqual(char(a.(cls).name), 'intan1');
            testCase.verifyEqual(testCase.softwareName(stored, a), 'ndi.daq.system.mfdaq');
            ad = ndi.document(a);
            testCase.verifyEqual(ad.dependency_value('reader_id'), rdr.id());
            testCase.verifyEqual(ad.dependency_value('epoch_file_pattern_id'), nav.id());
            testCase.verifyEqual(ndi.vintage.edge_n(ad, 'daqmetadatareader_id', 'ErrorIfNotFound', 0), {md.id()});
            testCase.verifyRigDevice(stored, ad, 'intan1', dev.id());

            % and it loads again, by name and among all systems
            S2 = ndi.session.dir(S.getpath());
            d = S2.daqsystem_load('name', 'intan1');
            testCase.assertClass(d, 'ndi.daq.system.mfdaq');
            testCase.verifyEqual(d.id(), dev.id());
            testCase.verifyEqual(d.name, 'intan1');
            testCase.verifyEqual(d.filenavigator.id(), nav.id());
            testCase.verifyEqual(d.daqreader.id(), rdr.id());
            testCase.assertNumElements(d.daqmetadatareader, 1);
            testCase.verifyEqual(d.daqmetadatareader{1}.id(), md.id());
            all_ = S2.daqsystem_load('name', '(.*)');
            testCase.verifyClass(all_, 'ndi.daq.system.mfdaq', 'one system, loaded alone');

            % adding it again is refused as a duplicate
            testCase.verifyError(@() S2.daqsystem_add(dev), ?MException);
        end

        function testAV1DatabaseKeepsTheV1DaqSystem(testCase)
            S = ndi.session.dir('ref1', testCase.Dir);
            testCase.assertFalse(S.writesV2(), 'a new folder was given a v2 database');
            nav = ndi.file.navigator(S, {'#.rhd', '#.epochprobemap.ndi'}, ...
                'ndi.epoch.epochprobemap_daqsystem', {'(.*)epochprobemap.ndi'});
            dev = ndi.daq.system.mfdaq('intan1', nav, ndi.daq.reader.mfdaq.intan());
            S.daqsystem_add(dev);
            d = S.database_search(ndi.query('base.id', 'exact_string', dev.id(), ''));
            testCase.assertNumElements(d, 1);
            testCase.verifyEqual(d{1}.document_properties.document_class.class_name, 'daqsystem');
        end
    end

    methods
        function verifyRigDevice(testCase, stored, ad, rigName, systemId)
            % did-schema docs/plans/did_v2_standing_wiring_plan.md [device id
            % required and named by the rig]: the configuration names the
            % rig's device by `device_id`, an entity of type device whose
            % `name` is the rig's name and which writes nothing else
            % ([local identifier required only where looked up]), one per
            % rig per session, with the id DID-matlab's migration gives it
            devId = ad.dependency_value('device_id', 'ErrorIfNotFound', 0);
            testCase.assertNotEmpty(devId, 'the acquisition configuration names no device_id');
            hit = stored(cellfun(@(s) strcmp(s.base.id, devId), stored));
            testCase.assertNumElements(hit, 1, 'the device_id names no stored document');
            d = hit{1};
            testCase.verifyEqual(d.document_class.class_name, 'entity');
            testCase.verifyEqual(ndi.v2.vocabHandle('entity_type', d.entity.type), 'device');
            testCase.verifyEqual(char(d.entity.name), rigName);
            testCase.verifyFalse(isfield(d.entity, 'local_identifier') && ...
                ~isempty(d.entity.local_identifier), 'the rig device writes name only');
            testCase.verifyEqual(char(d.base.session_id), char(ad.document_properties.base.session_id));
            % one device per rig: no other device entity is named rigName
            isDev = cellfun(@(s) strcmp(s.document_class.class_name, 'entity') && ...
                strcmp(ndi.v2.vocabHandle('entity_type', s.entity.type), 'device') && ...
                isfield(s.entity, 'name') && strcmp(char(s.entity.name), rigName), stored);
            testCase.verifyEqual(nnz(isDev), 1, 'one device per rig per session');
            % the migration's id: did2.convert.mintId('rig device') in the
            % context DID-matlab's v1_to_v2 opens for the v1 daqsystem, keyed
            % on its base.id (the system's id)
            depth = did2.convert.mintId('-depth');
            did2.convert.mintId('-push', systemId);
            migrated = did2.convert.mintId('rig device');
            did2.convert.mintId('-popto', depth);
            testCase.verifyEqual(devId, migrated, ...
                'the device id is the one DID-matlab''s migration mints for this rig');
        end

        function doc = onlyDoc(testCase, stored, id, className)
            hit = cellfun(@(s) strcmp(s.base.id, id), stored);
            testCase.assertEqual(nnz(hit), 1, sprintf( ...
                'expected one document with id %s', id));
            doc = stored{find(hit, 1)};
            testCase.verifyEqual(doc.document_class.class_name, className);
        end

        function name = softwareName(testCase, stored, doc)
            swId = ndi.document(doc).dependency_value('software_id', 'ErrorIfNotFound', 0);
            testCase.assertNotEmpty(swId, 'the document names no software');
            sw = stored(cellfun(@(s) strcmp(s.base.id, swId), stored));
            testCase.assertNumElements(sw, 1);
            testCase.verifyEqual(sw{1}.document_class.class_name, 'entity');
            name = char(sw{1}.entity.name);
        end

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
