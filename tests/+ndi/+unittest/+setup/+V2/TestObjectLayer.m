classdef TestObjectLayer < matlab.unittest.TestCase
%TESTOBJECTLAYER The V2 object layer (ndi.entity, ndi.statement and its
%children, ndi.value) over a written Haley session.
%
%   Writes TestHaleyRecordings' synthetic concentration_0001 with its
%   assertions, manipulations and calculations, opens it with
%   ndi.session.dir, and asks the questions through the objects that
%   TestHaleyWrite answers by reading documents. ndi.subject is v1's and
%   is not used: every entity, a worm included, is an ndi.entity.

    properties
        Root
        Session
        Dataset
        Result
        % the session as it reaches the dataset-level documents: the Session
        % itself, or, with one entity class, the session opened from its
        % dataset, where the strain entities and their species are (#112)
        Reach
    end

    methods (TestClassSetup)
        function fixture(testCase)
            testCase.assumeTrue(~isempty(which('did2.build.document')), ...
                'did2.build (DID-matlab V2) is not on the path');
            schemaPath = getenv('DID_SCHEMA_PATH');
            testCase.assumeTrue(~isempty(schemaPath) && ...
                isfile(fullfile(schemaPath, 'entity.json')), ...
                'DID_SCHEMA_PATH does not hold a V2 schema with `entity` (did-schema #88)');
            testCase.Root = tempname;
            testCase.addTeardown(@() rmdir(testCase.Root, 's'));
            ndi.unittest.setup.V2.TestHaleyRecordings.writeFixture(testCase.Root);
            testCase.Result = ndi.setup.conv.haley.import_V2(testCase.Root, ...
                'Stages', ["sessions", "subjects", "acquisition", "relations", "metadata", ...
                "assertions", "manipulations", "observations", "calculations", "dataset"], ...
                'Sessions', "concentration_0001", ...
                'OutputRoot', fullfile(testCase.Root, 'haley_V2'), 'Write', true, ...
                'Overwrite', true, 'ReadVideos', false, 'SessionFolders', true);
            testCase.Session = ndi.session.dir(testCase.Result.sessions.path{1});
            testCase.Dataset = ndi.dataset.dir(testCase.Result.dataset.path);
            testCase.Reach = testCase.Session;
            [refs, ids] = testCase.Dataset.session_list();
            testCase.Reach = testCase.Dataset.open_session( ...
                ids{strcmp(refs, testCase.Session.reference)});
        end
    end

    methods (Test)
        function testSubjectIsAnEntity(testCase)
            w = testCase.subject('concentration_worm0121');
            testCase.verifyClass(w, 'ndi.entity');
            testCase.verifyEqual(w.kind, 'subject');
            p = w.document_properties();
            testCase.verifyEqual(w.name, char(ndi.v2.blockOf(p, 'subject', 'name')), 'a subject''s display name is its own name');
            testCase.verifyEqual(w.name(), 'Worm 0121');
            testCase.verifyEqual(w.local_identifier, 'concentration_worm0121', ...
                'no @ is required of a V2 subject read from a document (D6)');
            testCase.verifyEqual(w.type, 'organism');
            g = ndi.entity.search(testCase.Session, {'Type', 'group'});
            testCase.verifyNumElements(g, 4, 'one cohort per assay plate');
            e = ndi.entity.fromDocument(testCase.Session, w.document_id);
            testCase.verifyClass(e, 'ndi.entity');
            testCase.verifyEqual(e.document_id, w.document_id);
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
            % an entity with no document: all four are empty
            s = ndi.entity();
            testCase.verifyEqual({s.name, s.type, s.kind, s.document_id}, {'', '', '', ''});
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

            % a patch is contained_in its plate (decision #107), not part_of it
            p = testCase.subject('concentration_assayPlate0012_patch0001');
            testCase.verifyEmpty(p.partOf());
            w = p.parents('contained_in');
            testCase.verifyNumElements(w, 1);
            testCase.verifyEqual(w{1}.local_identifier, 'concentration_assayPlate0012');
            inside = cellfun(@(x) x.local_identifier, w{1}.children('contained_in'), 'UniformOutput', false);
            testCase.verifyTrue(ismember('concentration_assayPlate0012_patch0001', inside), strjoin(inside, ', '));
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
            testCase.verifyGreaterThanOrEqual(sum(T.relation == "contained_in" & T.direction == "in" & ...
                T.start_id == a.document_id), 2, 'its cohort and its patch contained_in it (decision #107)');
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

            testCase.verifyEmpty(w.ancestors('Type', 'material', 'Kind', 'subject'), ...
                'Type and Kind together: a plate is not a subject (isa subject is the biological types)');
            testCase.verifyEmpty(w.ancestors('Type', 'material', 'Kind', 'person'));

            inside = local(a.descendants('Relation', 'contained_in'));
            parts = inside(startsWith(inside, 'concentration_assayPlate0012_patch'));
            testCase.verifyNotEmpty(parts, 'its patches are contained_in it (decision #107)');
            testCase.verifyTrue(ismember('concentration_assayPlate0012_worms', inside), strjoin(inside, ', '));
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
            p = strainProp();     % the strain's property name on the schema in use
            typo = strrep(p, 'strain', 'stran');
            % one entity class (2026-10-08): a cohort is an instance_of the
            % dataset-level strain entity, so p, 'N2' needs that
            % entity in reach. A session opened from its dataset reaches it
            % (ndi.session/database_search_with_dataset); a session folder
            % opened on its own holds only the relation and cannot name it.
            testCase.verifyError(@() ndi.entity.search(S, {p, 'N2'}), ...
                'ndi:entity:search:unknownVariable');
            [refs, ids] = testCase.Dataset.session_list();
            inDataset = testCase.Dataset.open_session(ids{strcmp(refs, S.reference)});
            testCase.verifyTrue(all(ismember({'concentration_worm0121', 'concentration_worm0122'}, ...
                local(ndi.entity.search(inDataset, {'type', 'organism', p, 'N2'})))), ...
                'a session opened from its dataset finds the strain entity there');
            S = testCase.Dataset;
            w = ndi.entity.search(S, {'type', 'organism', 'species', 'Caenorhabditis elegans', p, 'N2'});
            names = local(w);
            testCase.verifyTrue(all(ismember({'concentration_worm0121', 'concentration_worm0122'}, names)), ...
                strjoin(names, ', '));
            testCase.verifyTrue(all(cellfun(@(x) strcmp(x.type, 'organism'), w)));
            testCase.verifyTrue(ismember('concentration_assayPlate0012_worms', ...
                local(ndi.entity.search(S, {p, 'N2'}))), 'the cohort it was stated on matches too');

            % property names and value names ignore case; nodes are exact
            same = @(varargin) isequal(sort(local(ndi.entity.search(S, varargin))), sort(names));
            testCase.verifyTrue(same('Type', 'Organism', upper(p), 'n2'));
            testCase.verifyTrue(same('type', 'organism', 'species', 'NCBITaxon:6239', p, 'N2'));
            % a node's prefix is read by key, spelling or synonym, ignoring case
            % (did-schema V_eta_prefix_spelling_plan.md, signed 2026-10-19)
            testCase.verifyTrue(same('type', 'organism', 'species', 'ncbitaxon:6239', p, 'N2'), ...
                'a node prefix ignores case');
            if isKey(ndi.v2.curiePrefixes().names, 'ncbit')
                testCase.verifyTrue(same('type', 'organism', 'species', 'NCBIT:6239', p, 'N2'), ...
                    'a node prefix is read by synonym');
            end
            testCase.verifyTrue(same('type', 'organism', p, {'N2', 'no such strain'}), 'a cell is any of');
            testCase.verifyTrue(same('type', 'organism', p, 'N*'), 'a wildcard');
            testCase.verifyTrue(same('type', 'organism', 'species', '*ELEGANS', p, 'N2'), ...
                'a wildcard on a name ignores case');
            testCase.verifyTrue(same('type', 'organism', 'species', 'NCBITaxon:*', p, 'N2'), ...
                'a wildcard on a node');

            % inherited false: only what was stated on the subject itself
            testCase.verifyEmpty(ndi.entity.search(S, {'type', 'organism', p, 'N2'}, 'inherited', false), ...
                'strain is stated on no worm itself');
            testCase.verifyEqual(sort(local(ndi.entity.search(S, {p, 'N2'}, 'inherited', false))), ...
                sort(local(ndi.entity.search(S, {p, 'N2', 'type', 'group'}))), 'the cohorts alone');

            ecoli = ndi.entity.search(S, {'species', 'NCBITaxon:562'});
            testCase.verifyNotEmpty(ecoli);
            testCase.verifyFalse(any(cellfun(@(x) strcmp(x.type, 'organism'), ecoli)), 'lawns, not worms');
            testCase.verifyEqual(local(ndi.entity.search(S, {p, 'N2', ...
                'local_identifier', 'concentration_worm0121'})), {'concentration_worm0121'});
            testCase.verifyEqual(local(ndi.entity.search(S, {'LocalIdentifier', 'concentration_worm0121'})), ...
                {'concentration_worm0121'}, 'the old spelling still works');

            % a misspelled variable is an error; a value no one has, a warning
            testCase.verifyError(@() ndi.entity.search(S, {typo, 'N2'}), 'ndi:entity:search:unknownVariable');
            testCase.verifyWarning(@() ndi.entity.search(S, {'species', 'Caenorhabdiits elegans'}), ...
                'ndi:entity:search:noSuchValue');
            testCase.verifyEmpty(testCase.verifyWarning(@() ndi.entity.search(S, {p, 'no such strain'}), ...
                'ndi:entity:search:noSuchValue'));
            % the conditions are one cell of pairs; the switches are options after it
            testCase.verifyError(@() ndi.entity.search(S, {p}), 'ndi:entity:search:pairs');
            testCase.verifyError(@() ndi.entity.search(S, {p, 'N2', 'inherited', false}), ...
                'ndi:entity:search:option');
            testCase.verifyError(@() ndi.entity.search(S, {p, 'N2'}, 'inheritd', false), ...
                ?MException, 'a misspelt option is caught by the arguments block');
        end

        function testSynonymsFindATermByAnotherName(testCase)
            % a value that matches no term by its name or node matches a term
            % it is a synonym of (ndi.v2.synonyms); the names are read from
            % the on-disk cache, prepared here so no lookup goes online
            S = testCase.Reach;     % where the species is stated (#112)
            folder = tempname;
            mkdir(folder);
            testCase.addTeardown(@() rmdir(folder, 's'));
            old = getenv('NDI_SYNONYM_CACHE');
            setenv('NDI_SYNONYM_CACHE', folder);
            testCase.addTeardown(@() setenv('NDI_SYNONYM_CACHE', old));
            fid = fopen(fullfile(folder, 'ncbitaxon_6239.json'), 'w');
            fwrite(fid, jsonencode(struct('node', 'NCBITaxon:6239', 'names', ...
                {{'Caenorhabditis elegans', 'C. elegans', 'nematode worm'}})), 'char');
            fclose(fid);
            testCase.verifyEqual(ndi.v2.synonyms('ncbitaxon:6239'), ...
                {'Caenorhabditis elegans', 'C. elegans', 'nematode worm'}, 'read from the cache, any case');
            worms = {'concentration_worm0121', 'concentration_worm0122'};
            w = local(ndi.entity.search(S, {'type', 'organism', 'species', 'C. elegans'}));
            testCase.verifyTrue(all(ismember(worms, w)), strjoin(w, ', '));
            w = local(ndi.entity.search(S, {'type', 'organism', 'species', 'nematode*'}));
            testCase.verifyTrue(all(ismember(worms, w)), 'a wildcard over the synonyms');
            testCase.verifyEmpty(testCase.verifyWarning(@() ndi.entity.search(S, ...
                {'type', 'organism', 'species', 'C. elegans'}, 'synonyms', false), ...
                'ndi:entity:search:noSuchValue'), 'synonyms off: the name only');
            a = testCase.subject('concentration_assayPlate0012_worms', S).assertions( ...
                {'variable', 'species', 'value', 'C. elegans'});
            testCase.verifyNotEmpty(a, 'statement filters use them too');
            testCase.verifyEmpty(ndi.v2.synonyms('not a curie'));
        end

        function testFindByAStatementOfAKind(testCase)
            % the six statement keys: the filters in one cell are one
            % statement; a key given twice is two statements
            S = testCase.Session;
            plate = 'concentration_assayPlate0012';
            has = @(varargin) ismember(plate, local(ndi.entity.search(S, varargin)));
            testCase.verifyTrue(has('manipulation', {'variable', 'nematode growth medium'}));
            testCase.verifyTrue(has('manipulation', {'method', 'refrigeration'}));
            testCase.verifyTrue(has('interaction', {'method', 'refrigeration'}), 'an interaction is any of the three');
            testCase.verifyTrue(has('statement', {'variable', 'nematode growth medium'}));
            testCase.verifyTrue(has('manipulation', {'method', 'REFRIG*'}), 'a wildcard, any case');
            % a dose compares by its amount, in its canonical unit (liters)
            testCase.verifyTrue(has('manipulation', {'variable', 'nematode growth medium', 'value', '>=0.02'}));
            testCase.verifyTrue(has('manipulation', {'variable', 'nematode growth medium', 'value', '<=0.025'}));
            w = warning('off', 'ndi:entity:search:noSuchValue');
            restore = onCleanup(@() warning(w));
            testCase.verifyFalse(has('manipulation', {'variable', 'nematode growth medium', 'value', '>0.03'}));
            % one statement that is both, versus two statements
            testCase.verifyEmpty(ndi.entity.search(S, {'manipulation', {'method', 'refrigeration', ...
                'variable', 'nematode growth medium'}}), 'no single manipulation is both: none, not an error');
            testCase.verifyTrue(has('manipulation', {'method', 'refrigeration'}, ...
                'manipulation', {'variable', 'nematode growth medium'}));
            % the shorthand is an assertion (with one entity class a strain is
            % a relation, not an assertion: testFindByWhatIsTrueOfASubject)
            testCase.verifyError(@() ndi.entity.search(S, {'assertion', {'method', 'x'}}), ...
                'ndi:entity:search:assertionMethod');
            testCase.verifyError(@() ndi.entity.search(S, {'manipulation', {'method', 'no such method'}}), ...
                'ndi:entity:search:noSuchStatement');
            testCase.verifyError(@() ndi.entity.search(S, {'manipulation', {'colour', 'x'}}), ...
                'ndi:entity:search:statementFilter');
            testCase.verifyError(@() ndi.entity.search(S, {'manipulation', 'nematode growth medium'}), ...
                'ndi:entity:search:statementFilter');
            % a plate's statements are not its worms': contained_in is not followed
            testCase.verifyEmpty(ndi.entity.search(S, {'type', 'organism', 'manipulation', {'variable', 'nematode growth medium'}}));
        end

        function testFindByRelation(testCase)
            S = testCase.Session;
            worms = {'concentration_worm0121', 'concentration_worm0122'};
            cohort = testCase.subject('concentration_assayPlate0012_worms');
            plate = testCase.subject('concentration_assayPlate0012');
            names = @(varargin) sort(local(ndi.entity.search(S, varargin)));

            % the shortcut: a relation's name, the subject is the child
            testCase.verifyEqual(names('member_of', cohort), worms);
            testCase.verifyEqual(names('directed_relation', {'parent', cohort}), worms, 'no name: any relation');
            testCase.verifyEqual(names('directed_relation', {'name', 'member_of', 'parent', cohort.document_id}), ...
                worms, 'the other end as a document id');
            % the cohort is contained_in the plate, distributive: so is each worm
            testCase.verifyEqual(names('type', 'organism', 'contained_in', plate), worms);
            testCase.verifyEmpty(ndi.entity.search(S, {'type', 'organism', 'contained_in', plate}, 'inherited', false), ...
                'not inherited: no worm is contained_in anything itself');
            % the other end described, not named
            onNGM = names('type', 'organism', 'contained_in', {'manipulation', {'variable', 'nematode growth medium'}});
            testCase.verifyTrue(all(ismember(worms, onNGM)), strjoin(onNGM, ', '));
            % the reverse: the subject is the parent
            p = names('directed_relation', {'name', 'contained_in', 'child', ...
                {'local_identifier', 'concentration_assayPlate0012_patch0001'}});
            testCase.verifyEqual(p, {'concentration_assayPlate0012'});
            % nested: worms on the plate that patch 0001 is in
            testCase.verifyEqual(names('type', 'organism', 'contained_in', {'directed_relation', ...
                {'name', 'contained_in', 'child', {'local_identifier', 'concentration_assayPlate0012_patch0001'}}}), worms);
            % 'with': either end
            w = names('relation', {'with', cohort});
            testCase.verifyTrue(all(ismember([worms, {'concentration_assayPlate0012', ...
                'concentration_0001_acclimationPlate0001'}], w)), strjoin(w, ', '));
            testCase.verifyEqual(local(ndi.entity.search(S, {'id', cohort.document_id})), ...
                {'concentration_assayPlate0012_worms'});

            % explain says what it will do
            out = evalc('ndi.entity.search(S, {''type'', ''organism'', ''contained_in'', {''manipulation'', {''variable'', ''nematode growth medium''}}}, ''explain'', true);');
            testCase.verifySubstring(out, 'contained_in');
            testCase.verifySubstring(out, 'nematode growth medium');
            testCase.verifySubstring(out, 'Searching this session for organisms that', ...
                'the search names what it is for');
            testCase.verifySubstring(out, 'are contained_in an entity');
            testCase.verifySubstring(out, 'had a manipulation with variable nematode growth medium');
            % the noun follows a single kind or type condition; several types are listed
            out = evalc('ndi.entity.search(S, {''kind'', ''person''}, ''explain'', true);');
            testCase.verifySubstring(out, 'Searching this session for all people');
            R = testCase.Reach;     %#ok<NASGU> where the species is stated (#112)
            out = evalc('ndi.entity.search(R, {''type'', ndi.v2.subjectTypes(), ''species'', ''Caenorhabditis elegans''}, ''explain'', true);');
            testCase.verifySubstring(out, ...
                'Searching this session for organisms, cultures, tissues, cells or groups that', ...
                'several types are listed');
            out = evalc('ndi.entity.search(R, {''species'', ''Caenorhabditis elegans''}, ''explain'', true);');
            testCase.verifySubstring(out, 'Searching this session for entities that');
            out = evalc(['ndi.entity.search(S, {''type'', ''organism'', ''contained_in'', ' ...
                '{''type'', ''material''}}, ''explain'', true);']);
            testCase.verifySubstring(out, 'are contained_in a material');

            testCase.verifyError(@() ndi.entity.search(S, {'directed_relation', {'name', 'containd_in'}}), ...
                'ndi:entity:search:unknownRelation');
            testCase.verifyError(@() ndi.entity.search(S, {'contained_in', plate, 'directed_relation', ...
                {'name', 'contained_in', 'parent', plate, 'depth', 2}}), 'ndi:entity:search:notYet');
            testCase.verifyError(@() ndi.entity.search(S, {'undirected_relation', {'parent', plate}}), ...
                'ndi:entity:search:relationFilter');
            testCase.verifyError(@() ndi.entity.search(S, {'directed_relation', {'parent', plate, 'child', plate}}), ...
                'ndi:entity:search:relationFilter');
        end

        function testAnAssertionAboutAContainerStaysOnIt(testCase)
            % plate 0013 is excluded (an assertion on the plate). Its patches
            % and its worms are contained_in it (decision #107), and
            % contained_in carries no assertion (tenet T17), so neither is
            S = testCase.Session;
            direct = local(ndi.entity.search(S, {'inclusion in analysis', false}, 'inherited', false));
            testCase.verifyTrue(ismember('concentration_assayPlate0013', direct));
            all_ = local(ndi.entity.search(S, {'inclusion in analysis', false}));
            testCase.verifyEqual(sort(all_), sort(direct), 'nothing inherits the plate''s exclusion');
            patches = local(ndi.entity.search(S, {'directed_relation', {'name', 'contained_in', 'parent', ...
                {'local_identifier', 'concentration_assayPlate0013'}}}));
            patches = patches(startsWith(patches, 'concentration_assayPlate0013_patch'));
            testCase.verifyNotEmpty(patches, 'its patches are contained_in it');
            testCase.verifyEmpty(intersect(patches, all_), 'and are not excluded');
            testCase.verifyEmpty(ndi.entity.search(S, {'type', 'organism', 'inclusion in analysis', false}), ...
                'contained_in does not carry statements');
        end

        function testAnAnalysisAsksTheContainersInOneCall(testCase)
            % V_eta tenet T17 (did-schema dc66d35): an assertion about a
            % container stays on the container -- a plate's `inclusion in
            % analysis` false is not its worms' -- so an analysis asks the
            % containers: ndi.statement.search's 'NotContainerAssertion' drops
            % the statements whose subject was, while they held, on a plate
            % so described (through its cohort's distributive stay), and
            % 'ContainerAssertion' keeps only those. Plate 0013, the fixture's
            % excluded plate, was never filmed, so nothing timed is on it; the
            % test excludes plate 0012 too, in a copy of the session.
            folder = fullfile(testCase.Root, ['containers_' char(ndi.ido.unique_id())]);
            copyfile(testCase.Session.getpath(), folder);
            sid = testCase.Session.id();
            plate = testCase.subject('concentration_assayPlate0012').document_id;
            worm = testCase.subject('concentration_worm0121').document_id;
            % the import's own exclusion of plate 0013, restated of 0012
            ex = testCase.Session.database_search(ndi.v2.isaQuery('logical_assertion'));
            ex = ex(cellfun(@(d) strcmp(ndi.v2.termName(ndi.v2.blockOf( ...
                d.document_properties, 'statement', 'variable', '')), ...
                'inclusion in analysis'), ex));
            testCase.assertNotEmpty(ex, 'the import excludes plate 0013');
            variable = ndi.v2.blockOf(ex{1}.document_properties, 'statement', 'variable');
            doc = did2.build.statement('logical_assertion', plate, variable, false, ...
                'SessionId', sid);
            desc = {'inclusion in analysis', false};
            % written into the copy's database file, then the copy is opened
            db = did2.database.sqlitedb(fullfile(folder, '.ndi', ...
                ndi.database.implementations.database.did2sqlite.DEFAULTFILENAME()));
            db.add({did2.document(doc)});
            db.close();
            S = ndi.session.dir(folder);
            testCase.verifyEqual(S.id(), sid);

            all_ = ndi.statement.search(S, 'Class', 'calculation', 'Subject', worm);
            testCase.assertNotEmpty(all_, 'worm 0121 has calculations (stage 10)');
            [kept, info] = ndi.statement.search(S, 'Class', 'calculation', 'Subject', worm, ...
                'NotContainerAssertion', desc);
            testCase.verifyEqual(info.read, numel(all_), 'the denominator: every statement read');
            testCase.verifyGreaterThanOrEqual(info.containers, 1, 'plate 0012 matches');
            testCase.verifyEqual(info.kept + info.dropped, info.read);
            testCase.verifyGreaterThan(info.dropped, 0, ...
                'the worm''s statements made while its cohort was on plate 0012 are dropped');
            [inside, info2] = ndi.statement.search(S, 'Class', 'calculation', 'Subject', worm, ...
                'ContainerAssertion', desc);
            testCase.verifyEqual(info2.kept, info.dropped);
            testCase.verifyEqual(sort([sids(kept), sids(inside)]), sort(sids(all_)), ...
                'the two forms split the statements between them');
            % the exclusion itself is still the plate's, not the worm's
            w = ndi.entity.fromDocument(S, worm);
            testCase.verifyEmpty(w.assertions({'variable', desc{1}}, 'synonyms', false));
            testCase.verifyError(@() ndi.statement.search(S, 'ContainerAssertion', desc, ...
                'NotContainerAssertion', desc), 'ndi:statement:search:twoContainerFilters');

            % a worm on a plate that is not excluded keeps everything
            other = ndi.entity.search(S, {'LocalIdentifier', 'concentration_worm0111'});
            if ~isempty(other)
                o = other{1}.document_id;
                n = numel(ndi.statement.search(S, 'Class', 'calculation', 'Subject', o));
                [k, i3] = ndi.statement.search(S, 'Class', 'calculation', 'Subject', o, ...
                    'NotContainerAssertion', desc);
                testCase.verifyNumElements(k, n);
                testCase.verifyEqual(i3.dropped, 0);
            end
        end

        function testContextIsWhatTheSubjectWasIn(testCase)
            % V_eta tenet T17: a container's interactions reach what it
            % contained only with 'context', true, only while it was in it,
            % and marked as reached through contained_in. Assertions never.
            S = testCase.Session;
            w = testCase.subject('concentration_worm0121');
            c = testCase.subject('concentration_assayPlate0012_worms');
            plates = cellfun(@(x) x.document_id, c.parents('contained_in'), 'UniformOutput', false);
            testCase.assertNotEmpty(plates, 'the cohort was on plates');
            isCtx = @(x) endsWith(x.via(), 'contained_in');

            % off by default: nothing about the worm comes from its plates
            testCase.verifyFalse(any(cellfun(isCtx, w.statements())));
            testCase.verifyEmpty(w.manipulations({'variable', 'Environmental Temperature'}));

            m = w.manipulations('context', true);
            ctx = m(cellfun(isCtx, m));
            testCase.verifyNotEmpty(ctx, 'its plates'' manipulations while it was on them');
            testCase.verifyTrue(all(cellfun(@(x) ismember(x.subject().document_id, plates), ctx)), ...
                'only the plates it was on; stated_on is the plate');
            testCase.verifyTrue(all(cellfun(@(x) strcmp(x.via(), 'member_of > contained_in'), ctx)), ...
                'through its cohort''s distributive stay');
            vars = cellfun(@(x) x.variable_name(), ctx, 'UniformOutput', false);
            methods_ = cellfun(@(x) char(x.method_name()), ctx, 'UniformOutput', false);
            testCase.verifyTrue(any(strcmp(vars, 'Environmental Temperature')), ...
                'the bench and the incubator, while it was there');
            testCase.verifyFalse(any(strcmp(vars, 'nematode growth medium')), ...
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
            testCase.verifyEmpty(ndi.entity.search(S, {'type', 'organism', ...
                'inclusion in analysis', false}, 'context', true));

            % search: a plate's room-temperature period finds the worms on it then
            found = local(ndi.entity.search(S, {'type', 'organism', ...
                'manipulation', {'method', 'ambient exposure'}}, 'context', true));
            testCase.verifyTrue(ismember('concentration_worm0121', found));
            testCase.verifyEmpty(ndi.entity.search(S, {'type', 'organism', ...
                'manipulation', {'method', 'ambient exposure'}}), 'not without context');
            testCase.verifyEmpty(ndi.entity.search(S, {'type', 'organism', ...
                'manipulation', {'method', 'refrigeration'}}, 'context', true), ...
                'every cold room was before the worms arrived');
            out = evalc(['ndi.entity.search(S, {''type'', ''organism'', ''manipulation'', ' ...
                '{''method'', ''ambient exposure''}}, ''context'', true, ''explain'', true);']);
            testCase.verifySubstring(out, 'contained in something that did while they were in it');

            % a patch is contained_in its plate from the seeding (decision
            % #107): the plate's cold room after seeding reaches it as context
            p = testCase.subject('concentration_assayPlate0012_patch0001');
            testCase.verifyEmpty(p.manipulations({'method', 'refrigeration'}), 'not without context');
            cold = p.manipulations({'method', 'refrigeration'}, 'context', true);
            testCase.verifyNotEmpty(cold, 'the plate''s cold room, while the patch was on it');
            testCase.verifyTrue(all(cellfun(@(x) strcmp(x.subject().local_identifier, ...
                'concentration_assayPlate0012'), cold)), 'stated on the plate');
        end

        function testDuringAnotherStatement(testCase)
            % 'during' takes a description of statements as well as times:
            % kept when it overlaps one matching it that holds of the same
            % subject, by the same rules ('inherited', 'context'). The
            % fixture's plates read 21.5 + plate/100 C over their videos, so
            % '>21.615' is plates 12 and 14 (21.62, 21.64), not plate 11 (21.61).
            S = testCase.Session;
            plate = testCase.subject('concentration_assayPlate0012');
            hot = {'observation', {'variable', 'Environmental Temperature', 'value', '>21.615'}};
            cold = {'observation', {'variable', 'Environmental Temperature', 'value', '>30'}};
            v = plate.observations({'variable', 'Imaging Signal Intensity'});
            testCase.assertNotEmpty(v, 'plate 12 was filmed');
            during = plate.observations({'variable', 'Imaging Signal Intensity', 'during', hot});
            testCase.verifyNotEmpty(during, 'plate 12''s reading is timed by one of its videos');
            testCase.verifyLessThanOrEqual(numel(during), numel(v));
            testCase.verifyEmpty(plate.observations({'variable', 'Imaging Signal Intensity', 'during', cold}));
            other = testCase.subject('concentration_assayPlate0011');
            testCase.verifyEmpty(other.observations({'variable', 'Imaging Signal Intensity', 'during', hot}), ...
                'plate 11 read 21.61 C; plate 12''s reading is not plate 11''s');

            % a worm: its plate's videos, while that plate was over 21.615 C
            w = testCase.subject('concentration_worm0121');
            testCase.verifyEmpty(w.observations({'variable', 'Imaging Signal Intensity', 'during', hot}), ...
                'without context the worm has neither the videos nor the reading');
            o = w.observations({'variable', 'Imaging Signal Intensity', 'during', hot}, 'context', true);
            testCase.verifyNotEmpty(o);
            testCase.verifyTrue(all(cellfun(@(x) strcmp(x.subject().local_identifier, ...
                'concentration_assayPlate0012'), o)));
            t = w.observations({'variable', 'Environmental Temperature'}, 'context', true);
            testCase.verifyNumElements(t, 1, 'the one reading of the plate it was filmed on');
            testCase.verifyEqual(double(t{1}.value()), 21.62, 'AbsTol', 1e-9);

            % search: worms filmed while their plate was over 21.615 C
            found = local(ndi.entity.search(S, {'type', 'organism', ...
                'observation', {'variable', 'Imaging Signal Intensity', 'during', hot}}, 'context', true));
            testCase.verifyTrue(ismember('concentration_worm0121', found));
            warm = local(ndi.entity.search(S, {'type', 'organism', 'contained_in', ...
                {'local_identifier', {'concentration_assayPlate0012', 'concentration_assayPlate0014'}}}));
            testCase.verifyEmpty(setdiff(found, warm), 'only the worms on plates 12 and 14');
            cool = local(ndi.entity.search(S, {'type', 'organism', 'contained_in', other}));
            testCase.verifyEmpty(intersect(found, cool), 'none of the worms on plate 11');
            testCase.verifyEmpty(ndi.entity.search(S, {'type', 'organism', ...
                'observation', {'variable', 'Imaging Signal Intensity', 'during', cold}}, 'context', true));
            out = evalc(['ndi.entity.search(S, {''type'', ''organism'', ' ...
                '''observation'', {''variable'', ''Imaging Signal Intensity'', ''during'', hot}}, ''context'', true, ''explain'', true);']);
            testCase.verifySubstring(out, 'at a time when they also had an observation with variable Environmental Temperature');
            testCase.verifyError(@() plate.observations({'during', {'assertion', {'variable', 'strain'}}}), ...
                'ndi:entity:search:assertionTime');
        end

        function testTimeFilters(testCase)
            % the fixture's windows (TestHaleyWrite pins them), Los Angeles:
            % cohort 0012 on acclimation plate 0001 from 2022-02-03 12:10:51 to
            % 2022-02-04 12:10:51; cohort 0014 food-deprived for exactly 3 h,
            % 2022-02-04 12:17:10 to 15:17:10 (the end, T, up to 5 min early)
            S = testCase.Session;
            w = warning('off', 'ndi:entity:search:noSuchTime');
            restore = onCleanup(@() warning(w));
            acc = testCase.subject('concentration_0001_acclimationPlate0001');
            on = @(varargin) local(ndi.entity.search(S, {'type', 'organism', 'directed_relation', ...
                [{'name', 'contained_in', 'parent', acc}, varargin]}));
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
            fd = local(ndi.entity.search(S, {'member_of', testCase.subject('concentration_assayPlate0014_worms')}));
            testCase.assertNotEmpty(fd);
            deprived = @(varargin) local(ndi.entity.search(S, {'type', 'organism', 'manipulation', ...
                [{'variable', 'food availability'}, varargin{1}]}, varargin{2:end}));
            testCase.verifyEqual(sort(deprived({'duration', '>=3h'})), sort(fd));
            testCase.verifyEqual(sort(deprived({'duration', '>=180min'})), sort(fd));
            testCase.verifyEmpty(deprived({'duration', '>3h'}), 'exactly 3 h as stated');
            testCase.verifyEqual(sort(deprived({'duration', '>3h'}, 'tolerant', true)), sort(fd), ...
                'the hand-written start could be a minute early');
            warning('on', 'ndi:entity:search:noSuchTime');
            testCase.verifyWarning(@() ndi.entity.search(S, {'manipulation', ...
                {'variable', 'food availability', 'duration', '>4h'}}), 'ndi:entity:search:noSuchTime');
            warning('off', 'ndi:entity:search:noSuchTime');

            % a time known only as "before the seeding" (a plate's pour) is a bound
            plate = 'concentration_assayPlate0012';
            poured = @(varargin) local(ndi.entity.search(S, {'manipulation', [{'variable', 'nematode growth medium'}, varargin]}));
            testCase.verifyTrue(ismember(plate, poured('before', '2030-01-01')), 'the bound decides it');
            testCase.verifyFalse(ismember(plate, poured('at', '2022-02-04T12:00')), 'a bound cannot place it');

            out = evalc(['ndi.entity.search(S, {''type'', ''organism'', ''manipulation'', ' ...
                '{''variable'', ''food availability'', ''duration'', ''>=3h''}}, ''explain'', true);']);
            testCase.verifySubstring(out, 'lasting >=3h');
            testCase.verifyError(@() ndi.entity.search(S, {'directed_relation', ...
                {'name', 'contained_in', 'at', 'sometime after lunch'}}), 'ndi:v2:timeFilter:badTime');
            testCase.verifyError(@() ndi.entity.search(S, {'manipulation', ...
                {'variable', 'food availability', 'duration', '3 fortnights'}}), 'ndi:v2:timeFilter:badDuration');
        end

        function testAssertions(testCase)
            c = testCase.subject('concentration_assayPlate0012_worms', testCase.Reach);
            a = c.assertions();
            testCase.verifyTrue(all(cellfun(@(x) isa(x, 'ndi.assertion'), a)), 'objects, not a table');
            T = ndi.summary(a);
            testCase.verifyEqual(lower(T.value_node(lower(T.variable) == "species")), "ncbitaxon:6239");
            % one entity class: the strain is an instance_of relation
            testCase.verifyEmpty(c.assertions({'variable', 'strain'}));
            x = testCase.subject('concentration_assayPlate0013').assertions({'variable', 'inclusion in analysis'});
            testCase.verifyNumElements(x, 1);
            testCase.verifyEqual(x{1}.value().canonical(), false);
        end

        function testInheritedFollowsMemberOfAndDistributive(testCase)
            % decision #55: species and strain are stated once, on the
            % cohort, marked distributive -- they hold of each worm, and are
            % read that way by default. With one entity class the species is
            % stated once more upstream, on the strain the cohort is an
            % instance_of (decision #112), so the worm is read where the
            % strain is in reach
            w = testCase.subject('concentration_worm0121', testCase.Reach);
            own = w.assertions('inherited', false);
            testCase.verifyFalse(any(cellfun(@(x) strcmpi(x.variable_name(), 'species'), own)), ...
                'nothing is stated on the worm itself');
            testCase.verifyTrue(all(cellfun(@(x) strcmp(x.subject().document_id, w.document_id), own)));
            T = w.assertions();
            st = w.statements();
            mine = w.statements('inherited', false);
            testCase.verifyTrue(all(cellfun(@(x) strcmp(x.via(), 'own'), mine)));
            testCase.verifyEqual(sum(cellfun(@(x) strcmp(x.via(), 'own'), st)), numel(mine), ...
                'its own statements are kept');
            sp = T(cellfun(@(x) strcmpi(x.variable_name(), 'species'), T));
            testCase.verifyNumElements(sp, 1);
            testCase.verifyEqual(lower(sp{1}.raw_value().node), 'ncbitaxon:6239');
            % stated on the strain, reached through the cohort
            testCase.verifyEqual(sp{1}.via(), 'member_of > instance_of');
            testCase.verifyEqual(ndi.v2.edgeIds(sp{1}.document_properties(), 'entity_id'), ...
                {testCase.Result.metadata.ids('N2')}, 'stated on the strain');
            strain = T(cellfun(@(x) strcmpi(x.variable_name(), strainProp()), T));
            testCase.verifyEmpty(strain, 'one entity class: a strain is a relation');
            % what the cohort stated (a type's assertions, via
            % instance_of, are testTypesPassTheirAssertionsToInstances')
            extra = st(cellfun(@(x) strcmp(x.via(), 'member_of'), st));
            testCase.verifyNotEmpty(extra);
            testCase.verifyTrue(all(cellfun(@(x) x.distributive(), extra)), 'only distributive ones');
            testCase.verifyTrue(all(cellfun(@(x) strcmp(x.subject().local_identifier, ...
                'concentration_assayPlate0012_worms'), extra)), 'each says where it was stated');
            testCase.verifyTrue(all(cellfun(@(x) strcmp(x.about(), w.document_id), st)), ...
                'each says which subject it was asked for');
            % contained_in is not followed: the plate's temperature is not the worm's
            testCase.verifyEmpty(w.statements('temperature_manipulation'));
            testCase.verifyEmpty(w.statements('manipulation', {'variable', 'Environmental Temperature'}));
        end

        function testSubjectsAreTheBiologicalTypes(testCase)
            % `isa subject` is the organisms, cultures, tissues, cells and
            % groups (ndi.v2.subjectTypes), as a v1 subject always was; a
            % plate (material) or an instrument (device) is an entity, not a
            % subject. 'subject' is not a kind ndi.entity.search takes.
            S = testCase.Session;
            bio = ndi.v2.subjectTypes();
            all_ = ndi.entity.search(S, {'type', '*'});
            types = cellfun(@(x) x.type, all_, 'UniformOutput', false);
            testCase.assertTrue(any(strcmp(types, 'material')), 'the fixture has plates');
            s = ndi.entity.search(S, {'type', bio});
            testCase.verifyEqual(numel(s), sum(ismember(types, bio)));
            docs = S.database_search(ndi.query('', 'isa', 'subject'));
            testCase.verifyEqual(sort(cellfun(@(d) char(d.document_properties.base.id), docs, ...
                'UniformOutput', false)), sort(cellfun(@(x) x.document_id, s, 'UniformOutput', false)), ...
                'isa subject finds the biological types');
            plate = ndi.entity.search(S, {'LocalIdentifier', 'concentration_assayPlate0012'});
            testCase.verifyNumElements(plate, 1, 'a plate is an entity');
            testCase.verifyFalse(ismember(plate{1}.document_id, ...
                cellfun(@(d) char(d.document_properties.base.id), docs, 'UniformOutput', false)), ...
                'and not a subject');
            testCase.verifyError(@() ndi.entity.search(S, {'kind', 'subject'}), 'ndi:entity:search:subjectKind');
        end

        function testGetsubjectsReturnsOnlyBiologicalSubjects(testCase)
            % getsubjects on V2 answers as on v1 (Jess Haley, 2026-10-21):
            % the organisms, cultures, tissues, cells and groups, never a
            % plate (material) or an instrument (device). Session and dataset.
            bio = ndi.v2.subjectTypes();
            idsOf = @(c) sort(cellfun(@(d) char(d.id()), c, 'UniformOutput', false));
            entIds = @(c) sort(cellfun(@(x) char(x.document_id), c, 'UniformOutput', false));
            for holder = {testCase.Session, testCase.Dataset}
                H = holder{1};
                all_ = ndi.entity.search(H, {'type', '*'});
                types = cellfun(@(x) char(x.type), all_, 'UniformOutput', false);
                apparatus = all_(~ismember(types, bio));
                testCase.assertNotEmpty(apparatus, sprintf( ...
                    'the fixture read through a %s has non-biological entities', class(H)));
                got = H.getsubjects();
                testCase.verifyClass(got, 'cell');
                testCase.verifyTrue(all(cellfun(@(d) isa(d, 'ndi.document'), got)), ...
                    'getsubjects returns ndi.document objects, as a database_search does');
                gotIds = idsOf(got);
                bioIds = unique(entIds(ndi.entity.search(H, {'type', bio})));
                testCase.verifyTrue(all(ismember(bioIds, gotIds)), ...
                    sprintf('getsubjects on a %s keeps every biological entity', class(H)));
                untyped = setdiff(gotIds, bioIds);
                % entityDocuments writes the entity's type from 'Type' (the
                % instruments are devices)
                testCase.verifyEmpty(untyped, ...
                    sprintf('getsubjects on a %s is exactly the biological entities', class(H)));
                testCase.verifyNotEmpty(gotIds, 'the worms are subjects');
                testCase.verifyFalse(any(ismember(entIds(apparatus), gotIds)), ...
                    sprintf('getsubjects on a %s leaves out every device and material', class(H)));
            end
            testCase.verifyEqual(idsOf(testCase.Session.getsubjects()), ...
                idsOf(testCase.Session.database_search(ndi.query('', 'isa', 'subject'))), ...
                'on V2, getsubjects is `isa subject` (already the biological types)');
        end

        function testTypesPassTheirAssertionsToInstances(testCase)
            % one entity class (2026-10-08): a cohort is an instance_of its
            % strain, distributive, so each worm is one too; what is
            % asserted of the strain holds of each worm (T17) and the
            % summary names the strain under its type
            [refs, ids] = testCase.Dataset.session_list();
            S = testCase.Dataset.open_session(ids{strcmp(refs, testCase.Session.reference)});
            plate = ndi.entity.search(S, {'LocalIdentifier', 'concentration_assayPlate0012'});
            testCase.assertNumElements(plate, 1);
            ws = ndi.entity.search(S, {'type', 'organism', 'contained_in', plate{1}});
            W = [ws{:}];
            testCase.assertNumElements(W, 2);
            T = ndi.summary(ws);
            testCase.assertTrue(ismember('strain', T.Properties.VariableNames), ...
                strjoin(T.Properties.VariableNames, ', '));
            testCase.verifyEqual(T.strain, ["N2"; "N2"], 'the cohort''s strain, through instance_of');
            a = W(1).assertions();
            via = cellfun(@(x) x.via(), a, 'UniformOutput', false);
            fromType = a(contains(via, 'instance_of'));
            testCase.verifyNotEmpty(fromType, ['the strain''s assertions hold of the worm: ' strjoin(via, ', ')]);
            testCase.verifyTrue(all(contains(via(contains(via, 'instance_of')), 'member_of > instance_of')), ...
                'reached through the cohort');
            i = W(1).interactions();
            testCase.verifyFalse(any(cellfun(@(x) contains(x.via(), 'instance_of'), i)), ...
                'a type''s interactions do not pass to its instances');
            % the species is stated ONCE, on the strain (decision #112): not
            % on the worm, not on its cohort, and still found for both, by
            % reading the worm and by a search, through the strain
            sp = a(cellfun(@(x) strcmpi(x.variable_name(), 'species'), a));
            testCase.verifyNumElements(sp, 1);
            testCase.verifyEqual(sp{1}.via(), 'member_of > instance_of');
            testCase.verifyEqual(lower(sp{1}.raw_value().node), 'ncbitaxon:6239');
            cohort = ndi.entity.search(S, {'LocalIdentifier', 'concentration_assayPlate0012_worms'});
            testCase.assertNumElements(cohort, 1);
            testCase.verifyFalse(any(cellfun(@(x) strcmpi(x.variable_name(), 'species'), ...
                cohort{1}.assertions('inherited', false))), 'the cohort states no species of its own');
            found = local(ndi.entity.search(S, {'type', 'organism', 'species', 'Caenorhabditis elegans'}));
            testCase.verifyTrue(all(ismember(local(ws), found)), ...
                ['a search by species finds the worms through their strain: ' strjoin(found, ', ')]);
            testCase.verifyEmpty(ndi.entity.search(S, {'type', 'organism', 'species', ...
                'Caenorhabditis elegans'}, 'inherited', false, 'strict', false), ...
                'no worm states it itself (nor anything in the session: not inherited, the strain''s is not searched)');
            lawns = local(ndi.entity.search(S, {'species', 'NCBITaxon:562'}));
            testCase.verifyTrue(ismember('concentration_assayPlate0012_patch0001', lawns), ...
                'a patch is an instance_of OP50, whose species is E. coli');
            % a session folder opened on its own holds the relation, not the strain
            T0 = ndi.summary(ndi.entity.search(testCase.Session, {'type', 'organism', 'contained_in', ...
                testCase.subject('concentration_assayPlate0012')}));
            testCase.verifyFalse(ismember('strain', T0.Properties.VariableNames));
        end

        function testStatementsOfManySubjectsAndSummaries(testCase)
            S = testCase.Session;
            ws = ndi.entity.search(S, {'type', 'organism', 'contained_in', ...
                testCase.subject('concentration_assayPlate0012')});
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
            m = manipulations(W(1), {'variable', 'location'});
            testCase.verifyNotEmpty(m, 'the moves onto plates, stated on the cohort');
            testCase.verifyTrue(all(cellfun(@(x) strcmpi(x.variable_name(), 'location'), m)));

            T = ndi.summary(ws);
            testCase.verifyEqual(height(T), 2);
            testCase.verifyTrue(all(ismember({'name', 'kind', 'id', 'type', 'local_identifier'}, ...
                T.Properties.VariableNames)));
            if ismember('strain', T.Properties.VariableNames)
                testCase.verifyEqual(T.strain, ["N2"; "N2"], 'the cohort''s strain, inherited');
            end
            testCase.verifyEqual(W(1).summary().id, string(W(1).document_id), 'one object: one row');
            N = ndi.summary(ws, 'nodes', true);
            if ismember('Species', N.Properties.VariableNames)
                testCase.verifyEqual(lower(N.Species_node), ["ncbitaxon:6239"; "ncbitaxon:6239"]);
                testCase.verifyFalse(ismember('Species_node', T.Properties.VariableNames), 'nodes only when asked');
            end

            U = ndi.summary(statements(W));
            testCase.verifyEqual(height(U), numel(statements(W)));
            testCase.verifyTrue(all(ismember({'subject', 'kind', 'class', 'variable', 'variable_node', ...
                'method', 'method_node', 'value', 'value_node', 'unit', 'start', 'end', 'timezone', ...
                'stated_on', 'via', 'id'}, U.Properties.VariableNames)));
            sp = U(lower(U.variable) == "species", :);
            if height(sp) > 0
                testCase.verifyEqual(unique(lower(sp.value_node)), "ncbitaxon:6239", 'a term value carries its node');
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
            typo = strrep(strainProp(), 'strain', 'stran');
            testCase.verifyError(@() ndi.entity.search(S, {typo, 'N2'}), 'ndi:entity:search:unknownVariable');
            try
                ndi.entity.search(S, {typo, 'N2'});
            catch err
                testCase.verifySubstring(err.message, ['No entity in this session has a property ''' typo '''.']);
                testCase.verifySubstring(err.message, 'Properties in this session: ');
                testCase.verifySubstring(err.message, 'local_identifier');
            end
            R = testCase.Reach;     % where the species is stated (#112)
            testCase.verifyWarning(@() ndi.entity.search(R, {'species', 'Caenorhabdiits elegans'}), ...
                'ndi:entity:search:noSuchValue');
            % the message, whole: as an error (evalc wraps it at the console width)
            b = warning('error', 'ndi:entity:search:noSuchValue'); %#ok<CTPCT>
            restore = onCleanup(@() warning(b));
            msg = '';
            try
                ndi.entity.search(R, {'species', 'Caenorhabdiits elegans'});
            catch err
                msg = err.message;
            end
            clear restore
            testCase.verifySubstring(msg, 'Did you mean ''Caenorhabditis elegans''?');
            testCase.verifySubstring(msg, 'Species in this session: ');
            % strict false: nothing, quietly
            testCase.verifyEmpty(testCase.verifyWarningFree(@() ...
                ndi.entity.search(S, {typo, 'N2'}, 'strict', false)));
            testCase.verifyEmpty(testCase.verifyWarningFree(@() ...
                ndi.entity.search(R, {'species', 'Caenorhabdiits elegans'}, 'strict', false)));
            testCase.verifyEmpty(testCase.verifyWarningFree(@() ...
                ndi.entity.search(S, {'type', 'organism', 'contained_in', {typo, 'N2'}}, 'strict', false)), ...
                'a nested description is strict as the outer search is');
            testCase.verifyEqual(ndi.v2.closest('stran', {'strain', 'species'}), 'strain');
            testCase.verifyEqual(ndi.v2.closest('zzz', {'strain', 'species'}), '');
        end

        function testCalculationValueFromItsBody(testCase)
            w = testCase.subject('concentration_worm0121');
            sp = w.statements('velocity_calculation');
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
            testCase.verifyEqual(ax.variable(2), "Body Part");
            testCase.verifyEqual(ax.n(2), 1, 'one statement for the worm''s body parts: here the midpoint');

            in = sp{1}.inputs();
            testCase.verifyNumElements(in, 1);
            testCase.verifyClass(in{1}, 'ndi.calculation');
            testCase.verifyEqual(in{1}.variable_name(), 'position');
            xy = double(in{1}.value());
            testCase.verifyEqual(reshape(xy, 5, 2), [(1:5)' + 12.1 - 0.5, 3.5 * ones(5, 1)], 'AbsTol', 1e-12);
            P = in{1}.method_parameters();
            testCase.verifyEqual(sort(P.variable)', ["interpolation method", "maximum gap filled"]);
            testCase.verifyFalse(any(cellfun(@isstruct, P.value)), ...
                'a numeric parameter is its number, not its stored record');
            P = sp{1}.method_parameters();
            num = P(cellfun(@isnumeric, P.value), :);
            testCase.verifyNotEmpty(num, 'the speed''s window is a number');
            testCase.verifyTrue(all(cellfun(@isscalar, num.value)));

            de = w.statements('length_calculation');
            testCase.verifyNumElements(de, 1);
            testCase.verifyNumElements(de{1}.inputs(), 2, 'the positions and the lawn mask');
            testCase.verifyEqual(double(de{1}.value()), 2 * 1e-3 / 33 * ones(5, 1), 'AbsTol', 1e-15);
        end

        function testManipulations(testCase)
            plate = testCase.subject('concentration_assayPlate0012');
            pour = plate.statements('manipulation', {'variable', 'nematode growth medium'});
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

            tm = plate.statements('temperature_manipulation');
            testCase.verifyNumElements(tm, 2);
            m = sort(cellfun(@(s) s.method_name(), tm, 'UniformOutput', false));
            testCase.verifyEqual(m, {'ambient exposure', 'refrigeration'});
            mt = tm{1}.method();
            testCase.verifyClass(mt, 'ndi.term');
            testCase.verifyTrue(any(mt == ["ambient exposure", "refrigeration"]), 'a method is an ndi.term');
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

        function testAMethodDocumentReadsLikeTheInlineBlock(testCase)
            % did-schema #88 (V_eta_method_plan.md): a statement carries the
            % inline `method` block OR a `method_id` edge to a standalone
            % `method` document, never both; ndi.interaction reads either.
            moves = ndi.statement.search(testCase.Session, 'Variable', 'location', 'Method', 'agar plug transfer');
            testCase.assertNotEmpty(moves);
            inline = moves{1}.document_properties();
            testCase.assertTrue(isfield(inline.interaction.method, 'term'), 'the import writes the block');
            sid = testCase.Session.id();
            prev = did2.schema.cache.strictMode('TermRegistry', false);
            restore = onCleanup(@() did2.schema.cache.strictMode('TermRegistry', prev));
            m = did2.build.method(inline.interaction.method.term, ...
                inline.interaction.method.parameters, 'Name', 'house transfer', 'SessionId', sid);
            clear restore;
            byEdge = inline;
            byEdge.base.id = char(ndi.ido.unique_id());
            byEdge.interaction = rmfield(byEdge.interaction, 'method');
            dep = byEdge.depends_on;
            if iscell(dep), dep = [dep{:}]; end
            dep = struct('name', [{dep.name}, {'method_id'}], ...
                'document_id', [{dep.document_id}, {m.base.id}]);
            byEdge.depends_on = dep;
            folder = fullfile(testCase.Root, ['method_' char(ndi.ido.unique_id())]);
            copyfile(testCase.Session.getpath(), folder);
            db = did2.database.sqlitedb(fullfile(folder, '.ndi', ...
                ndi.database.implementations.database.did2sqlite.DEFAULTFILENAME()));
            db.add({did2.document(m), did2.document(byEdge)});
            db.close();
            S = ndi.session.dir(folder);
            st = ndi.statement.fromDocument(S, byEdge.base.id);
            testCase.verifyEqual(st.method_name(), moves{1}.method_name());
            P = st.method_parameters();
            testCase.verifyEqual(P.variable, moves{1}.method_parameters().variable);
            mb = ndi.v2.methodOf(S, byEdge, 'interaction');
            testCase.verifyEqual(mb.id, m.base.id);
            testCase.verifyEqual(mb.name, 'house transfer');
        end

        function testAMethodFilterFindsAMethodDocument(testCase)
            % did-schema #88: a method filter matches a statement whose
            % inline `interaction.method.term` matches OR whose `method_id`
            % names a `method` document whose `method.term` does; a
            % statement with neither is not found, and the counts agree.
            M = 'agar plug transfer';
            moves = ndi.statement.search(testCase.Session, 'Variable', 'location', 'Method', M);
            testCase.assertNotEmpty(moves);
            inline = moves{1}.document_properties();
            sid = testCase.Session.id();
            prev = did2.schema.cache.strictMode('TermRegistry', false);
            restore = onCleanup(@() did2.schema.cache.strictMode('TermRegistry', prev));
            m = did2.build.method(inline.interaction.method.term, ...
                inline.interaction.method.parameters, 'Name', 'house transfer', 'SessionId', sid);
            clear restore;
            dep = inline.depends_on;
            if iscell(dep), dep = [dep{:}]; end
            byEdge = inline;
            byEdge.base.id = char(ndi.ido.unique_id());
            byEdge.interaction = rmfield(byEdge.interaction, 'method');
            byEdge.depends_on = struct('name', [{dep.name}, {'method_id'}], ...
                'document_id', [{dep.document_id}, {m.base.id}]);
            neither = inline;
            neither.base.id = char(ndi.ido.unique_id());
            neither.interaction = rmfield(neither.interaction, 'method');
            neither.depends_on = struct('name', {dep.name}, 'document_id', {dep.document_id});
            folder = fullfile(testCase.Root, ['methodsearch_' char(ndi.ido.unique_id())]);
            copyfile(testCase.Session.getpath(), folder);
            db = did2.database.sqlitedb(fullfile(folder, '.ndi', ...
                ndi.database.implementations.database.did2sqlite.DEFAULTFILENAME()));
            db.add({did2.document(m), did2.document(byEdge), did2.document(neither)});
            db.close();
            S = ndi.session.dir(folder);
            idOf = @(c) cellfun(@(s) s.document_id(), c, 'UniformOutput', false);
            before = idOf(moves);

            % ndi.statement.search
            [after, info] = ndi.statement.search(S, 'Variable', 'location', 'Method', M);
            got = idOf(after);
            testCase.verifyTrue(any(strcmp(got, byEdge.base.id)), 'the method_id statement is found by its method term');
            testCase.verifyTrue(all(ismember(before, got)), 'every inline statement is still found');
            testCase.verifyFalse(any(strcmp(got, neither.base.id)), 'a statement with no method is not found');
            testCase.verifyNumElements(after, numel(moves) + 1, 'exactly one more: the method_id statement');
            testCase.verifyEqual(info.read, numel(moves) + 1, 'the denominator counts the method_id statement');
            node = inline.interaction.method.term.node;
            if ~isempty(node)
                byNode = idOf(ndi.statement.search(S, 'Variable', 'location', 'Method', char(node)));
                testCase.verifyTrue(any(strcmp(byNode, byEdge.base.id)), 'found by the method node too');
            end

            % ndi.v2.searchStatements (the path ndi.entity.search takes)
            [docs0, info0] = ndi.v2.searchStatements(testCase.Session, 'manipulation', ...
                struct('variable', 'location', 'method', M));
            [docs1, info1] = ndi.v2.searchStatements(S, 'manipulation', ...
                struct('variable', 'location', 'method', M));
            ids1 = cellfun(@(d) char(subsref(ndi.v2.props(d), substruct('.', 'base', '.', 'id'))), ...
                docs1, 'UniformOutput', false);
            testCase.verifyTrue(any(strcmp(ids1, byEdge.base.id)), 'searchStatements finds the method_id statement');
            testCase.verifyFalse(any(strcmp(ids1, neither.base.id)), 'searchStatements: no method, not found');
            testCase.verifyNumElements(docs1, numel(docs0) + 1);
            testCase.verifyEqual(info1.structural, info0.structural + 1, 'the structural count includes it');

            % a method nobody used finds nothing, by either route
            testCase.verifyEmpty(ndi.statement.search(S, 'Variable', 'location', 'Method', 'no such method zzz'));
            testCase.verifyEmpty(ndi.v2.searchStatements(S, 'manipulation', ...
                struct('variable', 'location', 'method', 'no such method zzz')));
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

        function testEntitiesOfAnyKindAreSearchedAndDescribed(testCase)
            % statements may be about any entity (2026-10-08): ndi.entity has
            % search and statements
            D = testCase.Dataset;
            p = ndi.entity.search(D, {'kind', 'person', 'name', '*Haley'});
            testCase.verifyNumElements(p, 1, 'search by kind and name');
            testCase.verifyEqual(p{1}.kind, 'person');
            testCase.verifyClass(p{1}, 'ndi.entity');
            old = ndi.entity.search(D, {'kind', 'person', 'Name', p{1}.name});
            testCase.verifyEqual(cellfun(@(x) x.document_id, old, 'UniformOutput', false), ...
                {p{1}.document_id}, 'the older (KIND, ''Name'', NAME) form still works');
            testCase.verifyEmpty(ndi.entity.search(D, {'kind', 'person', 'type', 'organism'}), ...
                'a person is not an organism');
            w = ndi.entity.search(D, {'local_identifier', 'concentration_worm0121'});
            testCase.verifyEqual(cellfun(@(x) x.document_id, ndi.entity.search(D, ...
                {'local_identifier', 'concentration_worm0121'}), 'UniformOutput', false), ...
                cellfun(@(x) x.document_id, w, 'UniformOutput', false), 'a worm is a subject');
            testCase.verifyError(@() ndi.entity.search(D, {'kind', 'subject', 'local_identifier', 'x'}), ...
                'ndi:entity:search:subjectKind');
            % a person's names are `text` assertions about it: read, and searched
            g = p{1}.assertions({'variable', 'given name'});
            testCase.verifyNumElements(g, 1);
            testCase.verifyEqual(g{1}.value().canonical(), "Jessica A");
            testCase.verifyEqual(g{1}.subject().document_id, p{1}.document_id, ...
                'a statement''s subject may be any entity');
            testCase.verifyEqual(cellfun(@(x) x.document_id, ...
                ndi.entity.search(D, {'kind', 'person', 'given name', 'jess*'}), 'UniformOutput', false), ...
                {p{1}.document_id}, 'a text value matches like a name: any case, wildcards');
            T = ndi.summary(p);
            testCase.verifyEqual(T.familyName, "Haley", 'a person''s assertions are summary columns');
        end

        function testDatasetLevelDocumentsAreReachedThroughTheDataset(testCase)
            % software, formulations, strains and people are stored with the
            % dataset (decision #20): read through the dataset, a statement
            % reaches them; read through a session, it does not
            local = 'concentration_worm0121';
            ws = ndi.entity.search(testCase.Session, {'LocalIdentifier', local});
            w = ndi.entity.fromDocument(testCase.Dataset, ws{1}.document_id());
            sp = w.statements('velocity_calculation');
            testCase.verifyNumElements(sp, 1);
            testCase.verifyEqual(double(sp{1}.value()), 121e-6 * ones(5, 1), 'AbsTol', 1e-15);
            testCase.assertNotEmpty(ndi.v2.edgeIds(sp{1}.document_properties(), 'software_id'), ...
                'with stage 2 run, a calculation names its software (import_V2, stage 10)');
            sw = sp{1}.software();
            testCase.verifyNumElements(sw, 1, 'the analysis package, from the dataset');
            testCase.verifyEqual(sw{1}.kind(), 'software');
            spS = ws{1}.statements('velocity_calculation');
            testCase.verifyEmpty(spS{1}.software(), 'not reached through the session');

            plate = ndi.entity.fromDocument(testCase.Dataset, ...
                testCase.subject('concentration_assayPlate0012').document_id());
            pour = plate.statements('manipulation', {'variable', 'nematode growth medium'});
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
            % ndi.subject is v1's, as on V2: the @ is required, and it is not
            % an ndi.entity
            testCase.verifyError(@() ndi.subject('nolab', 'a subject'), ?MException);
            s = ndi.subject('anteater23@nosuchlab.org', 'a subject');
            testCase.verifyEqual(s.local_identifier, 'anteater23@nosuchlab.org');
            testCase.verifyEqual(s.description, 'a subject');
            testCase.verifyFalse(isa(s, 'ndi.entity'));
            d = s.newdocument();
            testCase.verifyEqual(d.document_properties.subject.local_identifier, 'anteater23@nosuchlab.org');
        end
    end

    methods
        function s = subject(testCase, local, container)
            arguments
                testCase (1,1) matlab.unittest.TestCase
                local {mustBeText}
                container = []
            end
            if isempty(container), container = testCase.Session; end
            x = ndi.entity.search(container, {'LocalIdentifier', local});
            testCase.assertNumElements(x, 1, local);
            s = x{1};
        end
    end
end

function ids = sids(statements)
% the document ids of a cell array of statement objects, a row cellstr
arguments
    statements cell
end
ids = reshape(cellfun(@(x) char(x.document_properties().base.id), statements, ...
    'UniformOutput', false), 1, []);
end

function n = local(c)
arguments
    c
end
n = cellfun(@(x) x.local_identifier, c, 'UniformOutput', false);
n = reshape(n, 1, []);
end

function setName(w)
arguments
    w
end
w.name = 'x';
end

function p = strainProp()
% the strain's property name: the strain type entity's own name (T17)
p = 'strain';
end
