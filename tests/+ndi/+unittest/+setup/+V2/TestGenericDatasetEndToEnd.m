classdef TestGenericDatasetEndToEnd < matlab.unittest.TestCase
%TESTGENERICDATASETENDTOEND A small made-up V2 dataset, written and read back.
%
%   Every other V2 test here goes through the Haley import. This one builds a
%   dataset ONLY with the public V2 API that Using_V2.md tells a user to use
%   (did2.build.*, ndi.setup.V2.entityDocuments / registeredTerm /
%   attachFile / createDataset), writes it to a temporary folder, re-opens it
%   with ndi.dataset.dir, and reads every piece back through the object layer
%   (ndi.entity, ndi.statement and its children, ndi.value):
%
%     dataset   a `dataset` entity (its id is the dataset's session id) with
%               a text assertion; one session, `included_in` the dataset;
%               every document's `session_id` edge
%     entities  an organism that is `instance_of` a strain (the strain
%               asserts the species), a tissue `part_of` the organism, a
%               camera (a device)
%     observe   the organism's speed, a 5-sample series over a time key, in
%               a sampled body; the key's source unit is a term; a relative
%               time reference; the camera as instrument
%     manipulate  the organism's temperature, inline with a `source_unit`
%               term, and an inline method {term, parameters}
%     calculate the mean speed, derived from the observation (`input_id`),
%               whose method is a standalone `method` document (`method_id`),
%               computed by a software entity and run on an operating
%               system (both required on a calculation)
%
%   It asserts values, units, edges and inheritance (what `part_of`,
%   `instance_of` and `included_in` pass), that getsubjects returns the
%   biological subjects only, and that did2.build refuses an unregistered
%   term. Every term is one DID-schema's term registry holds
%   (ndi.setup.V2.registeredTerm). Needs did-schema #88 and DID-matlab #218;
%   without them the class is filtered, which test-import-v2.yml counts as a
%   failure.

    properties
        Root
        Dataset
        Session
        Id           % struct of the ids written
        Speed        % the observed series, metres per second
    end

    methods (TestClassSetup)
        function writeAndReopen(testCase)
            testCase.assumeTrue(~isempty(which('did2.build.document')), ...
                'did2.build (DID-matlab V2) is not on the path');
            schemaPath = getenv('DID_SCHEMA_PATH');
            testCase.assumeTrue(~isempty(schemaPath) && ...
                isfile(ndi.v2.schemaFile(schemaPath, 'entity.json')), ...
                'DID_SCHEMA_PATH does not hold a V2 schema with `entity` (did-schema #88)');
            testCase.assumeTrue(~isempty(which('did2.schema.termIndex')) && ...
                did2.schema.termIndex().present, ...
                'no term registry: needs did-schema #88 and DID-matlab #218');

            testCase.Root = tempname;
            mkdir(testCase.Root);
            testCase.addTeardown(@() rmdir(testCase.Root, 's'));
            [dsDocs, sessDocs, testCase.Id, testCase.Speed] = buildDataset(testCase.Root);
            [~, report] = ndi.setup.V2.createDataset(fullfile(testCase.Root, 'dataset'), ...
                'e2e', testCase.Id.dataset, dsDocs, {sessDocs}, 'Strict', true, ...
                'Progress', false);
            testCase.assertEqual(height(report.edges.dangling), 0, 'no edge dangles');
            testCase.assertEmpty(report.sessions.notInDataset, ...
                'the session is included_in the dataset');

            % re-open from disk, as a user would
            testCase.Dataset = ndi.dataset.dir(fullfile(testCase.Root, 'dataset'));
            [~, ids] = testCase.Dataset.session_list();
            testCase.assertTrue(ismember(testCase.Id.session, ids), ...
                'the dataset lists its session');
            testCase.Session = testCase.Dataset.open_session(testCase.Id.session);
        end
    end

    methods (Test)
        function testDatasetSessionAndSessionEdges(testCase)
            ds = testCase.Dataset;
            S = testCase.Session;
            testCase.verifyEqual(ds.id(), testCase.Id.dataset);
            testCase.verifyEqual(S.id(), testCase.Id.session);

            d = ndi.entity.search(ds, {'type', 'dataset'});
            testCase.assertNumElements(d, 1);
            testCase.verifyEqual(d{1}.document_id, testCase.Id.dataset, ...
                'the dataset entity''s id is the dataset''s session id');
            testCase.verifyEqual(d{1}.name, 'A made-up dataset');
            a = d{1}.assertions({'variable', 'Abbreviation'}, 'synonyms', false);
            testCase.assertNumElements(a, 1);
            testCase.verifyClass(a{1}, 'ndi.assertion');
            testCase.verifyEqual(a{1}.variable().node, 'NCIT:C42610');
            testCase.verifyEqual(a{1}.value().canonical(), "E2E");

            s = ndi.entity.fromDocument(S, testCase.Id.session);
            testCase.verifyEqual(s.type, 'session');
            testCase.verifyEqual(s.local_identifier, 'day1');
            up = s.parents('included_in');
            testCase.assertNumElements(up, 1);
            testCase.verifyEqual(up{1}.document_id, testCase.Id.dataset);

            % session_id is an edge: to the session for its documents, to the
            % dataset for the dataset's; the session's own points at itself
            sessionOf = @(id) ndi.v2.sessionIdOf(ndi.v2.props(ndi.v2.getDocument(S, id)));
            for n = {'session', 'organism', 'tissue', 'camera', 'observation', 'body', ...
                    'manipulation', 'method', 'calculation', 'timeReference', 'partOf', 'instanceOf'}
                testCase.verifyEqual(sessionOf(testCase.Id.(n{1})), testCase.Id.session, n{1});
            end
            for n = {'dataset', 'strain', 'species', 'abbreviation', 'os', 'software'}
                testCase.verifyEqual(sessionOf(testCase.Id.(n{1})), testCase.Id.dataset, n{1});
            end
        end

        function testEntitiesAndWhatRelationsPass(testCase)
            S = testCase.Session;
            w = ndi.entity.search(S, {'local_identifier', 'worm1'});
            testCase.assertNumElements(w, 1);
            w = w{1};
            testCase.verifyEqual(w.type, 'organism');
            cam = ndi.entity.search(S, {'type', 'device'});
            testCase.assertNumElements(cam, 1);
            testCase.verifyEqual(cam{1}.local_identifier, 'camera1');
            st = ndi.entity.search(testCase.Dataset, {'type', 'strain'});
            testCase.assertNumElements(st, 1);
            testCase.verifyEqual(st{1}.name, 'N2');

            P = ndi.v2.relationPasses();
            testCase.verifyTrue(all(ismember({'part_of', 'instance_of'}, P.assertions)));
            testCase.verifyTrue(ismember('included_in', P.nothing));

            % instance_of passes assertions: the strain's species is the worm's
            sp = w.assertions({'variable', 'Species'}, 'synonyms', false);
            testCase.assertNumElements(sp, 1);
            testCase.verifyEqual(sp{1}.via(), 'instance_of');
            testCase.verifyEqual(sp{1}.value().terms().node, 'NCBITaxon:6239');
            testCase.verifyEqual(sp{1}.value().canonical(), "Caenorhabditis elegans");
            testCase.verifyEmpty(w.assertions({'variable', 'Species'}, 'inherited', false, ...
                'synonyms', false), 'the worm states no species of its own');
            own = w.assertions({'variable', 'Developmental Stage'}, 'synonyms', false);
            testCase.assertNumElements(own, 1);
            testCase.verifyEqual(own{1}.via(), 'own');
            testCase.verifyEqual(own{1}.value().terms().node, 'WBls:0000038');

            % part_of passes assertions, and on through instance_of
            t = ndi.entity.search(S, {'local_identifier', 'worm1 head'});
            testCase.assertNumElements(t, 1);
            t = t{1};
            testCase.verifyEqual(t.type, 'tissue');
            whole = t.partOf();
            testCase.assertNumElements(whole, 1);
            testCase.verifyEqual(whole{1}.document_id, w.document_id);
            stage = t.assertions({'variable', 'Developmental Stage'}, 'synonyms', false);
            testCase.assertNumElements(stage, 1);
            testCase.verifyEqual(stage{1}.via(), 'part_of');
            tsp = t.assertions({'variable', 'Species'}, 'synonyms', false);
            testCase.assertNumElements(tsp, 1);
            testCase.verifyEqual(tsp{1}.via(), 'part_of > instance_of');
            testCase.verifyEmpty(t.assertions({}, 'inherited', false, 'synonyms', false), ...
                'the tissue states nothing of its own');

            % the camera is related to nothing, so inherits nothing
            testCase.verifyEmpty(cam{1}.assertions({'variable', 'Species'}, 'synonyms', false));

            % included_in passes nothing: the dataset's abbreviation is not the session's
            s = ndi.entity.fromDocument(S, testCase.Id.session);
            testCase.verifyEmpty(s.assertions({'variable', 'Abbreviation'}, 'synonyms', false));
        end

        function testGetsubjectsReturnsTheBiologicalSubjectsOnly(testCase)
            got = testCase.Session.getsubjects();
            ids = sort(cellfun(@(d) char(d.id()), got, 'UniformOutput', false));
            testCase.verifyEqual(ids, sort({testCase.Id.organism, testCase.Id.tissue}), ...
                'the organism and the tissue; not the camera, strain, session or dataset');
            bio = ndi.entity.search(testCase.Session, {'type', ndi.v2.subjectTypes()});
            testCase.verifyEqual(sort(cellfun(@(e) e.document_id, bio, 'UniformOutput', false)), ids);
        end

        function testObservationSeriesInABody(testCase)
            w = ndi.entity.fromDocument(testCase.Session, testCase.Id.organism);
            o = w.observations({'variable', 'speed'}, 'synonyms', false);
            testCase.assertNumElements(o, 1);
            o = o{1};
            testCase.verifyClass(o, 'ndi.observation');
            testCase.verifyEqual(o.document_id(), testCase.Id.observation);
            testCase.verifyEqual(o.variable().node, 'PATO:0000008');
            testCase.verifyEqual(o.entity().document_id, testCase.Id.organism);

            x = o.value();
            testCase.verifyEqual(reshape(double(x), 1, []), testCase.Speed, ...
                'the series reads back from the body, exactly');
            testCase.verifyEqual(x.unit(), 'meters_per_second');
            b = o.bodies();
            testCase.assertNumElements(b, 1);
            testCase.verifyEqual(b{1}.id(), testCase.Id.body);

            T = o.axes();
            testCase.assertEqual(height(T), 1);
            testCase.verifyEqual(T.term(1), "time");
            testCase.verifyEqual(T.unit(1), "second");
            testCase.verifyEqual(T.n(1), 5);
            testCase.verifyEqual(T.coordinates{1}(:), (0:4)' * 0.5, 'AbsTol', 1e-12);
            C = o.covariates();
            testCase.assertEqual(height(C), 1);
            testCase.verifyEqual(C.variable(1), "time");
            testCase.verifyEqual(C.along{1}, 0);
            testCase.verifyEqual(C.form(1), "origin_spacing");
            c = ndi.v2.blockOf(o.document_properties(), 'data', 'covariates');
            testCase.verifyEqual(c(1).source_unit.node, 'om:millisecond-Time', ...
                'the time covariate''s source unit is a registered term');
            testCase.verifyEqual(c(1).spacing.source_value, 500);

            tm = o.time();
            testCase.assertNumElements(tm, 1);
            testCase.verifyEqual(tm.kind, 'relative');
            testCase.verifyEqual(tm.referent_id, testCase.Id.session);
            testCase.verifyEqual([tm.start_offset tm.end_offset], [0 2]);
            testCase.verifyEqual(char(tm.clock), 'dev_local_time');

            inst = o.instrument();
            testCase.assertNumElements(inst, 1);
            testCase.verifyEqual(inst{1}.document_id, testCase.Id.camera);
        end

        function testManipulationWithAnInlineMethod(testCase)
            w = ndi.entity.fromDocument(testCase.Session, testCase.Id.organism);
            m = w.manipulations({'variable', 'Environmental Temperature'}, 'synonyms', false);
            testCase.assertNumElements(m, 1);
            m = m{1};
            testCase.verifyClass(m, 'ndi.manipulation');
            x = m.value();
            testCase.verifyEqual(double(x), 20);
            testCase.verifyEqual(x.unit(), 'celsius');
            src = x.source();
            testCase.verifyEqual(src.source_value, 20);
            testCase.verifyEqual(src.source_unit, "degree Celsius");
            p = m.document_properties();
            testCase.verifyEqual(p.interaction.method.term.node, 'EMPTY:0000333', ...
                'the method is inline, {term, parameters}');
            testCase.verifyEmpty(ndi.v2.edgeIds(p, 'method_id'));
            testCase.verifyEqual(m.method_name(), 'incubation');
            T = m.method_parameters();
            testCase.assertEqual(height(T), 1);
            testCase.verifyEqual(T.variable(1), "time");
            testCase.verifyEqual(T.value{1}, 3600);
            testCase.verifyEqual(T.unit(1), "second");
            testCase.verifyEqual(T.source_value(1), "1");
            testCase.verifyEqual(T.source_unit(1), "hour");
        end

        function testCalculationFromTheObservationWithAStandaloneMethod(testCase)
            w = ndi.entity.fromDocument(testCase.Session, testCase.Id.organism);
            c = w.calculations({'variable', 'speed'}, 'synonyms', false);
            testCase.assertNumElements(c, 1);
            c = c{1};
            testCase.verifyClass(c, 'ndi.calculation');
            x = c.value();
            testCase.verifyEqual(double(x), mean(testCase.Speed), 'AbsTol', 1e-15);
            testCase.verifyEqual(x.unit(), 'meters_per_second');
            src = x.source();
            testCase.verifyEqual(src.source_unit, "micrometre per second");
            testCase.verifyEqual(src.source_value, mean(testCase.Speed) * 1e6, 'AbsTol', 1e-9);

            in = c.inputs();
            testCase.assertNumElements(in, 1);
            testCase.verifyClass(in{1}, 'ndi.observation');
            testCase.verifyEqual(in{1}.document_id(), testCase.Id.observation);
            os = c.operating_system();
            testCase.assertNumElements(os, 1);
            testCase.verifyEqual(os{1}.document_id, testCase.Id.os);
            testCase.verifyEqual(os{1}.type, 'software');
            sw = c.software();
            testCase.assertNumElements(sw, 1);
            testCase.verifyEqual(sw{1}.name, 'e2e analysis');

            p = c.document_properties();
            testCase.verifyEqual(ndi.v2.edgeIds(p, 'method_id'), {testCase.Id.method});
            testCase.verifyEmpty(ndi.v2.blockOf(p, 'interaction', 'method', []), ...
                'no inline method beside the edge');
            M = ndi.v2.methodOf(testCase.Session, p);
            testCase.verifyEqual(M.id, testCase.Id.method);
            testCase.verifyEqual(M.name, 'mean speed');
            testCase.verifyEqual(c.method_name(), 'Arithmetic Mean');
            T = c.method_parameters();
            testCase.assertEqual(height(T), 2);
            testCase.verifyEqual(cellstr(T.variable)', {'analysis window start', 'analysis window end'});
            testCase.verifyEqual([T.value{:}], [0 2]);
            testCase.verifyEqual(unique(T.unit), "second");
        end

        function testAnUnregisteredTermIsRefused(testCase)
            testCase.assertTrue(logical(did2.schema.cache.strictMode('TermRegistry')), ...
                'the term registry check is armed by default');
            sid = testCase.Id.session;
            testCase.verifyError(@() did2.build.statement('assertion', testCase.Id.organism, ...
                did2.build.term('', 'a made-up e2e variable'), ...
                ndi.setup.V2.registeredTerm('NCBITaxon:6239'), 'SessionId', sid, 'ValueKind', 'term'), ...
                'did2:build:unregisteredTerm', 'an unregistered variable');
            testCase.verifyError(@() did2.build.statement('observation', ...
                testCase.Id.organism, ndi.setup.V2.registeredTerm('NCIT:C90380'), ...
                did2.build.valueCell('temperature', 20, 'SourceValue', 68, ...
                    'SourceUnit', did2.build.term('', 'a made-up e2e unit')), ...
                'TimeReferenceIds', {testCase.Id.timeReference}, 'SessionId', sid, 'ValueKind', 'temperature'), ...
                'did2:build:unregisteredTerm', 'an unregistered source unit');
            % and the registered spelling of the same is accepted
            ok = did2.build.statement('assertion', testCase.Id.organism, ...
                ndi.setup.V2.registeredTerm('NCIT:C45293'), ...
                ndi.setup.V2.registeredTerm('NCBITaxon:6239'), 'SessionId', sid, 'ValueKind', 'term');
            testCase.verifyEqual(ok.statement.variable.name, 'Species');
        end

        function testAttachFileRefusesAnUndeclaredName(testCase)
            body = did2.build.sampledBody(testCase.Id.observation, ...
                did2.build.dimension(ndi.setup.V2.registeredTerm('om:Time'), 1), ...
                'SessionId', testCase.Id.session);
            f = [tempname '.bin'];
            fid = fopen(f, 'w'); fwrite(fid, 0, 'double'); fclose(fid);
            testCase.addTeardown(@() delete(f));
            testCase.verifyError(@() ndi.setup.V2.attachFile(body, 'no_such_file', f), ...
                'ndi:setup:V2:undeclaredFile');
            testCase.verifyError(@() ndi.setup.V2.attachFile(body, 'body_data_0', [f '.missing']), ...
                'ndi:setup:V2:noFile');
        end
    end
end

% -----------------------------------------------------------------------------
function [dsDocs, sessDocs, id, speed] = buildDataset(root)
% The dataset, with the public V2 API only. Every term is the registry's
% (ndi.setup.V2.registeredTerm), so did2.build's term check accepts it.
arguments
    root {mustBeText}
end
T = @(node) ndi.setup.V2.registeredTerm(node);
id.dataset = ndi.ido.unique_id();
id.session = ndi.ido.unique_id();
D = {'SessionId', id.dataset};      % stored with the dataset
S = {'SessionId', id.session};      % stored with the session

% ---- the dataset: its entity, a text assertion, a strain with its species
dsDocs = ndi.setup.V2.entityDocuments('dataset', struct('name', 'A made-up dataset'), ...
    struct(), D{:}, 'Id', id.dataset);
abbrev = did2.build.statement('assertion', id.dataset, T('NCIT:C42610'), ...
    did2.build.valueCell('text', {'E2E'}), D{:}, 'ValueKind', 'text');
id.abbreviation = abbrev.base.id;
strain = ndi.setup.V2.entityDocuments('strain', struct('name', 'N2'), struct(), D{:});
id.strain = strain{1}.base.id;
species = did2.build.statement('assertion', id.strain, T('NCIT:C45293'), ...
    T('NCBITaxon:6239'), D{:}, 'ValueKind', 'term');
id.species = species.base.id;
% a calculation names the software that computed it (software_id) and the
% operating system it ran on (operating_system_id); both are required, and
% both are shared software entities
app = ndi.setup.V2.entityDocuments('software', struct('name', 'e2e analysis', 'version', '1.0'), ...
    struct(), D{:});
id.software = app{1}.base.id;
os = ndi.setup.V2.entityDocuments('software', struct('name', 'Linux', 'version', '6.8'), ...
    struct(), D{:});
id.os = os{1}.base.id;
dsDocs = [dsDocs, {abbrev}, strain, {species}, app, os];

% ---- the session, included_in the dataset; its id is the session id
sess = ndi.setup.V2.entityDocuments('session', struct('local_identifier', 'day1'), ...
    struct(), S{:}, 'Id', id.session);
included = did2.build.directedRelation(id.session, id.dataset, 'included_in', S{:});

% ---- entities: an organism of the strain, a tissue part of it, a camera
worm = ndi.setup.V2.entityDocuments('subject', struct('local_identifier', 'worm1', ...
    'type', did2.build.term('', 'organism')), struct(), S{:});
id.organism = worm{1}.base.id;
head = ndi.setup.V2.entityDocuments('subject', struct('local_identifier', 'worm1 head', ...
    'type', did2.build.term('', 'tissue')), struct(), S{:});
id.tissue = head{1}.base.id;
camera = ndi.setup.V2.entityDocuments('subject', struct('local_identifier', 'camera1', ...
    'type', did2.build.term('', 'device')), struct(), S{:});
id.camera = camera{1}.base.id;
instanceOf = did2.build.directedRelation(id.organism, id.strain, 'instance_of', S{:});
id.instanceOf = instanceOf.base.id;
partOf = did2.build.directedRelation(id.tissue, id.organism, 'part_of', S{:});
id.partOf = partOf.base.id;
stage = did2.build.statement('assertion', id.organism, T('NCIT:C43531'), ...
    T('WBls:0000038'), S{:}, 'ValueKind', 'term');

% ---- when: 0 to 2 s after the start of the session
ref = did2.build.relativeTimeReference(id.session, 'Clock', 'dev_local_time', ...
    'Start', 0, 'Duration', 2, S{:});
id.timeReference = ref.base.id;
when = {'TimeReferenceIds', {id.timeReference}};

% ---- an observation: speed over time, 5 samples every 0.5 s, in a body
speed = [100 120 150 110 90] * 1e-6;     % metres per second
second = T('om:second-Time');
time = did2.build.dimension(T('om:Time'), numel(speed));
timeOf = did2.build.covariate(T('om:Time'), 0, 'Unit', second, ...
    'Origin', 0, 'Spacing', 0.5, ...
    'SourceUnit', T('om:millisecond-Time'), 'SourceOrigin', 0, 'SourceSpacing', 500);
obs = did2.build.statement('observation', id.organism, T('PATO:0000008'), [], ...
    'Dimensions', time, 'Covariates', timeOf, 'DataBody', true, ...
    'DatumType', did2.build.datumType('double'), ...
    'InstrumentId', id.camera, when{:}, S{:}, 'ValueKind', 'velocity');
id.observation = obs.base.id;
body = did2.build.sampledBody(id.observation, time, 'ByteOrder', 'little', ...
    'Format', T('EDAM:format_2333'), S{:});
id.body = body.base.id;
bytes = fullfile(root, 'speed.bin');
fid = fopen(bytes, 'w', 'ieee-le');
fwrite(fid, speed, 'double');
fclose(fid);
body = ndi.setup.V2.attachFile(body, 'body_data_0', bytes);

% ---- a manipulation with its method inline: held at 20 C, incubated 1 hour
manip = did2.build.statement('manipulation', id.organism, T('NCIT:C90380'), ...
    did2.build.valueCell('temperature', 20, 'SourceValue', 20, ...
        'SourceUnit', T('om:degreeCelsius')), ...
    'Method', T('EMPTY:0000333'), ...
    'MethodParameters', did2.build.parameter(T('om:Time'), 'Value', 3600, 'Unit', second, ...
        'SourceValue', '1', 'SourceUnit', T('om:hour')), ...
    when{:}, S{:}, 'ValueKind', 'temperature');
id.manipulation = manip.base.id;

% ---- a calculation from the observation, its method a standalone document
method = did2.build.method(T('NCIT:C53319'), did2.build.list( ...
        did2.build.parameter(T('EMPTY:0000281'), 'Value', 0, 'Unit', second), ...
        did2.build.parameter(T('EMPTY:0000282'), 'Value', 2, 'Unit', second)), ...
    'Name', 'mean speed', S{:});
id.method = method.base.id;
calc = did2.build.statement('calculation', id.organism, T('PATO:0000008'), ...
    did2.build.valueCell('velocity', mean(speed), 'SourceValue', mean(speed) * 1e6, ...
        'SourceUnit', T('om:micrometrePerSecond-Time')), ...
    'MethodId', id.method, 'InputIds', {id.observation}, 'SoftwareId', id.software, ...
    'OperatingSystemId', id.os, ...
    when{:}, S{:}, 'ValueKind', 'velocity');
id.calculation = calc.base.id;

sessDocs = [sess, {included}, worm, head, camera, {instanceOf, partOf, stage, ref, ...
    obs, body, manip, method, calc}];
end
