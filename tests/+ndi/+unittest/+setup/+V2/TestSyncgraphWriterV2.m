classdef TestSyncgraphWriterV2 < matlab.unittest.TestCase
%TESTSYNCGRAPHWRITERV2 the syncgraph writes the v2 clock alignment records into a v2 database.
%
%   Jess Haley 2026-11-03 [v2 line reads and writes both] (did-schema
%   did_v2_go_forward_class_audit.md): a v1 database is written as v1, a v2
%   database as v2. When a rule is added to a session whose database is v2
%   (did2), the syncgraph's record is a `clock_alignment_policy` whose id is
%   the syncgraph's id, with `software_id` naming a `software` entity of its
%   class and `clock_alignment_configuration_id` naming its rules; each rule
%   is a `clock_alignment_configuration` (with its software entity, its
%   settings as method parameters and its two daq systems as
%   `from_acquisition_system_id` / `to_acquisition_system_id`) -- the shape
%   DID-matlab's +migrators_j/syncgraph.m and syncrule.m (with
%   did2.convert.resolveClockAlignment) write for v1 `syncgraph` and
%   `syncrule` documents -- or, where the migration carries a rule whole as
%   v1, the rule's v1 document. Each reads back through ndi.session.dir. A v1
%   database keeps the v1 documents.
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
                isfile(ndi.v2.schemaFile(schemaPath, 'entity.json')) && ...
                isfile(ndi.v2.schemaFile(schemaPath, 'clock_alignment_policy.json')), ...
                ['DID_SCHEMA_PATH does not hold a v2 schema with `entity` and ' ...
                 '`clock_alignment_policy`']);
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
        function testAV1DatabaseKeepsTheV1Syncgraph(testCase)
            S = ndi.session.dir('ref1', testCase.Dir);
            testCase.assertFalse(S.writesV2(), 'a new folder was given a v2 database');
            r = ndi.time.syncrule.filematch(struct('number_fullpath_matches', 2));
            S = S.syncgraph_addrule(r);

            g = S.database_search(ndi.query('', 'isa', 'syncgraph', ''));
            testCase.assertNumElements(g, 1, 'a v1 database holds one v1 syncgraph document');
            testCase.verifyEqual(g{1}.document_properties.document_class.class_name, 'syncgraph');
            testCase.verifyEqual(g{1}.id(), S.syncgraph.id());
            testCase.verifyEqual(g{1}.dependency_value('syncrule_id_1'), r.id());
            d = S.database_search(ndi.query('base.id', 'exact_string', r.id(), ''));
            testCase.assertNumElements(d, 1);
            testCase.verifyEqual(d{1}.document_properties.document_class.class_name, 'syncrule');
            testCase.verifyEmpty(S.database_search(ndi.query('', 'isa', 'entity', '')), ...
                'a v1 database got v2 entities');

            S2 = ndi.session.dir(S.getpath());
            testCase.verifyEqual(S2.syncgraph.id(), S.syncgraph.id());
            testCase.assertNumElements(S2.syncgraph.rules, 1);
            testCase.verifyEqual(S2.syncgraph.rules{1}.id(), r.id());
        end

        function testAV2DatabaseGetsTheV2Policy(testCase)
            % the term registry armed, as every writer runs it
            S = ndi.setup.V2.createSession(testCase.Dir, 'd1');
            testCase.assertTrue(S.writesV2(), 'createSession did not make a v2 session');
            nStart = numel(testCase.storedBodies(S.getpath()));
            r = ndi.time.syncrule.filematch(struct('number_fullpath_matches', 2));
            S = S.syncgraph_addrule(r);

            % DENOMINATOR FIRST: what the database now holds
            stored = testCase.storedBodies(S.getpath());
            testCase.assertGreaterThan(numel(stored), nStart, 'syncgraph_addrule stored nothing');
            classes = cellfun(@(s) s.document_class.class_name, stored, 'UniformOutput', false);
            testCase.verifyFalse(any(strcmp(classes, 'syncgraph')), sprintf( ...
                'a v1 syncgraph document was written into a v2 database (classes: %s)', ...
                strjoin(classes, ', ')));

            p = testCase.onlyDoc(stored, S.syncgraph.id(), 'clock_alignment_policy');
            testCase.verifyTrue(did2.schema.isV2Stamp(p), 'the policy is stamped v2');
            testCase.verifyEqual(testCase.softwareName(stored, p), 'ndi.time.syncgraph');
            testCase.verifyEqual(ndi.v2.edgeIds(p, 'clock_alignment_configuration_id'), {r.id()});

            % The rule: a v2 configuration when the term registry holds the
            % term of its setting, otherwise carried as its v1 document
            % ([early migration pieces fixed] (3)).
            label = ndi.setup.V2.registeredTerm('', 'minimum matching file paths');
            registered = did2.schema.termRegistered(label, did2.schema.termIndex());
            rd = testCase.onlyDoc(stored, r.id(), '');
            if registered
                testCase.verifyEqual(rd.document_class.class_name, 'clock_alignment_configuration');
            else
                testCase.verifyEqual(rd.document_class.class_name, 'syncrule', ...
                    'with its setting''s term unregistered the rule is carried as v1');
                testCase.verifyFalse(did2.schema.isV2Stamp(rd));
                [~, why] = r.newdocumentV2(S);
                testCase.verifyNotEmpty(strfind(why, 'minimum matching file paths'), why);
            end
            testCase.verifyStoredV2Validate(stored);

            % and it reads back
            S2 = ndi.session.dir(S.getpath());
            testCase.verifyEqual(S2.syncgraph.id(), S.syncgraph.id());
            testCase.assertNumElements(S2.syncgraph.rules, 1);
            testCase.verifyClass(S2.syncgraph.rules{1}, 'ndi.time.syncrule.filematch');
            testCase.verifyEqual(S2.syncgraph.rules{1}.id(), r.id());
            testCase.verifyEqual(double(S2.syncgraph.rules{1}.parameters.number_fullpath_matches), 2);
        end

        function testV2ConfigurationsReadBack(testCase)
            % The v2 configuration branch, with the term registry disarmed
            % (as the migration runs today) so that it is reached whatever
            % the registry holds.
            prev = did2.schema.cache.strictMode('TermRegistry', false);
            testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prev));
            S = ndi.setup.V2.createSession(testCase.Dir, 'd1');
            sys1 = testCase.addDaqSystem(S, 'intan1');
            sys2 = testCase.addDaqSystem(S, 'intan2');
            rules = { ...
                ndi.time.syncrule.filematch(struct('number_fullpath_matches', 2)), ...
                ndi.time.syncrule.filefind(struct('number_fullpath_matches', 1, ...
                    'syncfilename', 'sync.txt', 'daqsystem1', 'intan1', 'daqsystem2', 'intan2')), ...
                ndi.time.syncrule.commonTriggersOverlappingEpochs(struct( ...
                    'daqsystem1_name', 'intan1', 'daqsystem2_name', 'intan2', ...
                    'daqsystem_ch1', 'dep1', 'daqsystem_ch2', 'dep2', ...
                    'epochclocktype', 'dev_local_time', 'minEmbeddedFileOverlap', 1, ...
                    'errorOnFailure', true))};
            for k = 1:numel(rules)
                [~, why] = rules{k}.newdocumentV2(S);
                testCase.assertEmpty(why, sprintf('rule %d was carried as v1: %s', k, why));
                S = S.syncgraph_addrule(rules{k});
            end

            stored = testCase.storedBodies(S.getpath());
            classes = cellfun(@(s) s.document_class.class_name, stored, 'UniformOutput', false);
            testCase.verifyFalse(any(ismember(classes, {'syncgraph', 'syncrule'})), sprintf( ...
                'a v1 sync document was written into a v2 database (classes: %s)', ...
                strjoin(classes, ', ')));
            p = testCase.onlyDoc(stored, S.syncgraph.id(), 'clock_alignment_policy');
            testCase.verifyEqual(ndi.v2.edgeIds(p, 'clock_alignment_configuration_id'), ...
                cellfun(@(r) r.id(), rules, 'UniformOutput', false), 'the rules, in order');
            for k = 1:numel(rules)
                c = testCase.onlyDoc(stored, rules{k}.id(), 'clock_alignment_configuration');
                testCase.verifyEqual(testCase.softwareName(stored, c), class(rules{k}));
            end
            % the edge names the loaded schema declares ([sync configuration
            % edges are input and output], Jess Haley 2026-11-10)
            names = ndi.vintage.syncConfigurationNames();
            ff = testCase.onlyDoc(stored, rules{2}.id(), 'clock_alignment_configuration');
            testCase.verifyEqual(ndi.v2.edgeIds(ff, names.inputEdge), {sys1.id()});
            testCase.verifyEqual(ndi.v2.edgeIds(ff, names.outputEdge), {sys2.id()});
            fm = testCase.onlyDoc(stored, rules{1}.id(), 'clock_alignment_configuration');
            testCase.verifyEmpty(ndi.v2.edgeIds(fm, names.inputEdge), ...
                'a filematch rule names no daq system');
            testCase.verifyStoredV2Validate(stored);
            testCase.verifyNoOrphanSoftware(stored);

            % it reads back as the same rules
            S2 = ndi.session.dir(S.getpath());
            testCase.verifyEqual(S2.syncgraph.id(), S.syncgraph.id());
            testCase.assertNumElements(S2.syncgraph.rules, numel(rules));
            for k = 1:numel(rules)
                got = S2.syncgraph.rules{k};
                testCase.verifyClass(got, class(rules{k}));
                testCase.verifyEqual(got.id(), rules{k}.id());
                want = rules{k}.parameters;
                fns = fieldnames(want);
                testCase.verifyEqual(sort(fieldnames(got.parameters)), sort(fns), ...
                    sprintf('rule %d parameters', k));
                for f = 1:numel(fns)
                    a = want.(fns{f});
                    b = got.parameters.(fns{f});
                    if isnumeric(a) || islogical(a)
                        testCase.verifyEqual(double(b), double(a), ...
                            sprintf('rule %d parameter %s', k, fns{f}));
                    else
                        testCase.verifyEqual(char(b), char(a), ...
                            sprintf('rule %d parameter %s', k, fns{f}));
                    end
                end
            end

            % removing a rule removes its configuration and its software
            % entity, and the policy's previous software entity
            S2 = S2.syncgraph_rmrule(2);
            stored = testCase.storedBodies(S2.getpath());
            testCase.verifyFalse(any(cellfun(@(s) strcmp(s.base.id, rules{2}.id()), stored)), ...
                'the removed rule''s configuration is still stored');
            p = testCase.onlyDoc(stored, S2.syncgraph.id(), 'clock_alignment_policy');
            testCase.verifyEqual(ndi.v2.edgeIds(p, 'clock_alignment_configuration_id'), ...
                {rules{1}.id(), rules{3}.id()});
            testCase.verifyNoOrphanSoftware(stored);
            testCase.verifyEqual(nnz(cellfun(@(s) strcmp(s.document_class.class_name, ...
                'clock_alignment_policy'), stored)), 1, 'one policy');
        end

        function testANamedSystemNotInTheSessionIsCarriedAsV1(testCase)
            prev = did2.schema.cache.strictMode('TermRegistry', false);
            testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prev));
            S = ndi.setup.V2.createSession(testCase.Dir, 'd1');
            r = ndi.time.syncrule.filefind(struct('number_fullpath_matches', 1, ...
                'syncfilename', 'sync.txt', 'daqsystem1', 'intan1', 'daqsystem2', 'intan2'));
            [docs, why] = r.newdocumentV2(S);
            testCase.assertNumElements(docs, 1);
            testCase.verifyEqual(docs{1}.document_properties.document_class.class_name, 'syncrule');
            testCase.verifyNotEmpty(strfind(why, 'intan1'), why);
        end
    end

    methods
        function dev = addDaqSystem(~, S, name)
            nav = ndi.file.navigator(S, {'#.rhd', '#.epochprobemap.ndi'}, ...
                'ndi.epoch.epochprobemap_daqsystem', {'(.*)epochprobemap.ndi'});
            dev = ndi.daq.system.mfdaq(name, nav, ndi.daq.reader.mfdaq.intan());
            S.daqsystem_add(dev);
        end

        function verifyStoredV2Validate(testCase, stored)
            for k = 1:numel(stored)
                if ~did2.schema.isV2Stamp(stored{k})
                    continue;
                end
                try
                    did2.document(stored{k}).validate();
                    ok = true;
                    msg = '';
                catch ME
                    ok = false;
                    msg = ME.message;
                end
                testCase.verifyTrue(ok, sprintf('%s %s does not validate: %s', ...
                    stored{k}.document_class.class_name, stored{k}.base.id, msg));
            end
        end

        function verifyNoOrphanSoftware(testCase, stored)
            named = {};
            for k = 1:numel(stored)
                named = [named, ndi.v2.edgeIds(stored{k}, 'software_id')]; %#ok<AGROW>
            end
            for k = 1:numel(stored)
                s = stored{k};
                if strcmp(s.document_class.class_name, 'entity') && ...
                        strcmp(ndi.v2.kindOf(s), 'software')
                    testCase.verifyTrue(any(strcmp(named, s.base.id)), sprintf( ...
                        'software entity %s (%s) is named by no document', s.base.id, ...
                        char(s.entity.name)));
                end
            end
        end

        function doc = onlyDoc(testCase, stored, id, className)
            hit = cellfun(@(s) strcmp(s.base.id, id), stored);
            testCase.assertEqual(nnz(hit), 1, sprintf( ...
                'expected one document with id %s', id));
            doc = stored{find(hit, 1)};
            if ~isempty(className)
                testCase.verifyEqual(doc.document_class.class_name, className);
            end
        end

        function name = softwareName(testCase, stored, doc)
            swId = ndi.v2.edgeIds(doc, 'software_id');
            testCase.assertNumElements(swId, 1, 'the document names one software entity');
            sw = stored(cellfun(@(s) strcmp(s.base.id, swId{1}), stored));
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
