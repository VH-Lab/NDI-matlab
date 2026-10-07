classdef TestObjectLayer < matlab.unittest.TestCase
%TESTOBJECTLAYER The V2 object layer (ndi.entity, ndi.subject, ndi.statement
%and its children, ndi.data_type) over a written Haley session.
%
%   Writes TestHaleyRecordings' synthetic concentration_0001 with its
%   assertions, manipulations and calculations, opens it with
%   ndi.session.dir, and asks the questions through the objects that
%   TestHaleyWrite answers by reading documents. Also checks that the v1
%   behaviour of ndi.subject is unchanged (V2_Object_Layer.md, D5 and D6).

    properties
        Root
        Session
        Dataset
        Result
    end

    methods (TestClassSetup)
        function fixture(testCase)
            testCase.Root = tempname;
            testCase.addTeardown(@() rmdir(testCase.Root, 's'));
            ndi.unittest.setup.V2.TestHaleyRecordings.writeFixture(testCase.Root);
            testCase.Result = ndi.setup.conv.haley.import_V2(testCase.Root, ...
                'Stages', ["sessions", "subjects", "acquisition", "relations", "metadata", ...
                "assertions", "manipulations", "calculations", "dataset"], 'Sessions', "concentration_0001", ...
                'OutputRoot', fullfile(testCase.Root, 'haley_V2'), 'Write', true, ...
                'Overwrite', true, 'ReadVideos', false);
            testCase.Session = ndi.session.dir(testCase.Result.sessions.path{1});
            testCase.Dataset = ndi.dataset.dir(testCase.Result.dataset.path);
        end
    end

    methods (Test)
        function testSubjectIsAnEntity(testCase)
            w = testCase.subject('concentration_worm0121');
            testCase.verifyClass(w, 'ndi.subject');
            testCase.verifyTrue(isa(w, 'ndi.entity'));
            testCase.verifyEqual(w.id(), w.document_id, 'the subject keeps its document''s id');
            testCase.verifyEqual(w.kind, 'subject');
            p = w.document_properties();
            testCase.verifyEqual(w.name, char(p.subject.name), 'a subject''s display name is its own name');
            testCase.verifyEqual(w.name(), 'Worm 0121');
            testCase.verifyEqual(w.local_identifier, 'concentration_worm0121', ...
                'no @ is required of a V2 subject read from a document (D6)');
            if ndi.setup.V2.schemaHasField('subject', 'type')
                testCase.verifyEqual(w.type, 'organism');
                g = ndi.subject.find(testCase.Session, 'Type', 'group');
                testCase.verifyNumElements(g, 4, 'one cohort per assay plate');
            end
            e = ndi.entity.fromDocument(testCase.Session, w.document_id());
            testCase.verifyClass(e, 'ndi.subject', 'fromDocument returns the subclass');
        end

        function testNameTypeKindAndIdAreProperties(testCase)
            % read from the document when asked, shown when the object is
            % displayed, and not settable
            w = testCase.subject('concentration_worm0121');
            for p = {'name', 'type', 'kind', 'document_id'}
                testCase.verifyTrue(isprop(w, p{1}), p{1});
            end
            testCase.verifyEqual(w.name(), w.name, 'the method-call form still works');
            shown = evalc('disp(w)');
            testCase.verifySubstring(shown, 'Worm 0121');
            testCase.verifySubstring(shown, 'organism');
            testCase.verifyError(@() setName(w), ?MException);
            % a v1 subject has no document: all four are empty, and it displays
            s = ndi.subject('anteater23@nosuchlab.org', 'a subject');
            testCase.verifyEqual({s.name, s.type, s.kind, s.document_id}, {'', '', '', ''});
            testCase.verifySubstring(evalc('disp(s)'), 'anteater23@nosuchlab.org');
        end

        function testRelations(testCase)
            w = testCase.subject('concentration_worm0121');
            g = w.memberOf();
            testCase.verifyNumElements(g, 1);
            testCase.verifyEqual(g{1}.local_identifier, 'concentration_assayPlate0012_worms');
            m = g{1}.members();
            names = sort(cellfun(@(x) x.local_identifier, m, 'UniformOutput', false));
            testCase.verifyEqual(names, {'concentration_worm0121', 'concentration_worm0122'});
            T = g{1}.relations('member_of', 'Direction', 'in');
            testCase.verifyEqual(height(T), 2);
            testCase.verifyEqual(unique(T.direction), "in");

            p = testCase.subject('concentration_assayPlate0012_patch0001');
            w = p.partOf();
            testCase.verifyNumElements(w, 1);
            testCase.verifyEqual(w{1}.local_identifier, 'concentration_assayPlate0012');
            parts = w{1}.parts();
            testCase.verifyEqual(cellfun(@(x) x.local_identifier, parts, 'UniformOutput', false), ...
                {'concentration_assayPlate0012_patch0001'});
        end

        function testRelationPathsFromOneOrManyEntities(testCase)
            % parents/children take a path of relations and an array of
            % starting entities; each entity reached is returned once
            w = testCase.subject('concentration_worm0121');
            plates = w.parents({'member_of', 'contained_in'});
            names = cellfun(@(x) x.local_identifier, plates, 'UniformOutput', false);
            testCase.verifyTrue(all(ismember({'concentration_assayPlate0012', ...
                'concentration_0001_acclimationPlate0001'}, names)), strjoin(names, ', '));

            a = testCase.subject('concentration_assayPlate0012');
            worms = a.children({'contained_in', 'member_of'});
            testCase.verifyEqual(sort(local(worms)), {'concentration_worm0121', 'concentration_worm0122'});

            b = testCase.subject('concentration_0001_acclimationPlate0001');
            % the acclimation plate also held other cohorts (0011's worms):
            % the array call is the union of the one-plate calls, each worm
            % once, though 0121 and 0122 were on both plates
            onB = local(b.children({'contained_in', 'member_of'}));
            testCase.verifyTrue(all(ismember({'concentration_worm0121', 'concentration_worm0122'}, onB)));
            both = children([a b], {'contained_in', 'member_of'});
            testCase.verifyEqual(sort(local(both)), sort(unique([local(worms), onB])), ...
                'a worm on both plates is returned once');
            T = children([a b], {'contained_in', 'member_of'}, 'Table', true);
            testCase.verifyEqual(height(T), numel(worms) + numel(onB), 'one row per (plate, worm)');
            testCase.verifyEqual(sort(unique(T.start_name)), sort(string({a.name; b.name})));
            testCase.verifyEmpty(a.children({'member_of', 'member_of'}), 'nothing at the end of that path');
        end

        function testRelationsOfManyEntities(testCase)
            a = testCase.subject('concentration_assayPlate0012');
            b = testCase.subject('concentration_0001_acclimationPlate0001');
            Ta = a.relations();
            Tb = b.relations();
            T = relations([a b]);
            testCase.verifyEqual(height(T), height(Ta) + height(Tb), 'the same rows as one at a time');
            testCase.verifyEqual(sort(T.relation_id(T.start_id == a.document_id)), sort(Ta.relation_id));
            testCase.verifyEqual(unique(T.start_name(T.start_id == b.document_id)), string(b.name));
            testCase.verifyTrue(any(T.relation == "contained_in" & T.direction == "in" & ...
                T.start_id == a.document_id), 'the cohort contained_in the assay plate');
            testCase.verifyTrue(any(T.relation == "part_of" & T.direction == "in" & ...
                T.start_id == a.document_id), 'its patches part_of it');
            In = relations([a b], 'contained_in', 'Direction', 'in');
            testCase.verifyEqual(unique(In.relation), "contained_in");
            testCase.verifyEqual(sort(unique(In.start_id)), sort(string({a.document_id; b.document_id})));
            testCase.verifyEqual(height(relations([a a])), height(Ta), 'an entity given twice is read once');
        end

        function testDescendantsAndAncestorsNeedNoRelationNames(testCase)
            a = testCase.subject('concentration_assayPlate0012');
            worms = a.descendants('Type', 'organism');
            testCase.verifyEqual(sort(local(worms)), {'concentration_worm0121', 'concentration_worm0122'});
            T = a.descendants('Type', 'organism', 'Table', true);
            testCase.verifyEqual(T.depth, [2; 2], 'plate <- cohort <- worm');
            testCase.verifyEqual(T.start_id, string(repmat({a.document_id}, 2, 1)));

            w = testCase.subject('concentration_worm0121');
            g = w.ancestors('Type', 'group');
            testCase.verifyEqual(local(g), {'concentration_assayPlate0012_worms'});
            m = local(w.ancestors('Type', 'material'));
            testCase.verifyTrue(all(ismember({'concentration_assayPlate0012', ...
                'concentration_0001_acclimationPlate0001'}, m)), strjoin(m, ', '));
            testCase.verifyEqual(local(w.ancestors('Kind', 'subject')), {'concentration_assayPlate0012_worms'}, ...
                'a match is not followed further: the nearest subject is the cohort');

            parts = local(a.descendants('Relation', 'part_of'));
            testCase.verifyNotEmpty(parts);
            testCase.verifyTrue(all(startsWith(parts, 'concentration_assayPlate0012_patch')), strjoin(parts, ', '));
            all_ = local(a.descendants());
            testCase.verifyTrue(all(ismember([parts, {'concentration_assayPlate0012_worms', ...
                'concentration_worm0121', 'concentration_worm0122'}], all_)), ...
                'with no filter, everything reached');
            testCase.verifyEmpty(w.descendants('Type', 'organism'), 'nothing points to a worm');
        end

        function testAssertions(testCase)
            c = testCase.subject('concentration_assayPlate0012_worms');
            T = c.assertions();
            testCase.verifyEqual(T.node(T.variable == "species"), "NCBITaxon:6239");
            testCase.verifyEqual(T.value(T.variable == "strain"), "N2");
            a = c.statements('Class', 'assertion', 'Variable', 'strain');
            testCase.verifyNumElements(a, 1);
            testCase.verifyClass(a{1}, 'ndi.assertion');
            testCase.verifyEqual(a{1}.composite(), 'term');
            testCase.verifyEqual(a{1}.value().canonical(), "N2");
            testCase.verifyEqual(a{1}.subject().id(), c.id());
            x = testCase.subject('concentration_assayPlate0013').assertions();
            testCase.verifyEqual(x.value(x.variable == "inclusion in analysis"), "excluded");
        end

        function testInheritedFollowsMemberOfAndDistributive(testCase)
            % decision #55: species and strain are stated once, on the
            % cohort, marked distributive -- they hold of each worm
            w = testCase.subject('concentration_worm0121');
            own = w.assertions();
            testCase.verifyFalse(any(own.variable == "species"), 'nothing is stated on the worm itself');
            testCase.verifyTrue(all(own.stated_on == "concentration_worm0121"));
            T = w.assertions('Inherited', true);
            st = w.statements('Inherited', true);
            mine = w.statements();
            testCase.verifyGreaterThanOrEqual(numel(st), numel(mine), 'its own statements are kept');
            if ndi.setup.V2.schemaHasField('subject_statement', 'distributive')
                sp = T(T.variable == "species", :);
                testCase.verifyEqual(height(sp), 1);
                testCase.verifyEqual(sp.node, "NCBITaxon:6239");
                testCase.verifyEqual(sp.stated_on, "concentration_assayPlate0012_worms");
                testCase.verifyEqual(T.value(T.variable == "strain"), "N2");
                extra = st(numel(mine)+1:end);
                testCase.verifyNotEmpty(extra);
                testCase.verifyTrue(all(cellfun(@(x) x.distributive(), extra)), 'only distributive ones');
                testCase.verifyTrue(all(cellfun(@(x) strcmp(x.subject().local_identifier, ...
                    'concentration_assayPlate0012_worms'), extra)), 'each says where it was stated');
            else
                testCase.verifyEqual(numel(st), numel(mine), 'no distributive flag in this schema: nothing inherits');
            end
            % contained_in is not followed: the plate's temperature is not the worm's
            testCase.verifyEmpty(w.statements('Inherited', true, 'Class', 'temperature_manipulation'));
        end

        function testCalculationValueFromItsBody(testCase)
            w = testCase.subject('concentration_worm0121');
            sp = w.statements('Class', 'velocity_calculation');
            testCase.verifyNumElements(sp, 1);
            testCase.verifyClass(sp{1}, 'ndi.calculation');
            testCase.verifyTrue(isa(sp{1}, 'ndi.interaction'));
            v = sp{1}.value();
            testCase.verifyClass(v, 'ndi.data_type');
            testCase.verifyEqual(v.class_name, 'velocity');
            testCase.verifyEqual(double(v), 121e-6 * ones(5, 1), 'AbsTol', 1e-15, ...
                'm/s by video frame, decoded from the sampled body');
            ax = sp{1}.axes();
            testCase.verifyEqual(ax.variable(1), "video frame");
            testCase.verifyEqual(ax.n(1), 5);

            in = sp{1}.inputs();
            testCase.verifyNumElements(in, 1);
            testCase.verifyClass(in{1}, 'ndi.calculation');
            testCase.verifyEqual(in{1}.variable_name(), 'midpoint position');
            xy = double(in{1}.value());
            testCase.verifyEqual(reshape(xy, 5, 2), [(1:5)' + 12.1 - 0.5, 3.5 * ones(5, 1)], 'AbsTol', 1e-12);
            P = in{1}.method_parameters();
            testCase.verifyEqual(sort(P.variable)', ["gap filling", "longest gap filled"]);
            testCase.verifyFalse(any(cellfun(@isstruct, P.value)), ...
                'a numeric parameter is its number, not its stored record');
            P = sp{1}.method_parameters();
            num = P(cellfun(@isnumeric, P.value), :);
            testCase.verifyNotEmpty(num, 'the speed''s window and fastest step are numbers');
            testCase.verifyTrue(all(cellfun(@isscalar, num.value)));

            de = w.statements('Class', 'length_calculation');
            testCase.verifyNumElements(de, 1);
            testCase.verifyNumElements(de{1}.inputs(), 2, 'the positions and the lawn mask');
            testCase.verifyEqual(double(de{1}.value()), 2 * 1e-3 / 33 * ones(5, 1), 'AbsTol', 1e-15);
        end

        function testManipulations(testCase)
            plate = testCase.subject('concentration_assayPlate0012');
            pour = plate.statements('Class', 'manipulation', 'Variable', 'NGM agar');
            testCase.verifyNumElements(pour, 1);
            testCase.verifyClass(pour{1}, 'ndi.manipulation');
            v = pour{1}.value();
            testCase.verifyEqual(v.class_name, 'dose');
            testCase.verifyEqual(v.raw.volume.liters, 0.025, 'AbsTol', 1e-12);
            t = pour{1}.time();
            testCase.verifyNumElements(t, 1);
            testCase.verifyEqual(t.kind, 'relative', 'poured relative to the seeding');
            testCase.verifyNotEmpty(t.referent_id);
            % the formulation is reached when its document is in this session
            fid = ndi.v2.edgeIds(pour{1}.document_properties(), 'formulation_id');
            testCase.verifyEqual(fid, {testCase.Result.metadata.ids('ngm')});
            f = pour{1}.formulation();
            if isempty(ndi.v2.getDocument(testCase.Session, fid{1}))
                testCase.verifyEmpty(f, 'a dataset-level formulation is not found from a session');
            else
                testCase.verifyEqual(f.class_name, 'formulation');
            end

            tm = plate.statements('Class', 'temperature_manipulation');
            testCase.verifyNumElements(tm, 2);
            m = sort(cellfun(@(s) s.method_name(), tm, 'UniformOutput', false));
            testCase.verifyEqual(m, {'ambient exposure', 'refrigeration'});
            for i = 1:2
                v = tm{i}.value();
                testCase.verifyNotEmpty(v.unit());
                testCase.verifyEqual(double(v), double(v.raw.(v.unit())));
            end

            moves = ndi.statement.find(testCase.Session, 'Variable', 'location', 'Method', 'agar plug transfer');
            testCase.verifyNotEmpty(moves);
            testCase.verifyTrue(all(cellfun(@(s) isa(s, 'ndi.manipulation'), moves)));
            P = moves{1}.method_parameters();
            testCase.verifyTrue(any(P.variable == "cleaning step"));
        end

        function testDatasetLevelDocumentsAreReachedThroughTheDataset(testCase)
            % software, formulations, strains and people are stored with the
            % dataset (decision #20): read through the dataset, a statement
            % reaches them; read through a session, it does not
            local = 'concentration_worm0121';
            ws = ndi.subject.find(testCase.Session, 'LocalIdentifier', local);
            w = ndi.subject.fromDocument(testCase.Dataset, ws{1}.document_id());
            sp = w.statements('Class', 'velocity_calculation');
            testCase.verifyNumElements(sp, 1);
            testCase.verifyEqual(double(sp{1}.value()), 121e-6 * ones(5, 1), 'AbsTol', 1e-15);
            testCase.assertNotEmpty(ndi.v2.edgeIds(sp{1}.document_properties(), 'software_id'), ...
                'with stage 2 run, a calculation names its software (import_V2, stage 10)');
            sw = sp{1}.software();
            testCase.verifyNumElements(sw, 1, 'the analysis package, from the dataset');
            testCase.verifyEqual(sw{1}.kind(), 'software');
            spS = ws{1}.statements('Class', 'velocity_calculation');
            testCase.verifyEmpty(spS{1}.software(), 'not reached through the session');

            plate = ndi.subject.fromDocument(testCase.Dataset, ...
                testCase.subject('concentration_assayPlate0012').document_id());
            pour = plate.statements('Class', 'manipulation', 'Variable', 'NGM agar');
            f = pour{1}.formulation();
            testCase.verifyNotEmpty(f, 'the formulation is found through the dataset');
            testCase.verifyEqual(f.class_name, 'formulation');
        end

        function testReadingAV2DocumentGivesTheFullPassResult(testCase)
            % applyReadNormalization takes a shortcut for documents already
            % at the read target (when DID-matlab has it). Every document of
            % the written session must come out exactly as the full
            % v1_to_v2 pass makes it.
            db = did2.database.sqlitedb(fullfile(testCase.Result.sessions.path{1}, '.ndi', ...
                ndi.database.implementations.database.did2sqlite.DEFAULTFILENAME()));
            closer = onCleanup(@() db.close());
            ids = db.allIds();
            testCase.assertGreaterThan(numel(ids), 100, 'the written session has documents');
            nDiffer = 0; first = '';
            for i = 1:numel(ids)
                d = db.get(ids{i});
                got = ndi.database.internal.applyReadNormalization(d);
                full = did2.convert.v1_to_v2(d.toStruct(), 'Validate', false, ...
                    'RenameClassNames', false, 'TargetVersion', 'V_delta');
                want = ndi.document(full.migrated{1}.toStruct());
                if ~isequaln(got.document_properties, want.document_properties)
                    nDiffer = nDiffer + 1;
                    if isempty(first), first = ids{i}; end
                end
            end
            testCase.verifyEqual(nDiffer, 0, sprintf(['%d of %d document(s) read differently ' ...
                'from the full pass; first: %s'], nDiffer, numel(ids), first));
        end

        function testInteractionIsAbstract(testCase)
            testCase.verifyTrue(meta.class.fromName('ndi.interaction').Abstract);
        end

        function testV1SubjectUnchanged(testCase)
            % D5, D6: making a v1 subject still requires the @, and works as before
            testCase.verifyError(@() ndi.subject('nolab', 'a subject'), ?MException);
            s = ndi.subject('anteater23@nosuchlab.org', 'a subject');
            testCase.verifyEqual(s.local_identifier, 'anteater23@nosuchlab.org');
            testCase.verifyEqual(s.description, 'a subject');
            testCase.verifyTrue(isa(s, 'ndi.entity'));
            testCase.verifyEmpty(s.statements(), 'a subject with no container has no statements');
            testCase.verifyEqual(s.type, '');
            d = s.newdocument();
            testCase.verifyEqual(d.document_properties.subject.local_identifier, 'anteater23@nosuchlab.org');
        end
    end

    methods
        function s = subject(testCase, local)
            x = ndi.subject.find(testCase.Session, 'LocalIdentifier', local);
            testCase.assertNumElements(x, 1, local);
            s = x{1};
        end
    end
end

function n = local(c)
n = cellfun(@(x) x.local_identifier, c, 'UniformOutput', false);
n = reshape(n, 1, []);
end

function setName(w)
w.name = 'x';
end
