classdef TestMetadataReaderWriterV2 < matlab.unittest.TestCase
%TESTMETADATAREADERWRITERV2 ndi.daq.metadatareader writes the V2 epoch_parameter_reader into a V2 database.
%
%   When a daq system with a metadata reader is added to a session whose
%   database is V2 (did2), the metadata reader's record is an
%   `epoch_parameter_reader` whose id is the reader's id (`file_regex` its
%   tab-separated file parameter), with the `software` entity its
%   `software_id` names (the shape DID-matlab's
%   +migrators_j/daqmetadatareader.m writes for a v1 `daqmetadatareader`),
%   not a v1 document stamped did_v1. The daq system loads again with it.
%   A v1 database keeps the v1 document.
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
        function testAV2DatabaseGetsTheEpochParameterReader(testCase)
            S = ndi.setup.V2.createSession(testCase.Dir, 'd1');
            testCase.assertTrue(S.writesV2(), 'createSession did not make a V2 session');
            nav = ndi.file.navigator(S, {'#.rhd', '#.epochprobemap.ndi', 'stims.tsv'}, ...
                'ndi.epoch.epochprobemap_daqsystem', {'(.*)epochprobemap.ndi'});
            md = ndi.daq.metadatareader('stims.tsv');
            S.daqsystem_add(ndi.daq.system.mfdaq('stim1', nav, ...
                ndi.daq.reader.mfdaq.intan(), {md}));

            % DENOMINATOR FIRST: what the database now holds
            stored = testCase.storedBodies(S.getpath());
            testCase.assertNotEmpty(stored, 'the V2 database holds nothing');
            classes = cellfun(@(s) s.document_class.class_name, stored, 'UniformOutput', false);
            testCase.verifyFalse(any(strcmp(classes, 'daqmetadatareader')), sprintf( ...
                'a v1 `daqmetadatareader` document was written into a V2 database (classes: %s)', ...
                strjoin(classes, ', ')));

            r = testCase.onlyDoc(stored, md.id(), 'epoch_parameter_reader');
            testCase.verifyTrue(did2.schema.isV2Stamp(r), 'stamped V2 (not did_v1)');
            testCase.verifyEqual(char(r.epoch_parameter_reader.file_regex), 'stims.tsv');
            testCase.verifyEqual(testCase.softwareName(stored, r), 'ndi.daq.metadatareader');

            % and the daq system loads again with that metadata reader
            S2 = ndi.session.dir(S.getpath());
            d = S2.daqsystem_load('name', 'stim1');
            testCase.assertClass(d, 'ndi.daq.system.mfdaq');
            testCase.assertNumElements(d.daqmetadatareader, 1);
            testCase.verifyClass(d.daqmetadatareader{1}, 'ndi.daq.metadatareader');
            testCase.verifyEqual(d.daqmetadatareader{1}.id(), md.id());
            testCase.verifyEqual(d.daqmetadatareader{1}.tab_separated_file_parameter, 'stims.tsv');
        end

        function testAV1DatabaseKeepsTheV1MetadataReader(testCase)
            S = ndi.session.dir('ref1', testCase.Dir);
            testCase.assertFalse(S.writesV2(), 'a new folder was given a V2 database');
            d = ndi.daq.metadatareader('stims.tsv').newdocument(S);
            testCase.verifyClass(d, 'ndi.document');
            testCase.verifyEqual(d.document_properties.document_class.class_name, 'daqmetadatareader');
        end
    end

    methods
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
