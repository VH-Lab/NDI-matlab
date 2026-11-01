classdef TestDaqReaderWriterV2 < matlab.unittest.TestCase
%TESTDAQREADERWRITERV2 ndi.daq.reader writes the V2 acquisition_reader into a V2 database.
%
%   When a daq system is added to a session whose database is V2 (did2),
%   its reader's record is an `acquisition_reader` whose id is the reader's
%   id, with the `software` entity its `software_id` names (the shape
%   DID-matlab's +migrators_j/daqreader.m and daqreader_ndr.m write for a v1
%   `daqreader` / `daqreader_ndr`), not a v1 document stamped did_v1. The
%   daq system loads again with that reader. A v1 database keeps the v1
%   document.
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
        function testAV2DatabaseGetsTheAcquisitionReader(testCase)
            S = ndi.setup.V2.createSession(testCase.Dir, 'd1');
            testCase.assertTrue(S.writesV2(), 'createSession did not make a V2 session');
            nav = ndi.file.navigator(S, {'#.rhd', '#.epochprobemap.ndi'}, ...
                'ndi.epoch.epochprobemap_daqsystem', {'(.*)epochprobemap.ndi'});
            rdr = ndi.daq.reader.mfdaq.intan();
            S.daqsystem_add(ndi.daq.system.mfdaq('intan1', nav, rdr));

            nav2 = ndi.file.navigator(S, {'#.rhd', '#.epochprobemap.ndi'}, ...
                'ndi.epoch.epochprobemap_daqsystem', {'(.*)epochprobemap.ndi'});
            ndrRdr = ndi.daq.reader.mfdaq.ndr('RHD');
            S.daqsystem_add(ndi.daq.system.mfdaq('ndr1', nav2, ndrRdr));

            % DENOMINATOR FIRST: what the database now holds
            stored = testCase.storedBodies(S.getpath());
            testCase.assertNotEmpty(stored, 'the V2 database holds nothing');
            classes = cellfun(@(s) s.document_class.class_name, stored, 'UniformOutput', false);
            testCase.verifyFalse(any(ismember(classes, {'daqreader', 'daqreader_ndr'})), ...
                sprintf(['a v1 `daqreader` or `daqreader_ndr` document was written ' ...
                'into a V2 database (classes: %s)'], strjoin(classes, ', ')));

            r = testCase.onlyDoc(stored, rdr.id(), 'acquisition_reader');
            testCase.verifyTrue(did2.schema.isV2Stamp(r), 'stamped V2 (not did_v1)');
            testCase.verifyEqual(testCase.softwareName(stored, r), 'ndi.daq.reader.mfdaq.intan');

            r2 = testCase.onlyDoc(stored, ndrRdr.id(), 'acquisition_reader');
            testCase.verifyEqual(char(r2.acquisition_reader.reader_string), ...
                ndrRdr.ndr_reader_string);
            testCase.verifyEqual(testCase.softwareName(stored, r2), 'ndi.daq.reader.mfdaq.ndr');

            % and the daq systems load again with those readers
            S2 = ndi.session.dir(S.getpath());
            d = S2.daqsystem_load('name', 'intan1');
            testCase.assertClass(d, 'ndi.daq.system.mfdaq');
            testCase.verifyClass(d.daqreader, 'ndi.daq.reader.mfdaq.intan');
            testCase.verifyEqual(d.daqreader.id(), rdr.id());
            d2 = S2.daqsystem_load('name', 'ndr1');
            testCase.assertClass(d2, 'ndi.daq.system.mfdaq');
            testCase.verifyClass(d2.daqreader, 'ndi.daq.reader.mfdaq.ndr');
            testCase.verifyEqual(d2.daqreader.id(), ndrRdr.id());
            testCase.verifyEqual(d2.daqreader.ndr_reader_string, ndrRdr.ndr_reader_string);
        end

        function testAV1DatabaseKeepsTheV1Reader(testCase)
            S = ndi.session.dir('ref1', testCase.Dir);
            testCase.assertFalse(S.writesV2(), 'a new folder was given a V2 database');
            d = ndi.daq.reader.mfdaq.intan().newdocument(S);
            testCase.verifyClass(d, 'ndi.document');
            testCase.verifyEqual(d.document_properties.document_class.class_name, 'daqreader');
            d = ndi.daq.reader.mfdaq.ndr('RHD').newdocument(S);
            testCase.verifyClass(d, 'ndi.document');
            testCase.verifyEqual(d.document_properties.document_class.class_name, 'daqreader_ndr');
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
