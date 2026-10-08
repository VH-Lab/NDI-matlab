classdef TestObjectLayer < matlab.unittest.TestCase
%TESTOBJECTLAYER The V2 object layer (ndi.entity, ndi.subject, ndi.statement
%and its children, ndi.value) over a written Haley session.
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
                "assertions", "manipulations", "observations", "calculations", "dataset"], ...
                'Sessions', "concentration_0001", ...
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
            testCase.verifyEqual(w.name, char(ndi.v2.blockOf(p, 'subject', 'name')), 'a subject''s display name is its own name');
            testCase.verifyEqual(w.name(), 'Worm 0121');
            testCase.verifyEqual(w.local_identifier, 'concentration_worm0121', ...
                'no @ is required of a V2 subject read from a document (D6)');
            if ndi.setup.V2.schemaHasField('subject', 'type')
                testCase.verifyEqual(w.type, 'organism');
                g = ndi.subject.search(testCase.Session, 'Type', 'group');
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

            testCase.verifyEqual(sort(local(w.ancestors('Type', 'material', 'Kind', 'subject'))), sort(m), ...
                'Type and Kind together');
            testCase.verifyEmpty(w.ancestors('Type', 'material', 'Kind', 'person'));

            parts = local(a.descendants('Relation', 'part_of'));
            testCase.verifyNotEmpty(parts);
            testCase.verifyTrue(all(startsWith(parts, 'concentration_assayPlate0012_patch')), strjoin(parts, ', '));
            all_ = local(a.descendants());
            testCase.verifyTrue(all(ismember([parts, {'concentration_assayPlate0012_worms', ...
                'concentration_worm0121', 'concentration_worm0122'}], all_)), ...
                'with no filter, everything reached');
            testCase.verifyEmpty(w.descendants('Type', 'organism'), 'nothing points to a worm');
        end

        function testFindByWhatIsTrueOfASubject(testCase)
            % strain and species are stated on each cohort, distributive
            % (decision #55): a search finds the worms without knowing that
            S = testCase.Session;
            w = ndi.subject.search(S, 'type', 'organism', 'species', 'Caenorhabditis elegans', 'strain', 'N2');
            names = local(w);
            testCase.verifyTrue(all(ismember({'concentration_worm0121', 'concentration_worm0122'}, names)), ...
                strjoin(names, ', '));
            testCase.verifyTrue(all(cellfun(@(x) strcmp(x.type, 'organism'), w)));
            testCase.verifyTrue(ismember('concentration_assayPlate0012_worms', ...
                local(ndi.subject.search(S, 'strain', 'N2'))), 'the cohort it was stated on matches too');

            % property names and value names ignore case; nodes are exact
            same = @(varargin) isequal(sort(local(ndi.subject.search(S, varargin{:}))), sort(names));
            testCase.verifyTrue(same('Type', 'Organism', 'STRAIN', 'n2'));
            testCase.verifyTrue(same('type', 'organism', 'species', 'NCBITaxon:6239', 'strain', 'N2'));
            testCase.verifyTrue(same('type', 'organism', 'strain', {'N2', 'no such strain'}), 'a cell is any of');
            testCase.verifyTrue(same('type', 'organism', 'strain', 'N*'), 'a wildcard');
            testCase.verifyTrue(same('type', 'organism', 'species', '*ELEGANS', 'strain', 'N2'), ...
                'a wildcard on a name ignores case');
            testCase.verifyTrue(same('type', 'organism', 'species', 'NCBITaxon:*', 'strain', 'N2'), ...
                'a wildcard on a node');

            % inherited false: only what was stated on the subject itself
            testCase.verifyEmpty(ndi.subject.search(S, 'type', 'organism', 'strain', 'N2', 'inherited', false), ...
                'strain is stated on no worm itself');
            testCase.verifyEqual(sort(local(ndi.subject.search(S, 'strain', 'N2', 'inherited', false))), ...
                sort(local(ndi.subject.search(S, 'strain', 'N2', 'type', 'group'))), 'the cohorts alone');

            ecoli = ndi.subject.search(S, 'species', 'NCBITaxon:562');
            testCase.verifyNotEmpty(ecoli);
            testCase.verifyFalse(any(cellfun(@(x) strcmp(x.type, 'organism'), ecoli)), 'lawns, not worms');
            testCase.verifyEqual(local(ndi.subject.search(S, 'strain', 'N2', ...
                'local_identifier', 'concentration_worm0121')), {'concentration_worm0121'});
            testCase.verifyEqual(local(ndi.subject.search(S, 'LocalIdentifier', 'concentration_worm0121')), ...
                {'concentration_worm0121'}, 'the old spelling still works');

            % a misspelled variable is an error; a value no one has, a warning
            testCase.verifyError(@() ndi.subject.search(S, 'stran', 'N2'), 'ndi:subject:search:unknownVariable');
            testCase.verifyWarning(@() ndi.subject.search(S, 'species', 'Caenorhabdiits elegans'), ...
                'ndi:subject:search:noSuchValue');
            testCase.verifyEmpty(testCase.verifyWarning(@() ndi.subject.search(S, 'strain', 'no such strain'), ...
                'ndi:subject:search:noSuchValue'));
            testCase.verifyError(@() ndi.subject.search(S, 'strain'), 'ndi:subject:search:pairs');
        end

        function testFindByAStatementOfAKind(testCase)
            % the six statement keys: the filters in one cell are one
            % statement; a key given twice is two statements
            S = testCase.Session;
            plate = 'concentration_assayPlate0012';
            has = @(varargin) ismember(plate, local(ndi.subject.search(S, varargin{:})));
            testCase.verifyTrue(has('manipulation', {'variable', 'NGM agar'}));
            testCase.verifyTrue(has('manipulation', {'method', 'refrigeration'}));
            testCase.verifyTrue(has('interaction', {'method', 'refrigeration'}), 'an interaction is any of the three');
            testCase.verifyTrue(has('statement', {'variable', 'NGM agar'}));
            testCase.verifyTrue(has('manipulation', {'method', 'REFRIG*'}), 'a wildcard, any case');
            % a dose compares by its amount, in its canonical unit (liters)
            testCase.verifyTrue(has('manipulation', {'variable', 'NGM agar', 'value', '>=0.02'}));
            testCase.verifyTrue(has('manipulation', {'variable', 'NGM agar', 'value', '<=0.025'}));
            w = warning('off', 'ndi:subject:search:noSuchValue');
            restore = onCleanup(@() warning(w));
            testCase.verifyFalse(has('manipulation', {'variable', 'NGM agar', 'value', '>0.03'}));
            % one statement that is both, versus two statements
            testCase.verifyEmpty(ndi.subject.search(S, 'manipulation', {'method', 'refrigeration', ...
                'variable', 'NGM agar'}), 'no single manipulation is both: none, not an error');
            testCase.verifyTrue(has('manipulation', {'method', 'refrigeration'}, ...
                'manipulation', {'variable', 'NGM agar'}));
            % the shorthand is an assertion
            testCase.verifyEqual(sort(local(ndi.subject.search(S, 'assertion', {'variable', 'strain', 'value', 'N2'}))), ...
                sort(local(ndi.subject.search(S, 'strain', 'N2'))));
            testCase.verifyEqual(sort(local(ndi.subject.search(S, 'str*', 'N2'))), ...
                sort(local(ndi.subject.search(S, 'strain', 'N2'))), 'a wildcard in the property name');
            testCase.verifyError(@() ndi.subject.search(S, 'assertion', {'method', 'x'}), ...
                'ndi:subject:search:assertionMethod');
            testCase.verifyError(@() ndi.subject.search(S, 'manipulation', {'method', 'no such method'}), ...
                'ndi:subject:search:noSuchStatement');
            testCase.verifyError(@() ndi.subject.search(S, 'manipulation', {'colour', 'x'}), ...
                'ndi:subject:search:statementFilter');
            testCase.verifyError(@() ndi.subject.search(S, 'manipulation', 'NGM agar'), ...
                'ndi:subject:search:statementFilter');
            % a plate's statements are not its worms': contained_in is not followed
            testCase.verifyEmpty(ndi.subject.search(S, 'type', 'organism', 'manipulation', {'variable', 'NGM agar'}));
        end

        function testFindByRelation(testCase)
            S = testCase.Session;
            worms = {'concentration_worm0121', 'concentration_worm0122'};
            cohort = testCase.subject('concentration_assayPlate0012_worms');
            plate = testCase.subject('concentration_assayPlate0012');
            names = @(varargin) sort(local(ndi.subject.search(S, varargin{:})));

            % the shortcut: a relation's name, the subject is the child
            testCase.verifyEqual(names('member_of', cohort), worms);
            testCase.verifyEqual(names('directed_relation', {'parent', cohort}), worms, 'no name: any relation');
            testCase.verifyEqual(names('directed_relation', {'name', 'member_of', 'parent', cohort.document_id}), ...
                worms, 'the other end as a document id');
            % the cohort is contained_in the plate, distributive: so is each worm
            testCase.verifyEqual(names('type', 'organism', 'contained_in', plate), worms);
            testCase.verifyEmpty(ndi.subject.search(S, 'type', 'organism', 'contained_in', plate, 'inherited', false), ...
                'not inherited: no worm is contained_in anything itself');
            % the other end described, not named
            onNGM = names('type', 'organism', 'contained_in', {'manipulation', {'variable', 'NGM agar'}});
            testCase.verifyTrue(all(ismember(worms, onNGM)), strjoin(onNGM, ', '));
            % the reverse: the subject is the parent
            p = names('directed_relation', {'name', 'part_of', 'child', ...
                {'local_identifier', 'concentration_assayPlate0012_patch0001'}});
            testCase.verifyEqual(p, {'concentration_assayPlate0012'});
            % nested: worms on the plate that patch 0001 is part of
            testCase.verifyEqual(names('type', 'organism', 'contained_in', {'directed_relation', ...
                {'name', 'part_of', 'child', {'local_identifier', 'concentration_assayPlate0012_patch0001'}}}), worms);
            % 'with': either end
            w = names('relation', {'with', cohort});
            testCase.verifyTrue(all(ismember([worms, {'concentration_assayPlate0012', ...
                'concentration_0001_acclimationPlate0001'}], w)), strjoin(w, ', '));
            testCase.verifyEqual(local(ndi.subject.search(S, 'id', cohort.document_id)), ...
                {'concentration_assayPlate0012_worms'});

            % explain says what it will do
            out = evalc('ndi.subject.search(S, ''type'', ''organism'', ''contained_in'', {''manipulation'', {''variable'', ''NGM agar''}}, ''explain'', true);');
            testCase.verifySubstring(out, 'contained_in');
            testCase.verifySubstring(out, 'NGM agar');
            testCase.verifySubstring(out, 'Searching this session for subjects that');
            testCase.verifySubstring(out, 'are of type organism');
            testCase.verifySubstring(out, 'had a manipulation with variable NGM agar');

            testCase.verifyError(@() ndi.subject.search(S, 'directed_relation', {'name', 'containd_in'}), ...
                'ndi:subject:search:unknownRelation');
            testCase.verifyError(@() ndi.subject.search(S, 'contained_in', plate, 'directed_relation', ...
                {'name', 'contained_in', 'parent', plate, 'depth', 2}), 'ndi:subject:search:notYet');
            testCase.verifyError(@() ndi.subject.search(S, 'undirected_relation', {'parent', plate}), ...
                'ndi:subject:search:relationFilter');
            testCase.verifyError(@() ndi.subject.search(S, 'directed_relation', {'parent', plate, 'child', plate}), ...
                'ndi:subject:search:relationFilter');
        end

        function testAnAssertionAboutAWholeHoldsOfItsParts(testCase)
            % plate 0013 is excluded (an assertion on the plate): its patches,
            % part_of it, are too; its worms, contained_in it, are not
            S = testCase.Session;
            direct = local(ndi.subject.search(S, 'inclusion in analysis', 'excluded', 'inherited', false));
            testCase.verifyTrue(ismember('concentration_assayPlate0013', direct));
            all_ = local(ndi.subject.search(S, 'inclusion in analysis', 'excluded'));
            extra = setdiff(all_, direct);
            testCase.verifyTrue(all(startsWith(extra, 'concentration_assayPlate0013_patch')), strjoin(extra, ', '));
            patches = local(ndi.subject.search(S, 'directed_relation', {'name', 'part_of', 'parent', ...
                {'local_identifier', 'concentration_assayPlate0013'}}));
            testCase.verifyEqual(sort(extra), sort(patches), 'exactly its parts');
            testCase.verifyEmpty(ndi.subject.search(S, 'type', 'organism', 'inclusion in analysis', 'excluded'), ...
                'contained_in does not carry statements');
        end

        function testContextIsWhatTheSubjectWasIn(testCase)
            % V_eta tenet T17: a container's interactions reach what it
            % contained only with 'context', true, only while it was in it,
            % and marked as reached through contained_in. Assertions never.
            if ~ndi.setup.V2.schemaHasField('statement', 'distributive')
                return;   % the stays are stated on the cohort, distributive
            end
            S = testCase.Session;
            w = testCase.subject('concentration_worm0121');
            c = testCase.subject('concentration_assayPlate0012_worms');
            plates = cellfun(@(x) x.document_id, c.parents('contained_in'), 'UniformOutput', false);
            testCase.assertNotEmpty(plates, 'the cohort was on plates');
            isCtx = @(x) endsWith(x.via(), 'contained_in');

            % off by default: nothing about the worm comes from its plates
            testCase.verifyFalse(any(cellfun(isCtx, w.statements())));
            testCase.verifyEmpty(w.manipulations({'variable', 'ambient temperature'}));

            m = w.manipulations('context', true);
            ctx = m(cellfun(isCtx, m));
            testCase.verifyNotEmpty(ctx, 'its plates'' manipulations while it was on them');
            testCase.verifyTrue(all(cellfun(@(x) ismember(x.subject().document_id, plates), ctx)), ...
                'only the plates it was on; stated_on is the plate');
            testCase.verifyTrue(all(cellfun(@(x) strcmp(x.via(), 'member_of > contained_in'), ctx)), ...
                'through its cohort''s distributive stay');
            vars = cellfun(@(x) x.variable_name(), ctx, 'UniformOutput', false);
            methods_ = cellfun(@(x) char(ndi.v2.termName(ndi.v2.blockOf(x.document_properties(), ...
                'interaction', 'method', ''))), ctx, 'UniformOutput', false);
            testCase.verifyTrue(any(strcmp(vars, 'ambient temperature')), ...
                'the bench and the incubator, while it was there');
            testCase.verifyFalse(any(strcmp(vars, 'NGM agar')), ...
                'the pour is only known to be before the seeding: it cannot be placed in the stay');
            testCase.verifyFalse(any(strcmp(methods_, 'refrigeration')), ...
                'the cold room was before the worms arrived');
            own = w.manipulations();
            testCase.verifyEqual(numel(m) - numel(ctx), numel(own), 'context adds; it removes nothing');

            % the videos of the plate it was filmed on
            o = w.observations('context', true);
            testCase.verifyNotEmpty(o(cellfun(isCtx, o)), 'the assay plate''s recordings');

            % assertions never pass: plate 0013 is excluded, its worms are not
            testCase.verifyEqual(numel(w.assertions('context', true)), numel(w.assertions()));
            testCase.verifyEmpty(ndi.subject.search(S, 'type', 'organism', ...
                'inclusion in analysis', 'excluded', 'context', true));

            % search: a plate's room-temperature period finds the worms on it then
            found = local(ndi.subject.search(S, 'type', 'organism', ...
                'manipulation', {'method', 'ambient exposure'}, 'context', true));
            testCase.verifyTrue(ismember('concentration_worm0121', found));
            testCase.verifyEmpty(ndi.subject.search(S, 'type', 'organism', ...
                'manipulation', {'method', 'ambient exposure'}), 'not without context');
            testCase.verifyEmpty(ndi.subject.search(S, 'type', 'organism', ...
                'manipulation', {'method', 'refrigeration'}, 'context', true), ...
                'every cold room was before the worms arrived');
            out = evalc(['ndi.subject.search(S, ''type'', ''organism'', ''manipulation'', ' ...
                '{''method'', ''ambient exposure''}, ''context'', true, ''explain'', true);']);
            testCase.verifySubstring(out, 'contained in something that did while they were in it');
        end

        function testDuringAnotherStatement(testCase)
            % 'during' takes a description of statements as well as times:
            % kept when it overlaps one matching it that holds of the same
            % subject, by the same rules ('inherited', 'context'). The
            % fixture's plates read 21.5 + plate/100 C over their videos, so
            % '>21.615' is plates 12 and 14 (21.62, 21.64), not plate 11 (21.61).
            S = testCase.Session;
            plate = testCase.subject('concentration_assayPlate0012');
            hot = {'observation', {'variable', 'ambient temperature', 'value', '>21.615'}};
            cold = {'observation', {'variable', 'ambient temperature', 'value', '>30'}};
            v = plate.observations({'variable', 'image intensity'});
            testCase.assertNotEmpty(v, 'plate 12 was filmed');
            during = plate.observations({'variable', 'image intensity', 'during', hot});
            testCase.verifyNotEmpty(during, 'plate 12''s reading is timed by one of its videos');
            testCase.verifyLessThanOrEqual(numel(during), numel(v));
            testCase.verifyEmpty(plate.observations({'variable', 'image intensity', 'during', cold}));
            other = testCase.subject('concentration_assayPlate0011');
            testCase.verifyEmpty(other.observations({'variable', 'image intensity', 'during', hot}), ...
                'plate 11 read 21.61 C; plate 12''s reading is not plate 11''s');

            if ndi.setup.V2.schemaHasField('statement', 'distributive')
                % a worm: its plate's videos, while that plate was over 21.615 C
                w = testCase.subject('concentration_worm0121');
                testCase.verifyEmpty(w.observations({'variable', 'image intensity', 'during', hot}), ...
                    'without context the worm has neither the videos nor the reading');
                o = w.observations({'variable', 'image intensity', 'during', hot}, 'context', true);
                testCase.verifyNotEmpty(o);
                testCase.verifyTrue(all(cellfun(@(x) strcmp(x.subject().local_identifier, ...
                    'concentration_assayPlate0012'), o)));
                t = w.observations({'variable', 'ambient temperature'}, 'context', true);
                testCase.verifyNumElements(t, 1, 'the one reading of the plate it was filmed on');
                testCase.verifyEqual(double(t{1}.value()), 21.62, 'AbsTol', 1e-9);

                % search: worms filmed while their plate was over 21.615 C
                found = local(ndi.subject.search(S, 'type', 'organism', 'context', true, ...
                    'observation', {'variable', 'image intensity', 'during', hot}));
                testCase.verifyTrue(ismember('concentration_worm0121', found));
                warm = local(ndi.subject.search(S, 'type', 'organism', 'contained_in', ...
                    {'local_identifier', {'concentration_assayPlate0012', 'concentration_assayPlate0014'}}));
                testCase.verifyEmpty(setdiff(found, warm), 'only the worms on plates 12 and 14');
                cool = local(ndi.subject.search(S, 'type', 'organism', 'contained_in', other));
                testCase.verifyEmpty(intersect(found, cool), 'none of the worms on plate 11');
                testCase.verifyEmpty(ndi.subject.search(S, 'type', 'organism', 'context', true, ...
                    'observation', {'variable', 'image intensity', 'during', cold}));
                out = evalc(['ndi.subject.search(S, ''type'', ''organism'', ''context'', true, ' ...
                    '''observation'', {''variable'', ''image intensity'', ''during'', hot}, ''explain'', true);']);
                testCase.verifySubstring(out, 'at a time when they also had an observation with variable ambient temperature');
            end
            testCase.verifyError(@() plate.observations({'during', {'assertion', {'variable', 'strain'}}}), ...
                'ndi:subject:search:assertionTime');
        end

        function testTimeFilters(testCase)
            % the fixture's windows (TestHaleyWrite pins them), Los Angeles:
            % cohort 0012 on acclimation plate 0001 from 2022-02-03 12:10:51 to
            % 2022-02-04 12:10:51; cohort 0014 food-deprived for exactly 3 h,
            % 2022-02-04 12:17:10 to 15:17:10 (the end, T, up to 5 min early)
            S = testCase.Session;
            w = warning('off', 'ndi:subject:search:noSuchTime');
            restore = onCleanup(@() warning(w));
            acc = testCase.subject('concentration_0001_acclimationPlate0001');
            on = @(varargin) local(ndi.subject.search(S, 'type', 'organism', 'directed_relation', ...
                [{'name', 'contained_in', 'parent', acc}, varargin]));
            worms = {'concentration_worm0121', 'concentration_worm0122'};
            testCase.verifyTrue(all(ismember(worms, on('at', '2022-02-03T18:00'))), 'local time, the lab''s zone');
            testCase.verifyTrue(all(ismember(worms, on('at', '2022-02-04T02:00Z'))), 'the same instant in UTC');
            testCase.verifyTrue(all(ismember(worms, on('at', datetime(2022, 2, 3, 18, 0, 0)))), 'a datetime');
            testCase.verifyFalse(any(ismember(worms, on('at', '2022-02-02T18:00'))), 'before the pick');
            testCase.verifyTrue(all(ismember(worms, on('during', '2022-02-03'))), 'a whole day');
            testCase.verifyTrue(all(ismember(worms, on('during', {'2022-02-01', '2022-02-03T13:00'}))));
            testCase.verifyFalse(any(ismember(worms, on('during', '2022-02-01'))));
            testCase.verifyTrue(all(ismember(worms, on('before', '2022-02-05'))));
            testCase.verifyTrue(all(ismember(worms, on('after', '2022-02-03'))));
            testCase.verifyFalse(any(ismember(worms, on('after', '2022-02-04'))));

            % duration, and tolerance
            fd = local(ndi.subject.search(S, 'member_of', testCase.subject('concentration_assayPlate0014_worms')));
            testCase.assertNotEmpty(fd);
            deprived = @(varargin) local(ndi.subject.search(S, 'type', 'organism', 'manipulation', ...
                [{'variable', 'food availability'}, varargin{1}], varargin{2:end}));
            testCase.verifyEqual(sort(deprived({'duration', '>=3h'})), sort(fd));
            testCase.verifyEqual(sort(deprived({'duration', '>=180min'})), sort(fd));
            testCase.verifyEmpty(deprived({'duration', '>3h'}), 'exactly 3 h as stated');
            testCase.verifyEqual(sort(deprived({'duration', '>3h'}, 'tolerant', true)), sort(fd), ...
                'the hand-written start could be a minute early');
            warning('on', 'ndi:subject:search:noSuchTime');
            testCase.verifyWarning(@() ndi.subject.search(S, 'manipulation', ...
                {'variable', 'food availability', 'duration', '>4h'}), 'ndi:subject:search:noSuchTime');
            warning('off', 'ndi:subject:search:noSuchTime');

            % a time known only as "before the seeding" (a plate's pour) is a bound
            plate = 'concentration_assayPlate0012';
            poured = @(varargin) local(ndi.subject.search(S, 'manipulation', [{'variable', 'NGM agar'}, varargin]));
            testCase.verifyTrue(ismember(plate, poured('before', '2030-01-01')), 'the bound decides it');
            testCase.verifyFalse(ismember(plate, poured('at', '2022-02-04T12:00')), 'a bound cannot place it');

            out = evalc(['ndi.subject.search(S, ''type'', ''organism'', ''manipulation'', ' ...
                '{''variable'', ''food availability'', ''duration'', ''>=3h''}, ''explain'', true);']);
            testCase.verifySubstring(out, 'lasting >=3h');
            testCase.verifyError(@() ndi.subject.search(S, 'directed_relation', ...
                {'name', 'contained_in', 'at', 'sometime after lunch'}), 'ndi:v2:timeFilter:badTime');
            testCase.verifyError(@() ndi.subject.search(S, 'manipulation', ...
                {'variable', 'food availability', 'duration', '3 fortnights'}), 'ndi:v2:timeFilter:badDuration');
        end

        function testAssertions(testCase)
            c = testCase.subject('concentration_assayPlate0012_worms');
            a = c.assertions();
            testCase.verifyTrue(all(cellfun(@(x) isa(x, 'ndi.assertion'), a)), 'objects, not a table');
            T = ndi.summary(a);
            testCase.verifyEqual(T.value_node(T.variable == "species"), "NCBITaxon:6239");
            testCase.verifyEqual(T.value(T.variable == "strain"), "N2");
            st = c.assertions({'variable', 'strain'});
            testCase.verifyNumElements(st, 1, 'a cell of filters comes first');
            testCase.verifyEqual(st{1}.variable_name(), 'strain');
            a = c.statements('Class', 'assertion', 'Variable', 'strain');
            testCase.verifyNumElements(a, 1);
            testCase.verifyClass(a{1}, 'ndi.assertion');
            testCase.verifyEqual(a{1}.composite(), 'term');
            testCase.verifyEqual(a{1}.value().canonical(), "N2");
            testCase.verifyEqual(a{1}.subject().id(), c.id());
            x = testCase.subject('concentration_assayPlate0013').assertions({'variable', 'inclusion in analysis'});
            testCase.verifyNumElements(x, 1);
            testCase.verifyEqual(x{1}.value().canonical(), "excluded");
        end

        function testInheritedFollowsMemberOfAndDistributive(testCase)
            % decision #55: species and strain are stated once, on the
            % cohort, marked distributive -- they hold of each worm, and are
            % read that way by default
            w = testCase.subject('concentration_worm0121');
            own = w.assertions('inherited', false);
            testCase.verifyFalse(any(cellfun(@(x) strcmp(x.variable_name(), 'species'), own)), ...
                'nothing is stated on the worm itself');
            testCase.verifyTrue(all(cellfun(@(x) strcmp(x.subject().document_id, w.document_id), own)));
            T = w.assertions();
            st = w.statements();
            mine = w.statements('inherited', false);
            testCase.verifyTrue(all(cellfun(@(x) strcmp(x.via(), 'own'), mine)));
            testCase.verifyEqual(sum(cellfun(@(x) strcmp(x.via(), 'own'), st)), numel(mine), ...
                'its own statements are kept');
            if ndi.setup.V2.schemaHasField('statement', 'distributive')
                sp = T(cellfun(@(x) strcmp(x.variable_name(), 'species'), T));
                testCase.verifyNumElements(sp, 1);
                testCase.verifyEqual(sp{1}.raw_value().node, 'NCBITaxon:6239');
                testCase.verifyEqual(sp{1}.subject().local_identifier, 'concentration_assayPlate0012_worms');
                testCase.verifyEqual(sp{1}.via(), 'member_of');
                strain = T(cellfun(@(x) strcmp(x.variable_name(), 'strain'), T));
                testCase.verifyEqual(strain{1}.value().canonical(), "N2");
                extra = st(cellfun(@(x) ~strcmp(x.via(), 'own'), st));
                testCase.verifyNotEmpty(extra);
                testCase.verifyTrue(all(cellfun(@(x) x.distributive(), extra)), 'only distributive ones');
                testCase.verifyTrue(all(cellfun(@(x) strcmp(x.subject().local_identifier, ...
                    'concentration_assayPlate0012_worms'), extra)), 'each says where it was stated');
                testCase.verifyTrue(all(cellfun(@(x) strcmp(x.about(), w.document_id), st)), ...
                    'each says which subject it was asked for');
            else
                testCase.verifyEqual(numel(st), numel(mine), 'no distributive flag in this schema: nothing inherits');
            end
            % contained_in is not followed: the plate's temperature is not the worm's
            testCase.verifyEmpty(w.statements('Class', 'temperature_manipulation'));
            testCase.verifyEmpty(w.statements('manipulation', {'variable', 'ambient temperature'}));
        end

        function testStatementsOfManySubjectsAndSummaries(testCase)
            S = testCase.Session;
            ws = ndi.subject.search(S, 'type', 'organism', 'contained_in', ...
                testCase.subject('concentration_assayPlate0012'));
            W = [ws{:}];
            testCase.assertNumElements(W, 2);
            st = statements(W, 'assertion');
            about = cellfun(@(x) x.about(), st, 'UniformOutput', false);
            testCase.verifyEqual(sort(unique(about)), sort({W.document_id}), 'one set per worm');
            one = W(1).statements('assertion');
            testCase.verifyEqual(sum(strcmp(about, W(1).document_id)), numel(one), ...
                'the same as asking one worm at a time');
            A = assertions(W);
            testCase.verifyEqual(numel(A), numel(st), 'assertions is statements of one kind');
            % the kind shortcuts are statements of that kind, filters included
            kinds = {'observation', 'manipulation', 'calculation', 'interaction'};
            short = {@observations, @manipulations, @calculations, @interactions};
            for k = 1:numel(kinds)
                testCase.verifyEqual(cellfun(@(x) x.document_id(), short{k}(W), 'UniformOutput', false), ...
                    cellfun(@(x) x.document_id(), statements(W, kinds{k}), 'UniformOutput', false), kinds{k});
            end
            if ndi.setup.V2.schemaHasField('statement', 'distributive')
                m = manipulations(W(1), {'variable', 'location'});
                testCase.verifyNotEmpty(m, 'the moves onto plates, stated on the cohort');
                testCase.verifyTrue(all(cellfun(@(x) strcmp(x.variable_name(), 'location'), m)));
            end

            T = ndi.summary(ws);
            testCase.verifyEqual(height(T), 2);
            testCase.verifyTrue(all(ismember({'name', 'kind', 'id', 'type', 'local_identifier'}, ...
                T.Properties.VariableNames)));
            if ismember('strain', T.Properties.VariableNames)
                testCase.verifyEqual(T.strain, ["N2"; "N2"], 'the cohort''s strain, inherited');
            end
            testCase.verifyEqual(W(1).summary().id, string(W(1).document_id), 'one object: one row');
            N = ndi.summary(ws, 'nodes', true);
            if ismember('species', N.Properties.VariableNames)
                testCase.verifyEqual(N.species_node, ["NCBITaxon:6239"; "NCBITaxon:6239"]);
                testCase.verifyFalse(ismember('species_node', T.Properties.VariableNames), 'nodes only when asked');
            end

            U = ndi.summary(statements(W));
            testCase.verifyEqual(height(U), numel(statements(W)));
            testCase.verifyTrue(all(ismember({'subject', 'kind', 'class', 'variable', 'variable_node', ...
                'method', 'method_node', 'value', 'value_node', 'unit', 'start', 'end', 'timezone', ...
                'stated_on', 'via', 'id'}, U.Properties.VariableNames)));
            sp = U(U.variable == "species", :);
            if height(sp) > 0
                testCase.verifyEqual(unique(sp.value_node), "NCBITaxon:6239", 'a term value carries its node');
            end
            timed = U(~isnat(U.start), :);
            testCase.verifyNotEmpty(timed, 'the transfers have times');
            testCase.verifyEqual(unique(timed.timezone), "America/Los_Angeles");
            testCase.verifyEqual(U.start.TimeZone, 'America/Los_Angeles', 'shown in the zone recorded');
            testCase.verifyClass(U.start, 'datetime');
            testCase.verifyError(@() ndi.summary(statements(W), 'nodes', true), 'ndi:summary:options');
            r = U(U.variable == "strain", :);
            if height(r) > 0
                testCase.verifyEqual(unique(r.via), "member_of");
                testCase.verifyEqual(unique(r.stated_on), "Worms on Assay Plate 0012");
            end
            m = U(U.kind == "manipulation" & U.via == "member_of", :);
            testCase.verifyTrue(all(~isnat(m.start) | m.value ~= ""), 'transfers have times or values');
            testCase.verifyError(@() ndi.summary([ws, statements(W)]), 'ndi:summary:mixed');
            testCase.verifyEqual(height(ndi.summary({})), 0);
        end

        function testStrictAndTheMessages(testCase)
            S = testCase.Session;
            testCase.verifyError(@() ndi.subject.search(S, 'stran', 'N2'), 'ndi:subject:search:unknownVariable');
            try
                ndi.subject.search(S, 'stran', 'N2');
            catch err
                testCase.verifySubstring(err.message, 'No subject in this session has a property ''stran''.');
                testCase.verifySubstring(err.message, 'Did you mean ''strain''?');
                testCase.verifySubstring(err.message, 'Properties in this session: ');
                testCase.verifySubstring(err.message, 'local_identifier');
            end
            testCase.verifyWarning(@() ndi.subject.search(S, 'species', 'Caenorhabdiits elegans'), ...
                'ndi:subject:search:noSuchValue');
            % the message, whole: as an error (evalc wraps it at the console width)
            b = warning('error', 'ndi:subject:search:noSuchValue'); %#ok<CTPCT>
            restore = onCleanup(@() warning(b));
            msg = '';
            try
                ndi.subject.search(S, 'species', 'Caenorhabdiits elegans');
            catch err
                msg = err.message;
            end
            clear restore
            testCase.verifySubstring(msg, 'Did you mean ''Caenorhabditis elegans''?');
            testCase.verifySubstring(msg, 'Species in this session: ');
            % strict false: nothing, quietly
            testCase.verifyEmpty(testCase.verifyWarningFree(@() ...
                ndi.subject.search(S, 'stran', 'N2', 'strict', false)));
            testCase.verifyEmpty(testCase.verifyWarningFree(@() ...
                ndi.subject.search(S, 'species', 'Caenorhabdiits elegans', 'strict', false)));
            testCase.verifyEmpty(testCase.verifyWarningFree(@() ...
                ndi.subject.search(S, 'type', 'organism', 'contained_in', {'stran', 'N2'}, 'strict', false)), ...
                'a nested description is strict as the outer search is');
            testCase.verifyEqual(ndi.v2.closest('stran', {'strain', 'species'}), 'strain');
            testCase.verifyEqual(ndi.v2.closest('zzz', {'strain', 'species'}), '');
        end

        function testCalculationValueFromItsBody(testCase)
            w = testCase.subject('concentration_worm0121');
            sp = w.statements('Class', 'velocity_calculation');
            testCase.verifyNumElements(sp, 1);
            testCase.verifyClass(sp{1}, 'ndi.calculation');
            testCase.verifyTrue(isa(sp{1}, 'ndi.interaction'));
            v = sp{1}.value();
            testCase.verifyClass(v, 'ndi.value');
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

            moves = ndi.statement.search(testCase.Session, 'Variable', 'location', 'Method', 'agar plug transfer');
            testCase.verifyNotEmpty(moves);
            testCase.verifyTrue(all(cellfun(@(s) isa(s, 'ndi.manipulation'), moves)));
            P = moves{1}.method_parameters();
            testCase.verifyTrue(any(P.variable == "cleaning step"));
        end

        function testANestedEdgeTargetReachesDid2(testCase)
            % a depends_on whose target is a query (and one inside an or)
            % is converted for did2 as a query, not dropped or stringified.
            % Searching with it needs DID-matlab #218; the search itself is
            % tested there (testSqliteDb/testSearchDependsOnAQueryOrAList).
            D = 'ndi.database.implementations.database.did2sqlite';
            inner = ndi.query('chemical.value.substance.name', 'exact_string', 'peptone', '');
            q = ndi.query('', 'isa', 'formulation', '') & ndi.query('', 'depends_on', 'ingredient_id', inner);
            q2 = feval([D '.toDid2Query'], q);
            ss = q2.searchstructure;
            k = find(strcmp({ss.operation}, 'depends_on'));
            testCase.assertNumElements(k, 1);
            testCase.verifyClass(ss(k).param2, 'did2.query');
            testCase.verifyEqual(ss(k).param2.searchstructure.field, 'chemical.value.substance.name');
            testCase.verifyEqual(ss(k).param2.searchstructure.param1, 'peptone');

            o = feval([D '.toDid2Query'], ndi.query('', 'depends_on', 'ingredient_id', inner) | ...
                ndi.query('base.name', 'exact_string', 'x', ''));
            testCase.verifyEqual(o.searchstructure.operation, 'or');
            testCase.verifyClass(o.searchstructure.param1(1).param2, 'did2.query', 'inside an or');
        end

        function testDatasetLevelDocumentsAreReachedThroughTheDataset(testCase)
            % software, formulations, strains and people are stored with the
            % dataset (decision #20): read through the dataset, a statement
            % reaches them; read through a session, it does not
            local = 'concentration_worm0121';
            ws = ndi.subject.search(testCase.Session, 'LocalIdentifier', local);
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
            x = ndi.subject.search(testCase.Session, 'LocalIdentifier', local);
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
