classdef TestHaleyWrite < matlab.unittest.TestCase
%TESTHALEYWRITE The Haley V2 import, written: one C. elegans session and one
%E. coli session, over TestHaleyRecordings' synthetic fixture.
%
%   Runs import_V2 with 'Write', true and 'Sessions' set, then reads the
%   session back: the documents in its V2 database (each recording's file
%   recorded by location, not held), an otherwise empty session folder, and
%   the acquisition systems as NDI rebuilds them (daqsystem_load), whose
%   navigator (ndi.file.navigator.bodies) finds the epochs, raw files and
%   probe maps through the documents. The placeholder videos are not real
%   videos, so nothing reads frames.

    properties
        Root
        Out
    end

    methods (TestClassSetup)
        function fixture(testCase)
            testCase.assumeTrue(~isempty(which('did2.build.document')), ...
                'did2.build (DID-matlab V2) is not on the path');
            schemaPath = getenv('DID_SCHEMA_PATH');
            testCase.assumeTrue(~isempty(schemaPath) && ...
                ndi.setup.V2.schemaHasClass('study', schemaPath), ...
                'DID_SCHEMA_PATH does not hold a V2 schema with `study`');
            testCase.Root = tempname;
            testCase.addTeardown(@() rmdir(testCase.Root, 's'));
            ndi.unittest.setup.V2.TestHaleyRecordings.writeFixture(testCase.Root);
            % the output beside the raw data (nothing is written there)
            testCase.Out = fullfile(testCase.Root, 'haley_V2');
        end
    end

    methods (Test)
        function testExclusionReasonAndAPlateNotFilmed(testCase)
            % decision #73: an excluded plate carries its day's note when the
            % day is marked `include = no`; a plate never filmed gets
            % video recording (NCIT:C91063) = false and is not excluded. Both
            % are logical assertions, false, made only where they hold.
            session = table({ndi.ido.unique_id()}, {'concentration_0001'}, false, ...
                {'no contrast video, so patches are poorly aligned'}, ...
                'VariableNames', {'session_id', 'local_identifier', 'include', 'notes'});
            S = table({'concentration_0001'; 'concentration_0001'}, {'assay_plate'; 'assay_plate'}, ...
                {'p1'; 'p2'}, [true; false], [true; false], ...
                'VariableNames', {'session', 'kind', 'local_identifier', 'exclude', 'filmed'});
            ids = containers.Map({'p1', 'p2'}, {ndi.ido.unique_id(), ndi.ido.unique_id()});
            out = ndi.setup.conv.haley.assertionDocuments(session, S, ids);
            if ~ndi.setup.V2.schemaHasLeaf('logical_assertion')
                % a schema without the `logical` value kind: neither is
                % built, and both are reported, not dropped (each plate's
                % sample type, a term, is built: decision #107)
                kinds = cellfun(@(d) newNames(d).statement.variable.name, out.documents, ...
                    'UniformOutput', false);
                testCase.verifyEqual(kinds, {'Sample Type', 'Sample Type'});
                testCase.verifyNumElements(out.skipped, 2, strjoin(out.skipped, newline));
                testCase.verifyTrue(all(contains(out.skipped, 'no `logical` value kind')));
                return;
            end
            testCase.verifyEqual(out.counts.plate_excluded, 1);
            testCase.verifyEqual(out.counts.plate_not_filmed, 1);
            docs = cellfun(@newNames, out.documents, 'UniformOutput', false);
            pick = @(var) docs(cellfun(@(d) strcmpi(d.statement.variable.name, var), docs));
            % the reason is the tag's notes; with a schema whose statements
            % have no notes, a text statement beside it
            ex = pick('inclusion in analysis');
            testCase.verifyNumElements(ex, 1);
            testCase.verifyEqual(ex{1}.statement.variable.node, 'EMPTY:0000314');
            testCase.verifyFalse(logical(ex{1}.logical.value));
            nf = pick('video recording');
            testCase.verifyNumElements(nf, 1);
            testCase.verifyEqual(nf{1}.statement.variable.node, 'NCIT:C91063');
            testCase.verifyFalse(logical(nf{1}.logical.value));
            if ndi.setup.V2.schemaHasField('statement', 'notes')
                testCase.verifyEqual(ex{1}.statement.notes, 'no contrast video, so patches are poorly aligned');
                testCase.verifyEqual(nf{1}.statement.notes, 'Prepared but not filmed: no video.');
                testCase.verifyEmpty(pick('reason for inclusion in analysis'));
            elseif ~ndi.setup.V2.schemaHasClass('text')
                % neither notes nor a text kind: the reasons are reported
                testCase.verifyEmpty(pick('reason for inclusion in analysis'));
                testCase.verifyTrue(any(contains(out.skipped, 'no contrast video')));
            else
                why = pick('reason for inclusion in analysis');
                testCase.verifyNumElements(why, 1);
                testCase.verifyEqual(why{1}.text.value(1).text, 'no contrast video, so patches are poorly aligned');
                why = pick('reason for video recording');
                testCase.verifyNumElements(why, 1);
                testCase.verifyEqual(why{1}.text.value(1).text, 'Prepared but not filmed: no video.');
            end

            % a day marked `include = yes` gives an exclusion no reason
            session.include = true;
            out = ndi.setup.conv.haley.assertionDocuments(session, S, ids);
            docs = cellfun(@newNames, out.documents, 'UniformOutput', false);
            pick = @(var) docs(cellfun(@(d) strcmpi(d.statement.variable.name, var), docs));
            ex = pick('inclusion in analysis');
            testCase.verifyNumElements(ex, 1);
            testCase.verifyEmpty(pick('reason for inclusion in analysis'));
            testCase.verifyFalse(isfield(ex{1}.statement, 'notes') && ~isempty(ex{1}.statement.notes));
        end

        function testABacterialPatchHasItsSampleType(testCase)
            % decision #104: a patch with bacteria carries sample type
            % (NCIT:C210102) = bacterial patch (EMPTY:0000325); a patch of LB
            % alone is not a bacterial patch and gets none
            session = table({ndi.ido.unique_id()}, {'concentration_0001'}, ...
                'VariableNames', {'session_id', 'local_identifier'});
            S = table({'concentration_0001'; 'concentration_0001'}, {'patch'; 'patch'}, ...
                {'p1_patch0001'; 'p1_patch0002'}, {'OP50'; ''}, ...
                'VariableNames', {'session', 'kind', 'local_identifier', 'bacteria'});
            ids = containers.Map({'p1_patch0001', 'p1_patch0002'}, ...
                {ndi.ido.unique_id(), ndi.ido.unique_id()});
            out = ndi.setup.conv.haley.assertionDocuments(session, S, ids);
            testCase.verifyEqual(out.counts.patch_sample_type, 1);
            docs = cellfun(@newNames, out.documents, 'UniformOutput', false);
            st = docs(cellfun(@(d) strcmp(d.statement.variable.name, 'Sample Type'), docs));
            testCase.verifyNumElements(st, 1);
            testCase.verifyEqual(st{1}.statement.variable.node, 'NCIT:C210102');
            testCase.verifyEqual(st{1}.term.value.node, 'EMPTY:0000325');
            testCase.verifyEqual(st{1}.term.value.name, 'bacterial patch');
            on = ndi.v2.edgeIds(st{1}, 'entity_id');
            testCase.verifyEqual(on, {ids('p1_patch0001')}, 'on the patch with bacteria');
        end

        function testConcentrationSession(testCase)
            result = testCase.write("concentration_0001");
            testCase.verifyEqual(height(result.sessions), 1);
            sessionPath = result.sessions.path{1};

            docs = testCase.documents(sessionPath);
            classes = cellfun(@(d) d.document_class.class_name, docs, 'UniformOutput', false);
            count = @(c) sum(strcmp(classes, c));
            % plates 11-14, one patch each, two worms each, one cohort each
            % (decision #55); three acclimation plates (the fixture's plates
            % were picked at three times), each with its one patch; one food
            % deprivation plate (plate 14's worms)
            testCase.verifyEqual(count('subject'), 4 + 4 + 8 + 4 + 3 + 3 + 1);
            % plate 11 twice + 12 + 14 (behaviour) + 2 lawn clips
            testCase.verifyEqual(count('epoch'), 6);
            testCase.verifyEqual(count('intensity_observation'), 6);
            % the behaviour videos are brightfield imaging; the 2 lawn clips,
            % filmed with a card between the light and the plate, oblique
            % illumination imaging (decision #108)
            io = docs(strcmp(classes, 'intensity_observation'));
            how = cellfun(@(d) d.interaction.method.node, io, 'UniformOutput', false);
            testCase.verifyEqual(sum(strcmp(how, 'EMPTY:0000300')), 4);
            testCase.verifyEqual(sum(strcmp(how, 'EMPTY:0000348')), 2);
            testCase.verifyEqual(count('opaque_body'), 6);
            testCase.verifyEqual(count('acquisition_system'), 2, 'camera1 and camera2');
            testCase.verifyEqual(count('session'), 1);

            s = docs{strcmp(classes, 'session')};
            testCase.verifyNotEmpty(s.depends_on, 'the session names its UTC extent');

            b = docs(strcmp(classes, 'opaque_body'));
            b = b{cellfun(@(d) strcmp(d.data_body.filename, '2022-02-04_12-10-51_2.mp4'), b)};
            % an EDAM format term (did-schema 877bbde); the media type on an
            % older schema copy
            [~, decl] = ndi.setup.V2.schemaHasField('data_body', 'format');
            if ~isempty(decl) && strcmp(decl.type, 'ontology_term')
                testCase.verifyEqual(b.data_body.format.node, 'EDAM:format_3997');
                testCase.verifyEqual(b.data_body.format.name, 'MPEG-4');
            else
                testCase.verifyEqual(b.data_body.format, 'video/mp4');
            end
            testCase.verifyEqual(b.data_body.size_bytes, 100);
            testCase.verifyEqual(b.data_body.hash_algorithm, 'MD5');
            testCase.verifyEqual(numel(b.data_body.content_hash), 32);
            % the file is recorded BY LOCATION, not held: the raw file, in place
            raw = fullfile(testCase.Root, 'haley', 'celegans', 'foragingConcentration', ...
                'videos', '22-02-04', '2022-02-04_12-10-51_2.mp4');
            [tf, where] = ndi.database.fun.externalFileLocation(b, 'body_data_0');
            testCase.verifyTrue(tf);
            testCase.verifyEqual(where, raw);
            testCase.verifyEqual(b.files.file_info.locations.ingest, 0);

            % nothing is written into the session folder but its database,
            % and nothing next to the raw data
            listing = dir(sessionPath);
            testCase.verifyEqual(sort(setdiff({listing.name}, {'.', '..'})), {'.ndi'});
            testCase.verifyEmpty(dir(fullfile(fileparts(raw), '.*.epochid.ndi')));

            % NDI rebuilds both cameras from the session's own database, and
            % each finds its epochs, files and probe maps through the documents
            session = ndi.session.dir(sessionPath);
            sys = session.daqsystem_load();
            if ~iscell(sys), sys = {sys}; end
            names = cellfun(@(x) x.name, sys, 'UniformOutput', false);
            testCase.verifyEqual(sort(names), {'camera1', 'camera2'});
            cam2 = sys{strcmp(names, 'camera2')};
            testCase.verifyClass(cam2, 'ndi.daq.system.image');
            testCase.verifyClass(cam2.filenavigator, 'ndi.file.navigator.bodies');
            et = cam2.filenavigator.epochtable();
            testCase.verifyEqual(sort({et.epoch_id}), ...
                {'concentration_2022-02-04_11-49-08_2', 'concentration_2022-02-04_12-10-51_2', ...
                 'concentration_2022-02-04_15-17-10_2'}, ...
                'camera 2: plate 12 and its lawn clip, and plate 14 (camera 2 by its file name)');
            e = et(strcmp({et.epoch_id}, 'concentration_2022-02-04_12-10-51_2'));
            testCase.verifyEqual(e.underlying_epochs.underlying, {raw});
            subj = docs(strcmp(classes, 'subject'));
            plate = subj{cellfun(@(d) strcmp(d.subject.local_identifier, ...
                'concentration_assayPlate0012'), subj)};
            testCase.verifyEqual(e.epochprobemap.name, 'camera2');
            testCase.verifyEqual(e.epochprobemap.type, 'brightfield-imaging');
            testCase.verifyEqual(e.epochprobemap.subjectstring, plate.base.id);
        end

        function testRelations(testCase)
            % stage 6 (decision #52), over the fixture's concentration_0001:
            % plates 11-14 (one patch each, two worms each, worms N = plate*10
            % + 1, 2), three acclimation plates; plate 13 has no video.
            result = testCase.write("concentration_0001");
            docs = testCase.documents(result.sessions.path{1});
            classes = cellfun(@(d) d.document_class.class_name, docs, 'UniformOutput', false);
            byId = containers.Map(cellfun(@(d) d.base.id, docs, 'UniformOutput', false), docs);
            subj = docs(strcmp(classes, 'subject'));
            idOf = containers.Map(cellfun(@(d) d.subject.local_identifier, subj, 'UniformOutput', false), ...
                cellfun(@(d) d.base.id, subj, 'UniformOutput', false));
            rel = docs(strcmp(classes, 'directed_relation'));
            % only relations between subjects (the session is also part_of
            % its study, minted in stage 3 since decision #50)
            subjectIdSet = values(idOf);
            rel = rel(cellfun(@(r) any(strcmp(edge(r, 'child_id'), subjectIdSet)), rel));
            testCase.verifyEqual(numel(rel), 4 + 3 + 8 + 4 + 4 + 1, ['4 assay-plate patches and ' ...
                '3 acclimation-plate patches contained_in their plate (#107), 8 worms ' ...
                'member_of their cohort, 4 cohorts in their assay plate, 4 in their acclimation ' ...
                'plate, 1 (plate 14) in a food deprivation plate (decision #55)']);
            find1 = @(child, parent, name) rel(cellfun(@(r) ...
                strcmp(edge(r, 'child_id'), idOf(child)) && strcmp(edge(r, 'parent_id'), idOf(parent)) ...
                && strcmp(r.directed_relation.relation.name, name), rel));

            % a patch is contained_in its plate (decision #107), from the
            % plate's seeding to its last recording
            r = find1('concentration_assayPlate0012_patch0001', 'concentration_assayPlate0012', 'contained_in');
            testCase.verifyNumElements(r, 1);
            tr = edgeAll(r{1}, 'time_reference_id');
            testCase.verifyNumElements(tr, 1, 'a stay with a time');
            t = docs(cellfun(@(d) strcmp(d.base.id, tr{1}), docs));
            testCase.verifyNumElements(t, 1, 'the stay''s time reference is written');
            testCase.verifyEmpty(find1('concentration_assayPlate0012_patch0001', ...
                'concentration_assayPlate0012', 'part_of'), 'no longer part_of');
            r = find1('concentration_0001_acclimationPlate0001_patch0001', ...
                'concentration_0001_acclimationPlate0001', 'contained_in');
            testCase.verifyNumElements(r, 1, 'an acclimation plate''s one patch is in it');

            % each worm is a member of its plate's cohort, timelessly; the
            % plates and moves are stated once, on the cohort (decision #55)
            r = find1('concentration_worm0121', 'concentration_assayPlate0012_worms', 'member_of');
            testCase.verifyNumElements(r, 1);
            testCase.verifyEmpty(edgeAll(r{1}, 'time_reference_id'));
            testCase.verifyEmpty(find1('concentration_worm0121', 'concentration_assayPlate0012', ...
                'contained_in'), 'no per-worm plate relation: the cohort carries it');

            % worm 121's cohort was on assay plate 12 while it was filmed: from
            % its first behaviour video, 2022-02-04 12:10:51 Los Angeles = 20:10:51 UTC
            r = find1('concentration_assayPlate0012_worms', 'concentration_assayPlate0012', 'contained_in');
            testCase.verifyNumElements(r, 1);
            % it holds of each worm: `distributive`, once the schema has it (#84)
            if ndi.setup.V2.schemaHasField('directed_relation', 'distributive')
                testCase.verifyTrue(logical(r{1}.directed_relation.distributive));
            else
                testCase.verifyFalse(isfield(r{1}.directed_relation, 'distributive'));
            end
            t = edgeAll(r{1}, 'time_reference_id');
            testCase.verifyNumElements(t, 1);
            ref = byId(t{1});
            testCase.verifyEqual(ref.absolute_time_reference.value.start.utc, '2022-02-04T20:10:51.000Z');
            testCase.verifyTrue(logical(ref.absolute_time_reference.value.start.approximate), ...
                'the transfer was a few minutes before filming: the start is approximate');
            testCase.verifyTrue(logical(ref.absolute_time_reference.value.duration.approximate), ...
                'an approximate start makes the extent approximate');
            testCase.verifyNotEmpty(ref.absolute_time_reference.value.end.utc, ...
                'the window records its end: the end of filming');
            testCase.verifyFalse(logical(ref.absolute_time_reference.value.end.approximate), ...
                'the end of filming is a video time: exact (CHANGE 6)');
            % CHANGE 7: T is only ever EARLY of the video it is read off --
            % [minus 0], minus at most the protocol's 5 min (lawn first: or
            % less, to the lawn clip); the end of filming states no bound
            v = ref.absolute_time_reference.value;
            testCase.verifyEqual(v.start.tolerance.plus, 0, 'never later than the video');
            testCase.verifyGreaterThan(v.start.tolerance.minus, 0);
            testCase.verifyLessThanOrEqual(v.start.tolerance.minus, 300);
            testCase.verifyFalse(isfield(v.end, 'tolerance'), 'the end of filming is exact');
            testCase.verifyEqual(v.duration.tolerance.minus, 0, ...
                'the start can only be earlier, so the window only longer');
            testCase.verifyEqual(v.duration.tolerance.plus, v.start.tolerance.minus, 'AbsTol', 1e-9);

            % ... and on its acclimation plate from the pick time (the day
            % before, 12:10:51) until filming, that end approximate
            r = find1('concentration_assayPlate0012_worms', 'concentration_0001_acclimationPlate0001', 'contained_in');
            testCase.verifyNumElements(r, 1);
            t = edgeAll(r{1}, 'time_reference_id');
            ref = byId(t{1});
            testCase.verifyEqual(ref.absolute_time_reference.value.start.utc, '2022-02-03T20:10:51.000Z');
            testCase.verifyEqual(ref.absolute_time_reference.value.duration.seconds, 86400, 'AbsTol', 1e-6);
            testCase.verifyEqual(ref.absolute_time_reference.value.end.utc, '2022-02-04T20:10:51.000Z');
            testCase.verifyTrue(logical(ref.absolute_time_reference.value.end.approximate), ...
                'it ends at the transfer T, which is approximate');
            testCase.verifyTrue(logical(ref.absolute_time_reference.value.duration.approximate));
            testCase.verifyTrue(logical(ref.absolute_time_reference.value.start.approximate), ...
                'the pick time was written by hand: approximate');
            v = ref.absolute_time_reference.value;
            testCase.verifyEqual(v.start.tolerance, struct('minus', 60, 'plus', 60), ...
                'read off a clock (perhaps analog) and written to the minute');
            testCase.verifyEqual(v.start.source_value, '2022-02-03T12:10', ...
                'source_value at the resolution it was written: no invented seconds');
            testCase.verifyEqual(v.end.tolerance.plus, 0, 'it ends at T: early only');
            testCase.verifyEqual(v.duration.tolerance.minus, 60 + v.end.tolerance.minus, 'AbsTol', 1e-9, ...
                'shortest: picked a minute late and moved T-minus early');
            testCase.verifyEqual(v.duration.tolerance.plus, 60, 'AbsTol', 1e-9, ...
                'longest: picked a minute early, moved at T');

            % plate 14 was food-deprived: acclimation plate (picked the day
            % before, 15:17:10) -> food deprivation plate (12:17:10, 3 h before
            % filming) -> assay plate (filmed from 15:17:10)
            r = find1('concentration_assayPlate0014_worms', 'concentration_0001_foodDeprivationPlate0001', 'contained_in');
            testCase.verifyNumElements(r, 1);
            t = edgeAll(r{1}, 'time_reference_id');
            ref = byId(t{1});
            testCase.verifyEqual(ref.absolute_time_reference.value.start.utc, '2022-02-04T20:17:10.000Z');
            testCase.verifyEqual(ref.absolute_time_reference.value.duration.seconds, 3 * 3600, 'AbsTol', 1e-6);
            testCase.verifyEqual(ref.absolute_time_reference.value.end.utc, '2022-02-04T23:17:10.000Z');
            testCase.verifyTrue(logical(ref.absolute_time_reference.value.end.approximate), ...
                'it ends at the transfer T, which is approximate');
            testCase.verifyTrue(logical(ref.absolute_time_reference.value.start.approximate), ...
                'starvedTime was read off a clock too: approximate');
            testCase.verifyEqual(ref.absolute_time_reference.value.start.tolerance, ...
                struct('minus', 60, 'plus', 60));
            r = find1('concentration_assayPlate0014_worms', 'concentration_0001_acclimationPlate0003', 'contained_in');
            testCase.verifyNumElements(r, 1);
            t = edgeAll(r{1}, 'time_reference_id');
            ref = byId(t{1});
            testCase.verifyEqual(ref.absolute_time_reference.value.duration.seconds, 21 * 3600, 'AbsTol', 1e-6, ...
                'the acclimation window ends when the worms move to the food deprivation plate');
            testCase.verifyTrue(logical(ref.absolute_time_reference.value.duration.approximate), ...
                'the pick (its start) is approximate, so the extent is');

            % plate 13 was never filmed: its cohort is in it, with no time
            r = find1('concentration_assayPlate0013_worms', 'concentration_assayPlate0013', 'contained_in');
            testCase.verifyNumElements(r, 1);
            testCase.verifyEmpty(edgeAll(r{1}, 'time_reference_id'));
        end

        function testAssertionsAndTypes(testCase)
            % stage 7 (decision #55), over the fixture's concentration_0001,
            % with stage 2 run so the strains have documents
            result = testCase.write("concentration_0001", ["metadata", "assertions"]);
            docs = testCase.documents(result.sessions.path{1});
            classes = cellfun(@(d) d.document_class.class_name, docs, 'UniformOutput', false);
            subj = docs(strcmp(classes, 'subject'));
            idOf = containers.Map(cellfun(@(d) d.subject.local_identifier, subj, 'UniformOutput', false), ...
                cellfun(@(d) d.base.id, subj, 'UniformOutput', false));
            byLocal = containers.Map(cellfun(@(d) d.subject.local_identifier, subj, 'UniformOutput', false), subj);
            ta = docs(strcmp(classes, 'term_assertion'));
            about = @(local, variable) ta(cellfun(@(a) strcmp(edge(a, 'entity_id'), idOf(local)) ...
                && strcmpi(a.statement.variable.name, variable), ta));

            % 4 cohorts, each with a species, a strain and a sex; 7 seeded
            % patches (one per assay plate, one per acclimation plate), each
            % with a species, a strain and a sample type (#104); 8 plates (4
            % assay, 3 acclimation, 1 food deprivation), each with its sample
            % type (#107). With one entity class (2026-10-08)
            % the strain is an `instance_of` relation to the strain entity
            % instead of an assertion, and the species is stated once, on
            % the strain entity, not on each cohort and patch (decision
            % #112). Plate 13's exclusion is a logical assertion, not a term.
            merged = ndi.setup.V2.mergedEntities();
            perStrain = double(~merged);
            testCase.verifyNumElements(ta, 4 * (1 + 2 * perStrain) + 7 * (1 + 2 * perStrain) + 8);
            kind = ta(cellfun(@(a) strcmp(a.statement.variable.name, 'Sample Type'), ta));
            kinds = cellfun(@(a) a.term.value.name, kind, 'UniformOutput', false);
            testCase.verifyEqual(sum(strcmp(kinds, 'bacterial patch')), 7, 'one per seeded patch');
            testCase.verifyEqual(sum(strcmp(kinds, 'assay plate')), 4);
            testCase.verifyEqual(sum(strcmp(kinds, 'acclimation plate')), 3);
            testCase.verifyEqual(sum(strcmp(kinds, 'food deprivation plate')), 1);
            rel = docs(strcmp(classes, 'directed_relation'));
            instanceOf = @(local) rel(cellfun(@(r) strcmp(r.directed_relation.relation.name, ...
                'instance_of') && strcmp(edge(r, 'child_id'), idOf(local)), rel));
            % the species: on the cohort (did-schema main), or once on the
            % strain entity the cohort is an instance_of (decision #112)
            md = result.metadata.documents;
            speciesOf = @(id) md(cellfun(@(d) isfield(d, 'statement') && ...
                strcmp(edge(d, 'entity_id'), id) && strcmp(d.statement.variable.node, 'NCIT:C45293'), md));
            a = about('concentration_assayPlate0012_worms', 'species');
            if merged
                testCase.verifyEmpty(a, 'not repeated on the cohort: its strain states it');
                a = speciesOf(result.metadata.ids('N2'));
            end
            testCase.verifyNumElements(a, 1);
            testCase.verifyEqual(a{1}.statement.variable.node, 'NCIT:C45293');
            testCase.verifyEqual(a{1}.term.value.node, 'NCBITaxon:6239');
            if merged
                r = instanceOf('concentration_assayPlate0012_worms');
                testCase.verifyNumElements(r, 1);
                testCase.verifyEqual(edge(r{1}, 'parent_id'), result.metadata.ids('N2'), ...
                    'the cohort is an instance of the dataset-level N2 strain entity');
                testCase.verifyTrue(logical(r{1}.directed_relation.distributive), ...
                    'stated of the cohort, it holds of each worm');
                testCase.verifyEmpty(about('concentration_assayPlate0012_worms', 'organism strain'));
            else
                a = about('concentration_assayPlate0012_worms', 'organism strain');
                testCase.verifyNumElements(a, 1);
                testCase.verifyEqual(a{1}.statement.variable.node, 'NCIT:C14419');
                testCase.verifyEqual(a{1}.term.value.name, 'N2');
                testCase.verifyEqual(a{1}.term.value.node, 'WormBase:WBStrain00000001', ...
                    'the strain is its WormBase term, not a name alone');
                testCase.verifyEqual(edge(a{1}, 'strain_id'), result.metadata.ids('N2'), ...
                    'the strain assertion names the dataset-level strain document');
                if ndi.setup.V2.schemaHasField('statement', 'distributive')
                    testCase.verifyTrue(logical(a{1}.statement.distributive), ...
                        'stated on the cohort, it holds of each worm');
                end
            end
            a = about('concentration_assayPlate0012_worms', 'biological sex');
            testCase.verifyNumElements(a, 1);
            testCase.verifyEqual(a{1}.statement.variable.node, 'PATO:0000047');
            testCase.verifyEqual(a{1}.term.value.node, 'PATO:0001340');
            testCase.verifyEqual(a{1}.term.value.name, 'hermaphrodite');
            testCase.verifyEmpty(about('concentration_assayPlate0012_patch0001', 'biological sex'), ...
                'bacteria have no sex');
            testCase.verifyEmpty(about('concentration_worm0121', 'species'), ...
                'a worm inherits its cohort''s species; it is not repeated');
            if merged
                r = instanceOf('concentration_assayPlate0012_patch0001');
                testCase.verifyNumElements(r, 1);
                testCase.verifyEqual(edge(r{1}, 'parent_id'), result.metadata.ids('OP50'));
            else
                a = about('concentration_assayPlate0012_patch0001', 'organism strain');
                testCase.verifyNumElements(a, 1);
                testCase.verifyEqual(a{1}.term.value.name, 'OP50');
                testCase.verifyEqual(a{1}.term.value.node, 'WormBase:WBStrain00041969');
            end
            a = about('concentration_assayPlate0012_patch0001', 'species');
            if merged
                testCase.verifyEmpty(a, 'not repeated on the patch: OP50 states it');
                a = speciesOf(result.metadata.ids('OP50'));
                testCase.verifyNumElements(a, 1);
                testCase.verifyEmpty(about('concentration_0001_acclimationPlate0001_patch0001', 'species'));
                testCase.verifyNumElements(instanceOf('concentration_0001_acclimationPlate0001_patch0001'), 1, ...
                    'an acclimation plate''s patch is OP50 too');
            end
            testCase.verifyEqual(a{1}.term.value.node, 'NCBITaxon:562');
            if ~merged
                a = about('concentration_0001_acclimationPlate0001_patch0001', 'species');
                testCase.verifyNumElements(a, 1, 'an acclimation plate''s patch is OP50 too');
                testCase.verifyEqual(a{1}.term.value.node, 'NCBITaxon:562');
            end

            % excluded, and never filmed: logical assertions, false, only where
            % they hold
            if ndi.setup.V2.schemaHasLeaf('logical_assertion')
                la = docs(strcmp(classes, 'logical_assertion'));
                aboutL = @(local, variable) la(cellfun(@(a) strcmp(edge(a, 'entity_id'), idOf(local)) ...
                    && strcmpi(a.statement.variable.name, variable), la));
                a = aboutL('concentration_assayPlate0013', 'inclusion in analysis');
                testCase.verifyNumElements(a, 1);
                testCase.verifyFalse(logical(a{1}.logical.value));
                testCase.verifyEmpty(aboutL('concentration_assayPlate0012', 'inclusion in analysis'));
                testCase.verifyEmpty(aboutL('concentration_assayPlate0012', 'video recording'), ...
                    'plate 12 was filmed');
            end

            % the target design as statements (fixture: 1.5 mm patches 5 mm
            % apart): each assay-plate patch's diameter, each plate's spacing,
            % value basis = target
            if ndi.setup.V2.schemaHasLeaf('length_assertion')
                lens = docs(strcmp(classes, 'length_assertion'));
                testCase.verifyNumElements(lens, 4 + 4, ...
                    '4 assay-plate patches'' diameters, 4 assay plates'' spacings');
                d = lens(cellfun(@(a) strcmp(edge(a, 'entity_id'), ...
                    idOf('concentration_assayPlate0012_patch0001')), lens));
                testCase.verifyNumElements(d, 1);
                testCase.verifyEqual(d{1}.statement.variable.node, 'PATO:0001334');
                testCase.verifyEqual(d{1}.length.value(1).meters, 1.5e-3, 'AbsTol', 1e-12);
                testCase.verifyEqual(d{1}.length.value(1).source_value, 1.5, 'AbsTol', 1e-12);
                testCase.verifyEqual(d{1}.length.value(1).source_unit, 'mm');
                c = entries(d{1}.statement.conditions);
                c = [c{:}];
                testCase.verifyNumElements(c, 1);
                testCase.verifyEqual(c(1).variable.node, 'EMPTY:0000298');
                testCase.verifyEqual(c(1).term.node, 'EMPTY:0000299');
                sp = lens(cellfun(@(a) strcmp(edge(a, 'entity_id'), idOf('concentration_assayPlate0012')), lens));
                testCase.verifyNumElements(sp, 1);
                testCase.verifyEqual(sp{1}.statement.variable.node, 'NCIT:C45786');
                testCase.verifyEqual(sp{1}.length.value(1).meters, 5e-3, 'AbsTol', 1e-12);
                testCase.verifyEmpty(lens(cellfun(@(a) strcmp(edge(a, 'entity_id'), ...
                    idOf('concentration_0001_acclimationPlate0001_patch0001')), lens)), ...
                    'an acclimation plate has no target design');
                % the stage returns them per plate, for the calculation that used them
                t = result.written{1}.assertions.targetIds;
                testCase.verifyEqual(sort(t('concentration_assayPlate0012')), ...
                    sort({d{1}.base.id, sp{1}.base.id}));
            end

            % subject.type, once the schema has it (#84)
            if ndi.setup.V2.schemaHasField('subject', 'type')
                type = @(local) subjectType(byLocal, local);
                testCase.verifyEqual(type('concentration_worm0121'), 'organism');
                testCase.verifyEqual(type('concentration_assayPlate0012_worms'), 'group');
                testCase.verifyEqual(type('concentration_assayPlate0012_patch0001'), 'culture');
                testCase.verifyEqual(type('concentration_assayPlate0012'), 'material');
                testCase.verifyEqual(type('concentration_0001_acclimationPlate0001'), 'material');
                testCase.verifyEqual(type('concentration_0001_acclimationPlate0001_patch0001'), 'culture');
            else
                w = byLocal('concentration_worm0121');
                testCase.verifyFalse(isfield(w.subject, 'type'));
            end
        end

        function testManipulations(testCase)
            % stage 8 (decisions #54, #56, #57) over the fixture's
            % concentration_0001, with stage 2 run so the recipes and the
            % seeding suspensions have documents
            result = testCase.write("concentration_0001", ["metadata", "assertions", "manipulations"]);
            c = result.written{1}.manipulations.counts;
            testCase.verifyEqual(c.pour, 4 + 3 + 1, '4 assay, 3 acclimation, 1 food deprivation plate');
            testCase.verifyEqual(c.seed_patch, 4, 'one patch per assay plate');
            testCase.verifyEqual(c.seed_acclimation_patch, 3, 'one per acclimation plate''s patch');
            testCase.verifyEqual(c.temperature, 4 * 2 + 3 * 3 + 1, ['assay: cold room, room ' ...
                'temperature; acclimation: cold room, room temperature, incubator; food ' ...
                'deprivation: incubator']);
            testCase.verifyEqual(c.transfer, 4 + 1 + 3, ['each cohort onto its acclimation ' ...
                'plate, plate 14''s onto its food deprivation plate, the 3 filmed plates'' assay transfers']);
            testCase.verifyEqual(c.food_deprivation, 1);
            testCase.verifyTrue(any(contains(result.subjectChecks.roomTempLooksEstimated, ...
                'concentration_assayPlate0012')), 'plate 12''s timeRoomTemp is recording - 1 h');

            docs = testCase.documents(result.sessions.path{1});
            classes = cellfun(@(d) d.document_class.class_name, docs, 'UniformOutput', false);
            byId = containers.Map(cellfun(@(d) d.base.id, docs, 'UniformOutput', false), docs);
            subj = docs(strcmp(classes, 'subject'));
            idOf = containers.Map(cellfun(@(d) d.subject.local_identifier, subj, 'UniformOutput', false), ...
                cellfun(@(d) d.base.id, subj, 'UniformOutput', false));
            on = @(set, local) set(cellfun(@(a) strcmp(edge(a, 'entity_id'), idOf(local)), set));
            liters = @(d) d.dose.value.volume.liters;
            dm = docs(strcmp(classes, 'dose_manipulation'));

            % the patch: 0.5 uL of that day's OD600 1 dilution, at the seeding
            seed = on(dm, 'concentration_assayPlate0012_patch0001');
            testCase.verifyNumElements(seed, 1);
            testCase.verifyEqual(liters(seed{1}), 0.5e-6, 'AbsTol', 1e-15);
            testCase.verifyEqual(edge(seed{1}, 'formulation_id'), ...
                result.metadata.ids('suspension_op50_20220202_od1'));
            testCase.verifyEqual(seed{1}.statement.variable.node, 'WormBase:WBStrain00041969', ...
                'the variable is the strain''s term');
            testCase.verifyEqual(seed{1}.statement.variable.name, 'OP50');
            % the plate: 25 mL of NGM, poured before that seeding
            pour = on(dm, 'concentration_assayPlate0012');
            testCase.verifyNumElements(pour, 1);
            testCase.verifyEqual(liters(pour{1}), 0.025, 'AbsTol', 1e-12);
            testCase.verifyEqual(edge(pour{1}, 'formulation_id'), result.metadata.ids('ngm'));
            testCase.verifyEqual(pour{1}.statement.variable.node, 'EMPTY:0000262', ...
                'the variable is the recipe''s formulation type');
            testCase.verifyEqual(pour{1}.statement.variable.name, 'nematode growth medium');
            when = byId(edge(pour{1}, 'time_reference_id'));
            testCase.verifyEqual(when.document_class.class_name, 'relative_time_reference');
            testCase.verifyEqual(edge(when, 'referent_id'), edge(seed{1}, 'time_reference_id'));
            % the acclimation plate's one patch: 200 uL of the same dilution;
            % the plate itself has only its pour
            acc = on(dm, 'concentration_0001_acclimationPlate0001_patch0001');
            testCase.verifyNumElements(acc, 1);
            testCase.verifyEqual(liters(acc{1}), 200e-6, 'AbsTol', 1e-12);
            plateDoses = on(dm, 'concentration_0001_acclimationPlate0001');
            testCase.verifyNumElements(plateDoses, 1);
            testCase.verifyEqual(liters(plateDoses{1}), 0.025, 'AbsTol', 1e-12, 'its pour');
            testCase.verifyEqual(edge(acc{1}, 'formulation_id'), ...
                result.metadata.ids('suspension_op50_20220202_od1'));

            % plate 12: into the cold room (4 C), then room temperature (20 C)
            tm = on(docs(strcmp(classes, 'temperature_manipulation')), 'concentration_assayPlate0012');
            testCase.verifyEqual(reshape(sort(cellfun(@(d) d.temperature.value.celsius, tm)), 1, []), [4 20]);
            testCase.verifyEqual(tm{1}.statement.variable.node, 'NCIT:C90380');
            methods = sort(cellfun(@(d) d.interaction.method.name, tm, 'UniformOutput', false));
            testCase.verifyEqual(reshape(methods, 1, []), {'ambient exposure', 'refrigeration'});

            % the cohort's moves, at its contained_in times
            tmn = docs(strcmp(classes, 'term_manipulation'));
            mine = on(tmn, 'concentration_assayPlate0012_worms');
            toAssay = mine(cellfun(@(d) strcmp(d.term.value.name, 'assay plate'), mine));
            testCase.verifyNumElements(toAssay, 1);
            testCase.verifyEqual(toAssay{1}.statement.variable.name, 'Location');
            testCase.verifyEqual(toAssay{1}.term.value.node, 'EMPTY:0000321', 'assay plate');
            testCase.verifyEqual(toAssay{1}.statement.variable.node, 'NCIT:C25341');
            testCase.verifyEqual(toAssay{1}.interaction.method.name, 'agar plug transfer');
            mp = toAssay{1}.interaction.method_parameters;
            if iscell(mp), mp = [mp{:}]; end
            testCase.verifyTrue(any(arrayfun(@(q) strcmp(q.variable.name, 'cleaning step'), mp)));
            dr = docs(strcmp(classes, 'directed_relation'));
            rel = dr(cellfun(@(r) strcmp(edge(r, 'child_id'), idOf('concentration_assayPlate0012_worms')) ...
                && strcmp(edge(r, 'parent_id'), idOf('concentration_assayPlate0012')), dr));
            testCase.verifyNumElements(rel, 1);
            testCase.verifyEqual(edge(toAssay{1}, 'time_reference_id'), edge(rel{1}, 'time_reference_id'), ...
                'the move is stated at the time of the relation it makes');
            fd = on(tmn, 'concentration_assayPlate0014_worms');
            fd = fd(cellfun(@(d) strcmp(d.statement.variable.name, 'food availability'), fd));
            testCase.verifyNumElements(fd, 1);
            testCase.verifyEqual(fd{1}.statement.variable.node, 'ZECO:0000113');
            testCase.verifyEqual(fd{1}.term.value.node, 'ZECO:0000114');
            testCase.verifyEqual(fd{1}.term.value.name, 'fasting');
            toDep = on(tmn, 'concentration_assayPlate0014_worms');
            toDep = toDep(cellfun(@(d) strcmp(d.term.value.name, 'food deprivation plate'), toDep));
            testCase.verifyNumElements(toDep, 1);
            testCase.verifyEqual(toDep{1}.interaction.method.name, 'agar plug transfer');
        end

        function testObservations(testCase)
            % stage 9 (decision #59): one ambient temperature and one relative
            % humidity reading per filmed assay plate, by the probe, over the
            % plate's recordings. Filmed: 11 (twice), 12, 14 (13's video is not
            % on disk).
            testCase.assumeTrue(ndi.setup.V2.schemaHasField('humidity', 'value'), ...
                'DID_SCHEMA_PATH does not hold a schema with `humidity` (did-schema PR #86)');
            result = testCase.write("concentration_0001", ["metadata", "observations"]);
            c = result.written{1}.observations.counts;
            testCase.verifyEqual([c.temperature, c.humidity], [3 3]);
            testCase.verifyEmpty(result.written{1}.observations.skipped);

            docs = testCase.documents(result.sessions.path{1});
            classes = cellfun(@(d) d.document_class.class_name, docs, 'UniformOutput', false);
            byId = containers.Map(cellfun(@(d) d.base.id, docs, 'UniformOutput', false), docs);
            subj = docs(strcmp(classes, 'subject'));
            idOf = containers.Map(cellfun(@(d) d.subject.local_identifier, subj, 'UniformOutput', false), ...
                cellfun(@(d) d.base.id, subj, 'UniformOutput', false));
            on = @(set, local) set(cellfun(@(a) strcmp(edge(a, 'entity_id'), idOf(local)), set));
            tobs = docs(strcmp(classes, 'temperature_observation'));
            hobs = docs(strcmp(classes, 'humidity_observation'));
            probe = result.metadata.ids('temperature_probe_1');

            % plate 12, filmed once: its video's own UTC reference
            t12 = on(tobs, 'concentration_assayPlate0012');
            h12 = on(hobs, 'concentration_assayPlate0012');
            testCase.verifyNumElements(t12, 1);
            testCase.verifyNumElements(h12, 1);
            testCase.verifyEqual(t12{1}.temperature.value.celsius, 21.62, 'AbsTol', 1e-9);
            testCase.verifyEqual(h12{1}.humidity.value.percent_relative_humidity, 52, 'AbsTol', 1e-9);
            testCase.verifyEqual(t12{1}.statement.variable.name, 'Environmental Temperature');
            testCase.verifyEqual(t12{1}.statement.variable.node, 'NCIT:C90380');
            testCase.verifyEqual(h12{1}.statement.variable.name, 'relative humidity');
            testCase.verifyEqual(h12{1}.statement.variable.node, 'om:RelativeHumidity');
            testCase.verifyEqual(edge(t12{1}, 'instrument_id'), probe);
            testCase.verifyEqual(edge(t12{1}, 'time_reference_id'), edge(h12{1}, 'time_reference_id'));
            recs = on(docs(strcmp(classes, 'intensity_observation')), 'concentration_assayPlate0012');
            testCase.verifyTrue(any(cellfun(@(d) ismember(edge(t12{1}, 'time_reference_id'), ...
                edgeAll(d, 'time_reference_id')), recs)), 'the reading is timed by its video');
            % and its recordings name their camera (stage 5; decision #59's fix)
            cams = unique(cellfun(@(d) edge(d, 'instrument_id'), recs, 'UniformOutput', false));
            testCase.verifyEqual(reshape(cams, 1, []), {result.metadata.ids('camera_2')});

            % plate 11, filmed twice: one reading, over both videos
            t11 = on(tobs, 'concentration_assayPlate0011');
            testCase.verifyNumElements(t11, 1);
            w = byId(edge(t11{1}, 'time_reference_id'));
            testCase.verifyEqual(w.document_class.class_name, 'absolute_time_reference');
            vids = on(docs(strcmp(classes, 'intensity_observation')), 'concentration_assayPlate0011');
            testCase.verifyFalse(any(cellfun(@(d) ismember(w.base.id, edgeAll(d, 'time_reference_id')), vids)), ...
                'a window of its own, not either video''s');

            testCase.verifyEmpty(on(tobs, 'concentration_assayPlate0013'), 'its video is not on disk');
        end

        function testGeometry(testCase)
            % stage 10 part A (decision #60): per behaviour video on disk (plate
            % 11 twice, 12, 14), the lab's coordinate system, masks, nearest
            % patch and lawn clip registration, each a calculation of the
            % plate from its video, the masks and maps INGESTED into the session
            result = testCase.write("concentration_0001", ["metadata", "calculations"]);
            ge = result.written{1}.geometry;
            c = ge.counts;
            testCase.verifyEqual([c.coordinate_system, c.arena, c.reference_mark, c.lawn], [4 4 3 4], ...
                'plate 14''s reference mark mask is empty, so none');
            testCase.verifyEqual(c.registration, 3, 'the three videos of plates with a lawn clip');
            hasItem = ndi.setup.V2.schemaHasField('item', 'value');
            testCase.verifyEqual(c.nearest_patch, 4 * hasItem);

            sessionPath = result.sessions.path{1};
            docs = testCase.documents(sessionPath);
            classes = cellfun(@(d) d.document_class.class_name, docs, 'UniformOutput', false);
            byId = containers.Map(cellfun(@(d) d.base.id, docs, 'UniformOutput', false), docs);
            subj = docs(strcmp(classes, 'subject'));
            idOf = containers.Map(cellfun(@(d) d.subject.local_identifier, subj, 'UniformOutput', false), ...
                cellfun(@(d) d.base.id, subj, 'UniformOutput', false));
            ids = result.metadata.ids;

            % plate 12's video: its coordinate system is on the recording
            rec = docs(strcmp(classes, 'intensity_observation'));
            rec = rec(cellfun(@(d) strcmp(edge(d, 'entity_id'), idOf('concentration_assayPlate0012')), rec));
            cs = docs(strcmp(classes, 'coordinate_system'));
            cs = cs(cellfun(@(d) any(strcmp(edge(d, 'referent_id'), cellfun(@(r) r.base.id, rec, ...
                'UniformOutput', false))), cs));
            testCase.verifyNumElements(cs, 1);
            dims = cs{1}.coordinate_system.dimensions;
            testCase.verifyEqual(dims(1).axis.node, 'STATO:0000006', 'x-axis');
            testCase.verifyEqual(dims(2).axis.node, 'STATO:0000008', 'y-axis');
            testCase.verifyEqual(dims(1).positive_direction.name, 'image right');
            testCase.verifyEqual(dims(1).positive_direction.node, 'EMPTY:0000311');
            testCase.verifyEqual(dims(2).positive_direction.name, 'image down');
            testCase.verifyEqual(dims(2).positive_direction.node, 'EMPTY:0000312');
            testCase.verifyEqual(cs{1}.coordinate_system.origin.node, 'EMPTY:0000310', ...
                'image upper-left corner');
            testCase.verifyEqual(dims(1).spacing.meters, 1e-3 / 33, 'AbsTol', 1e-15);
            video = byId(edge(cs{1}, 'referent_id'));

            % each patch's center, radius and circularity, per video (decision
            % #70): one patch per plate, at lawnCenters [0 0] (pixel centers are
            % 1-based, the system's origin the corner: -0.5), radius 0 px, 0.9
            testCase.verifyEqual([c.patch_center, c.patch_radius, c.patch_circularity], [4 4 4]);
            patch = idOf('concentration_assayPlate0012_patch0001');
            about = @(cls, var) docs(cellfun(@(d) strcmp(d.document_class.class_name, cls) ...
                && strcmp(d.statement.variable.name, var) && strcmp(edge(d, 'entity_id'), patch), docs));
            center = about('position_calculation', 'position');
            testCase.verifyNumElements(center, 1);
            testCase.verifyEqual(center{1}.statement.variable.node, 'PATO:0000140');
            testCase.verifyEqual(center{1}.position.value(1).coordinates(:)', [-0.5 -0.5]);
            testCase.verifyEqual(edge(center{1}, 'coordinate_system_id'), cs{1}.base.id, ...
                'in the video''s own coordinate system');
            testCase.verifyEqual(edgeAll(center{1}, 'input_id'), {video.base.id});
            radius = about('length_calculation', 'radius');
            testCase.verifyNumElements(radius, 1);
            testCase.verifyEqual(radius{1}.statement.variable.node, 'PATO:0002390');
            testCase.verifyEqual(radius{1}.length.value(1).source_unit, 'pixel');
            circ = about('score_calculation', 'circularity');
            testCase.verifyEqual(circ{1}.statement.variable.node, 'EMPTY:0000288');
            testCase.verifyEqual(circ{1}.score.value(1).score, 0.9, 'AbsTol', 1e-12);

            % its arena mask: a label calculation of the plate from the video,
            % run by the analysis package in MATLAB on macOS
            masks = docs(strcmp(classes, 'label_calculation'));
            % a mask's variable is the region, Imaging Region of Interest, not
            % how it is stored (decision #113, tenet T16); which region is the
            % condition Location, which does not repeat the variable (T19)
            arena = masks(cellfun(@(d) strcmp(d.statement.variable.name, 'Imaging Region of Interest') ...
                && strcmp(conditionTerm(d, 'Location'), 'arena') ...
                && strcmp(edge(d, 'entity_id'), idOf('concentration_assayPlate0012')), masks));
            testCase.verifyNumElements(arena, 1);
            a = arena{1};
            testCase.verifyEqual(a.statement.variable.node, 'NCIT:C85402');
            cv = cellfun(@(e) e.variable.node, conditionsOf(a), 'UniformOutput', false);
            testCase.verifyEqual(cv, {'NCIT:C25341'}, 'one condition, not the variable again');
            testCase.verifyFalse(any(cellfun(@(d) strcmp(d.statement.variable.node, 'NCIT:C201530'), masks)), ...
                'no mask names its encoding as its variable');
            testCase.verifyEqual(edgeAll(a, 'input_id'), {video.base.id});
            testCase.verifyEqual(edge(a, 'software_id'), ids('haley_analysis'));
            testCase.verifyEqual(edge(a, 'interpreter_id'), ids('matlab'));
            testCase.verifyEqual(edge(a, 'operating_system_id'), ids('macos'));
            % `datum_type` was renamed `data_type` on 2026-10-08
            testCase.verifyEqual(ndi.v2.blockOf(a, 'value', 'data_type', ndi.v2.blockOf(a, 'value', 'datum_type')), 'bool');
            mp = entries(a.interaction.method_parameters);
            testCase.verifyEqual(mp{1}.variable.name, 'arena diameter');
            testCase.verifyEqual(mp{1}.variable.node, 'EMPTY:0000122');
            k = entries(a.data.keys);
            testCase.verifyEqual(cellfun(@(x) x.variable.node, k, 'UniformOutput', false), ...
                {'NCIT:C44478', 'NCIT:C44477'}, '[Y-coordinate, X-coordinate]: [row, column]');

            % its body is held by the session's database, not left in a temp file
            b = docs(strcmp(classes, 'sampled_body'));
            b = b{cellfun(@(d) strcmp(edge(d, 'owner_id'), a.base.id), b)};
            testCase.verifyEqual(b.data_body.compression, 'gzip');
            testCase.verifyEqual(b.files.file_info.locations.ingest, 1);
            testCase.verifyFalse(isfile(b.files.file_info.locations.location), 'the original is deleted');
            db = did2.database.sqlitedb(fullfile(sessionPath, '.ndi', ...
                ndi.database.implementations.database.did2sqlite.DEFAULTFILENAME()));
            held = db.filePath(b.base.id, 'body_data_0');
            db.close();
            testCase.verifyTrue(startsWith(held, fullfile(sessionPath, '.ndi')));
            tmp = [tempname '.bin.gz'];
            copyfile(held, tmp);
            raw = gunzip(tmp);
            fid = fopen(raw{1}, 'r');
            bytes = fread(fid, Inf, 'uint8=>uint8');
            fclose(fid);
            delete(tmp); delete(raw{1});
            expected = false(8); expected(2:7, 2:7) = true;
            testCase.verifyEqual(reshape(bytes, 8, 8), uint8(expected), 'column-major, as written');

            % the lawn mask: every patch was found by template, i.e. image
            % registration; no target statements were given, so its one input
            % is the video
            lawn = masks(cellfun(@(d) strcmp(d.statement.variable.name, 'Imaging Region of Interest') ...
                && strcmp(conditionTerm(d, 'Location'), 'bacterial patch') ...
                && strcmp(edge(d, 'entity_id'), idOf('concentration_assayPlate0012')), masks));
            testCase.verifyNumElements(lawn, 1);
            testCase.verifyEqual(lawn{1}.statement.variable.node, 'NCIT:C85402');
            testCase.verifyEqual(lawn{1}.interaction.method.node, 'NCIT:C80145');
            testCase.verifyFalse(isfield(lawn{1}.interaction, 'method_parameters') ...
                && ~isempty(lawn{1}.interaction.method_parameters), ...
                'the patches'' target diameter and spacing are statements, not parameters');
            testCase.verifyEqual(edgeAll(lawn{1}, 'input_id'), {video.base.id});

            % the registration fit: the overlap, from both the video and the lawn clip
            sc = docs(strcmp(classes, 'score_calculation'));
            sc = sc(cellfun(@(d) strcmp(edge(d, 'entity_id'), idOf('concentration_assayPlate0012')), sc));
            testCase.verifyNumElements(sc, 1);
            testCase.verifyEqual(sc{1}.statement.variable.node, 'NCIT:C54669', 'overlap');
            testCase.verifyEqual(sc{1}.interaction.method.node, 'NCIT:C80145', 'image registration');
            testCase.verifyEqual(sc{1}.score.value.scale.node, 'NCIT:C25514', 'fraction');
            testCase.verifyEqual(sc{1}.score.value.score, 0.98, 'AbsTol', 1e-12);
            testCase.verifyNumElements(edgeAll(sc{1}, 'input_id'), 2);

            if hasItem
                near = docs(strcmp(classes, 'item_calculation'));
                near = near(cellfun(@(d) strcmp(edge(d, 'entity_id'), idOf('concentration_assayPlate0012')), near));
                testCase.verifyNumElements(near, 1);
                testCase.verifyEqual(edgeAll(near{1}, 'item_id'), {idOf('concentration_assayPlate0012_patch0001')});
            end
        end

        function testTracks(testCase)
            % stage 10 part B (decision #61): per worm and video, one track,
            % speed, distance to the patch edge and nearest patch, keyed by the
            % 0-based video frame and the body part (the fixture tracks only
            % the midpoint, so n = 1). Videos on disk: plate 11 twice, 12, 14,
            % two worms each -> 8 of each.
            result = testCase.write("concentration_0001", ["metadata", "calculations"]);
            c = result.written{1}.tracks.counts;
            testCase.verifyEqual([c.position, c.speed, c.patch_edge_distance], [8 8 8]);
            hasItem = ndi.setup.V2.schemaHasField('item', 'value');
            testCase.verifyEqual(c.nearest_patch, 8 * hasItem);

            sessionPath = result.sessions.path{1};
            docs = testCase.documents(sessionPath);
            classes = cellfun(@(d) d.document_class.class_name, docs, 'UniformOutput', false);
            subj = docs(strcmp(classes, 'subject'));
            idOf = containers.Map(cellfun(@(d) d.subject.local_identifier, subj, 'UniformOutput', false), ...
                cellfun(@(d) d.base.id, subj, 'UniformOutput', false));
            of = @(cls, local) docs(strcmp(classes, cls) & cellfun(@(d) ...
                strcmp(edge(d, 'entity_id'), idOf(local)), docs));

            % worm 121, filmed once (plate 12)
            pos = of('position_calculation', 'concentration_worm0121');
            testCase.verifyNumElements(pos, 1);
            p = pos{1};
            testCase.verifyEqual(p.statement.variable.name, 'position');
            testCase.verifyEqual(p.statement.variable.node, 'PATO:0000140');
            testCase.verifyEqual(p.interaction.method.node, 'EMPTY:0000301', 'video tracking');
            cs = docs(strcmp(classes, 'coordinate_system'));
            testCase.verifyTrue(any(cellfun(@(d) strcmp(d.base.id, edge(p, 'coordinate_system_id')), cs)), ...
                'the positions are in their video''s coordinate system');
            k1 = entries(p.data.keys);
            testCase.verifyNumElements(k1, 3, '[video frame x body part x coordinate]');
            testCase.verifyEqual(k1{1}.variable.name, 'video frame');
            testCase.verifyEqual(k1{1}.variable.node, 'EMPTY:0000309');
            testCase.verifyEqual(k1{1}.n, 5);
            testCase.verifyEqual(k1{2}.variable.node, 'NCIT:C32221', 'Body Part');
            testCase.verifyEqual(k1{2}.n, 1, 'only the midpoint was tracked');
            testCase.verifyEqual(k1{2}.term(1).node, 'EMPTY:0000137', 'body midpoint');
            testCase.verifyEqual(k1{3}.variable.node, 'NCIT:C44465', 'coordinate');
            testCase.verifyEqual({k1{3}.term.node}, {'NCIT:C44477', 'NCIT:C44478'});
            mp = entries(p.interaction.method_parameters);
            names = cellfun(@(m) m.variable.name, mp, 'UniformOutput', false);
            testCase.verifyEqual(sort(names(:)'), {'interpolation method', 'maximum gap filled'});
            gap = mp{strcmp(names, 'interpolation method')};
            testCase.verifyEqual(gap.term.node, 'EMPTY:0000306', 'linear interpolation');

            % its bytes: x = frame + 12.1 - 0.5, y = 3.5 (pixels from the corner)
            xy = testCase.bodyValues(sessionPath, docs, classes, p.base.id, 'double');
            testCase.verifyEqual(reshape(xy, 5, 2), [(1:5)' + 12.1 - 0.5, 3.5 * ones(5, 1)], 'AbsTol', 1e-12);

            sp = of('velocity_calculation', 'concentration_worm0121');
            testCase.verifyNumElements(sp, 1);
            testCase.verifyEqual(sp{1}.statement.variable.node, 'PATO:0000008', 'speed');
            testCase.verifyEqual(sp{1}.interaction.method.node, 'OBI:0200056', 'moving average');
            testCase.verifyNumElements(entries(sp{1}.data.keys), 2, '[video frame x body part]');
            testCase.verifyEqual(edgeAll(sp{1}, 'input_id'), {p.base.id});
            v = testCase.bodyValues(sessionPath, docs, classes, sp{1}.base.id, 'double');
            testCase.verifyEqual(v(:)', 121e-6 * ones(1, 5), 'AbsTol', 1e-15, 'm/s');

            de = of('length_calculation', 'concentration_worm0121');
            testCase.verifyNumElements(de, 1);
            testCase.verifyNumElements(edgeAll(de{1}, 'input_id'), 2, 'the positions and the lawn mask');
            testCase.verifyEqual(de{1}.statement.variable.node, 'PATO:0000040', 'distance');
            cond = entries(de{1}.statement.conditions);
            testCase.verifyNumElements(cond, 1);
            testCase.verifyEqual(cond{1}.variable.node, 'NCIT:C45793', 'reference point');
            testCase.verifyEqual(cond{1}.term.node, 'EMPTY:0000276', 'nearest bacterial patch edge');
            v = testCase.bodyValues(sessionPath, docs, classes, de{1}.base.id, 'double');
            testCase.verifyEqual(v(:)', 2 * 1e-3 / 33 * ones(1, 5), 'AbsTol', 1e-15);

            if hasItem
                np = of('item_calculation', 'concentration_worm0121');
                testCase.verifyNumElements(np, 1);
                testCase.verifyEqual(np{1}.statement.variable.node, 'EMPTY:0000297');
                v = testCase.bodyValues(sessionPath, docs, classes, np{1}.base.id, 'uint8');
                testCase.verifyEqual(v(:)', uint8([0 0 255 0 0]), 'frame 3 is noTrack: the fill value');
            end
        end

        function testEcoliSession(testCase)
            result = testCase.write("ecoli_0001");
            docs = testCase.documents(result.sessions.path{1});
            classes = cellfun(@(d) d.document_class.class_name, docs, 'UniformOutput', false);
            testCase.verifyEqual(sum(strcmp(classes, 'epoch')), 4, ...
                'raw images 2, 3, background 9 and brightfield image 1 (decision #97)');
            testCase.verifyEqual(sum(strcmp(classes, 'acquisition_system')), 1, 'the microscope');
            r = docs(strcmp(classes, 'acquisition_reader'));
            testCase.verifyEqual(r{1}.acquisition_reader.reader_string, 'tiffstack');
            session = ndi.session.dir(result.sessions.path{1});
            sys = session.daqsystem_load();
            et = sys.filenavigator.epochtable();
            testCase.verifyEqual(sort({et.epoch_id}), ...
                {'ecoli_image0001', 'ecoli_image0002', 'ecoli_image0003', 'ecoli_image0009'});
            e2 = et(strcmp({et.epoch_id}, 'ecoli_image0002'));
            testCase.verifyEqual(e2.epochprobemap.type, 'wide-field-imaging');
            % the brightfield image: the same microscope, its method brightfield
            % microscopy (decisions #97, #103), so NDI rebuilds it as a
            % brightfield probe
            e1 = et(strcmp({et.epoch_id}, 'ecoli_image0001'));
            testCase.verifyEqual(e1.epochprobemap.name, 'microscope');
            testCase.verifyEqual(e1.epochprobemap.type, 'brightfield-imaging');
            testCase.verifyEqual(e1.underlying_epochs.underlying, ...
                {fullfile(testCase.Root, 'haley', 'ecoli', 'raw', '0001.tiff')});
            st = docs(strcmp(classes, 'intensity_observation'));
            how = cellfun(@(d) d.interaction.method.node, st, 'UniformOutput', false);
            testCase.verifyEqual(sum(strcmp(how, 'NCIT:C19827')), 1, ...
                'one brightfield microscopy recording');
            testCase.verifyEqual(sum(strcmp(how, 'EMPTY:0000300')), 0, ...
                'brightfield imaging is the cameras'' method, not the microscope''s');
            testCase.verifyEqual(sum(strcmp(how, 'NCIT:C16856')), 3, ...
                'three fluorescence microscopy recordings');
            testCase.verifyEqual(e2.underlying_epochs.underlying, ...
                {fullfile(testCase.Root, 'haley', 'ecoli', 'raw', '0002.tiff')}, ...
                'the epoch is the raw image (decision #64)');
            % the recording's size, read back through the object layer
            % (decision #70): rows and columns in pixels, centres at 0.5, 1.5, ...
            obs = session.database_search(ndi.v2.isaQuery('observation'));
            sizes = {};
            for i = 1:numel(obs)
                A = ndi.statement.fromDocument(session, obs{i}).axes();
                if height(A) ~= 2 || ~all(A.unit == "Pixel"), continue; end
                testCase.verifyEqual(A.variable, ["Y-Coordinate"; "X-Coordinate"]);
                testCase.verifyEqual(A.coordinates{1}, (0.5:1:A.n(1) - 0.5)');
                testCase.verifyEqual(A.n(1), A.n(2), 'the fixture''s images are square');
                sizes{end+1} = A.n(1); %#ok<AGROW>
            end
            testCase.verifyEqual(unique([sizes{:}]), [4 5], ...
                'the raw images 0001, 0002 and 0009 (4 x 4) and 0003 (5 x 5)');
        end

        function testEncounters(testCase)
            % stage 11 (decision #63): per worm, an encounter-onset list and the
            % per-encounter values keyed by it. Worm 121 (plate 12): two
            % encounters and the gap before them; worm 111 (plate 11, filmed
            % twice): one encounter in the second video.
            testCase.assumeTrue(ndi.setup.V2.schemaHasLeaf('time_calculation'), ...
                'DID_SCHEMA_PATH does not hold time_calculation (did-schema PR #87)');
            result = testCase.write("concentration_0001", ...
                ["metadata", "observations", "calculations", "encounters"]);
            c = result.written{1}.encounters.counts;
            testCase.verifyEqual([c.worms, c.encounters], [2 3]);
            testCase.verifyEmpty(result.written{1}.encounters.skipped);

            docs = testCase.documents(result.sessions.path{1});
            classes = cellfun(@(d) d.document_class.class_name, docs, 'UniformOutput', false);
            subj = docs(strcmp(classes, 'subject'));
            idOf = containers.Map(cellfun(@(d) d.subject.local_identifier, subj, 'UniformOutput', false), ...
                cellfun(@(d) d.base.id, subj, 'UniformOutput', false));
            named = @(cls, local, var) docs(strcmp(classes, cls) & cellfun(@(d) ...
                strcmp(edge(d, 'entity_id'), idOf(local)) && isfield(d, 'statement') ...
                && strcmp(d.statement.variable.name, var), docs));

            fr = 2.9991;
            list = named('time_calculation', 'concentration_worm0121', 'encounter onset time');
            testCase.verifyNumElements(list, 1);
            testCase.verifyEqual(list{1}.statement.variable.node, 'EMPTY:0000140');
            testCase.verifyEqual([list{1}.time.value.seconds], [1 3] / fr, 'AbsTol', 1e-9, ...
                'rows 2 and 4 of a one-video track: frames 2 and 4');
            testCase.verifyEqual(methodOf(list{1}), 'encounter detection');
            lk = entries(list{1}.data.keys);
            testCase.verifyEqual(lk{1}.variable.node, 'NCIT:C62143', 'keyed `encounter`');
            l111 = named('time_calculation', 'concentration_worm0111', 'encounter onset time');
            testCase.verifyEqual(l111{1}.time.value.seconds, 3671 + 1 / fr, 'AbsTol', 1e-6, ...
                'row 7 = frame 2 of the second video, which started 3671 s after the first');

            % velocityOn + velocityOff: one median speed, keyed [encounter x period]
            speeds = named('velocity_calculation', 'concentration_worm0121', 'speed');
            sp = speeds(cellfun(@(d) strcmp(methodOf(d), 'Median') && ...
                isempty(conditionTerms(d)), speeds));
            testCase.verifyNumElements(sp, 1);
            v = numbers(sp{1}.velocity.value, 'meters_per_second');
            testCase.verifyEqual(v(1:3), [10 20 60] * 1e-6, 'AbsTol', 1e-15, ...
                'column-major: during each encounter, then after');
            testCase.verifyTrue(isnan(v(4)), 'nothing after the last encounter');
            keys = entries(sp{1}.data.keys);
            testCase.verifyNumElements(keys, 2);
            testCase.verifyEqual(keys{2}.variable.name, 'encounter period');
            testCase.verifyEqual({keys{2}.term.name}, {'during the encounter', 'after the encounter'});
            testCase.verifyTrue(ismember(list{1}.base.id, edgeAll(sp{1}, 'input_id')), ...
                'a per-encounter value is computed over the encounter list');
            mn = speeds(cellfun(@(d) strcmp(methodOf(d), 'minimum observed value'), speeds));
            testCase.verifyEqual(numbers(mn{1}.velocity.value, 'meters_per_second'), [5 6] * 1e-6, 'AbsTol', 1e-15);
            testCase.verifyEqual(conditionTerms(mn{1}), {'during the encounter'});
            pk = speeds(cellfun(@(d) strcmp(methodOf(d), 'peak speed before an event'), speeds));
            testCase.verifyEqual(numbers(pk{1}.velocity.value, 'meters_per_second'), [100 110] * 1e-6, 'AbsTol', 1e-15);
            testCase.verifyEqual(conditionValues(pk{1}), [-10 0], ...
                'the window from 10 s before the onset to the onset');

            de = named('acceleration_calculation', 'concentration_worm0121', 'acceleration');
            testCase.verifyEqual(numbers(de{1}.acceleration.value, 'meters_per_second_squared'), ...
                [-40 -50] * 1e-6, 'AbsTol', 1e-15);
            testCase.verifyEqual(methodOf(de{1}), 'ordinary least squares estimation');
            testCase.verifyEqual(conditionValues(de{1}), [-1.5 6.5]);
            dist = named('length_calculation', 'concentration_worm0121', 'distance');
            on = dist(cellfun(@(d) ismember('during the encounter', conditionTerms(d)), dist));
            testCase.verifyEqual(numbers(on{1}.length.value, 'meters'), [0.1 0.2] * 1e-3, 'AbsTol', 1e-15);
            testCase.verifyTrue(ismember('nearest bacterial patch edge', conditionTerms(on{1})));

            % the encounter type: the decided terms (a label where the schema has no term_calculation)
            if ndi.setup.V2.schemaHasLeaf('term_calculation')
                lb = named('term_calculation', 'concentration_worm0121', 'encounter type');
                types = entries(lb{1}.term.value);
                testCase.verifyEqual(cellfun(@(t) t.node, types, 'UniformOutput', false), ...
                    {'EMPTY:0000293', 'EMPTY:0000294'});
            else
                lb = named('label_calculation', 'concentration_worm0121', 'encounter type');
                types = entries(lb{1}.label.value);
            end
            testCase.verifyEqual(cellfun(@(t) t.name, types, 'UniformOutput', false), {'exploit', 'sample'});
            testCase.verifyEqual(methodOf(lb{1}), 'Classification');

            % exploitPosterior and sensePosterior: two statements, one per model
            % (labelEncounters), the state a condition
            pr = named('score_calculation', 'concentration_worm0121', 'posterior probability');
            testCase.verifyNumElements(pr, 2);
            state = cellfun(@(d) conditionTerm(d, 'behavioral state'), pr, 'UniformOutput', false);
            ex = pr{strcmp(state, 'exploitation')};
            se = pr{strcmp(state, 'sensing')};
            testCase.verifyEqual(numbers(ex.score.value, 'score'), [0.9 0.2], 'AbsTol', 1e-12);
            testCase.verifyEqual(numbers(se.score.value, 'score'), [0.8 0.6], 'AbsTol', 1e-12);
            testCase.verifyEqual(ex.interaction.method.node, 'EMPTY:0000316', 'Gaussian mixture model clustering');
            testCase.verifyEqual(se.interaction.method.node, 'EMPTY:0000317', 'quadratic discriminant analysis');
            % timeSlowDown is not kept: no figure uses it
            testCase.verifyEmpty(named('time_calculation', 'concentration_worm0121', 'time to slow down'));

            % the gap before the first encounter
            g0 = speeds(cellfun(@(d) isequal(conditionTerms(d), {'before the first encounter'}), speeds));
            testCase.verifyNumElements(g0, 1);
            testCase.verifyEqual(g0{1}.velocity.value.meters_per_second, 50e-6, 'AbsTol', 1e-15);
            testCase.verifyEqual(methodOf(g0{1}), 'Median');

            % the key takes its positions from the list, once both repositories have key_id
            keys = entries(mn{1}.data.keys);
            if isfield(keys{1}, 'positions_from') && ~isempty(keys{1}.positions_from)
                testCase.verifyEqual(edgeAll(mn{1}, 'key_id'), {list{1}.base.id});
            end
            testCase.verifyEqual(keys{1}.n, 2);
        end

        function testEcoliProfiles(testCase)
            % stage 10 part C (decision #62): each analysed image's mask, and
            % each detected patch's values on its patch SUBJECT, matched by
            % position. Image 2's bwlabel order puts the bottom-left patch
            % first; the grid makes the top-left patch 1.
            result = testCase.write("ecoli_0001", ["metadata", "calculations"]);
            c = result.written{1}.ecoli.counts;
            testCase.verifyEqual([c.mask, c.matched_images, c.unmatched_images], [2 2 0]);
            testCase.verifyEqual(c.patch_values, 13 * 6, '13 patches x 6 values');
            hasItem = ndi.setup.V2.schemaHasField('item', 'value');
            testCase.verifyEqual(c.nearest_patch, double(hasItem), 'only image 2 has a closest map');

            docs = testCase.documents(result.sessions.path{1});
            classes = cellfun(@(d) d.document_class.class_name, docs, 'UniformOutput', false);
            subj = docs(strcmp(classes, 'subject'));
            idOf = containers.Map(cellfun(@(d) d.subject.local_identifier, subj, 'UniformOutput', false), ...
                cellfun(@(d) d.base.id, subj, 'UniformOutput', false));
            % every intensity is `fluorescence intensity`; borderAmplitude is
            % the one with method maximum and condition baseline = patch edge
            ic = docs(strcmp(classes, 'intensity_calculation'));
            testCase.verifyTrue(all(cellfun(@(d) strcmp(d.statement.variable.node, 'NCIT:C184706'), ic)), ...
                'all fluorescence intensity');
            border = ic(cellfun(@(d) strcmp(methodOf(d), 'maximum observed value') ...
                && strcmp(conditionTerm(d, 'Baseline'), 'bacterial patch edge'), ic));
            testCase.verifyEqual(sort(cellfun(@(d) d.base.id, border, 'UniformOutput', false)), ...
                sort({result.written{1}.ecoli.borderValues.statementId}), ...
                'stage 12 finds the border values by statement id');
            center = ic(cellfun(@(d) strcmp(conditionTerm(d, 'Location'), 'bacterial patch center'), ic));
            testCase.verifyTrue(all(cellfun(@(d) strcmp(methodOf(d), 'Arithmetic Mean'), center)));
            testCase.verifyNumElements(center, numel(border));
            amp = @(local) cellfun(@(d) d.intensity.value.arbitrary_units, border(cellfun(@(d) ...
                strcmp(edge(d, 'entity_id'), idOf(local)), border)));
            testCase.verifyEqual(amp('ecoli_plate0001_patch0001'), 102, 'row 2 is the top-left patch');
            testCase.verifyEqual(amp('ecoli_plate0001_patch0002'), 101, 'row 1 is the bottom-left patch');
            testCase.verifyEqual(amp('ecoli_plate0002_patch0001'), 500, 'the one-patch plate');

            len = docs(strcmp(classes, 'length_calculation'));
            l1 = len(cellfun(@(d) strcmp(edge(d, 'entity_id'), idOf('ecoli_plate0002_patch0001')), len));
            testCase.verifyEqual(l1{1}.length.value.meters, 0.2e-3, 'AbsTol', 1e-15);
            testCase.verifyEqual(l1{1}.statement.variable.name, 'distance');
            testCase.verifyEqual(conditionTerm(l1{1}, 'Reference Point'), 'bacterial patch edge');
            testCase.verifyEqual(conditionTerm(l1{1}, 'distance end point'), 'bacterial patch fluorescence peak');

            masks = docs(strcmp(classes, 'label_calculation'));
            testCase.verifyNumElements(masks, 2);
            plates = {idOf('ecoli_plate0001'), idOf('ecoli_plate0002')};
            testCase.verifyTrue(all(cellfun(@(d) ismember(edge(d, 'entity_id'), plates), masks)), ...
                'a mask is a calculation of its plate');
            testCase.verifyEqual(masks{1}.statement.variable.node, 'NCIT:C85402');
            testCase.verifyEqual(conditionTerm(masks{1}, 'Location'), 'bacterial patch');
            mk = entries(masks{1}.data.keys);
            testCase.verifyEqual(cellfun(@(e) e.variable.node, mk, 'UniformOutput', false), ...
                {'NCIT:C44478', 'NCIT:C44477'}, 'keyed [Y-coordinate, X-coordinate]');

            % decision #64: the TIFFs in images/ are background-normalized
            % images, calculated from the raw image and its background image
            testCase.verifyEqual([c.normalized_image, c.profiles], [2 13]);
            byMethod = @(name) ic(cellfun(@(d) strcmp(methodOf(d), name), ic));
            norm = byMethod('normalization to background illumination');
            testCase.verifyNumElements(norm, 2);
            obs = docs(strcmp(classes, 'intensity_observation'));
            rawOf = @(n) obs{cellfun(@(d) any(cellfun(@(t) strcmp(t, epochRefOf(docs, classes, n)), ...
                edgeAll(d, 'time_reference_id'))), obs)}.base.id;
            n2 = norm{cellfun(@(d) strcmp(edge(d, 'entity_id'), idOf('ecoli_plate0001')), norm)};
            testCase.verifyEqual(sort(edgeAll(n2, 'input_id')), sort({rawOf(2), rawOf(9)}), ...
                'from the raw image and its background image');
            m2 = masks{cellfun(@(d) strcmp(edge(d, 'entity_id'), idOf('ecoli_plate0001')), masks)};
            testCase.verifyEqual(edgeAll(m2, 'input_id'), {n2.base.id}, ...
                'the mask is from the normalised image');

            % the background fit's quality is not stored; each patch has its
            % circularity
            sc = docs(strcmp(classes, 'score_calculation') | strcmp(classes, 'count_calculation'));
            names = cellfun(@(d) d.statement.variable.name, sc, 'UniformOutput', false);
            testCase.verifyFalse(any(ismember(names, {'background fit r-squared', 'background outlier pixels'})));
            circ = sc(strcmp(names, 'circularity'));
            testCase.verifyNumElements(circ, 13);
            testCase.verifyEqual(circ{1}.statement.variable.node, 'EMPTY:0000288');

            % the profile curves: patch 1 (top-left) is row 2 of image 2
            curves = ic(cellfun(@(d) strcmp(methodOf(d), 'Arithmetic Mean') ...
                && strcmp(conditionTerm(d, 'Reference Point'), 'bacterial patch edge'), ic));
            testCase.verifyNumElements(curves, 13);
            p1 = curves{cellfun(@(d) strcmp(edge(d, 'entity_id'), idOf('ecoli_plate0001_patch0001')), curves)};
            k = entries(p1.data.keys);
            testCase.verifyEqual(k{1}.variable.name, 'distance');
            testCase.verifyEqual(k{1}.variable.node, 'PATO:0000040');
            testCase.verifyEqual(k{1}.n, 5);
            v = testCase.bodyValues(result.sessions.path{1}, docs, classes, p1.base.id, 'double');
            testCase.verifyEqual(v(:)', [201 202 203 204 NaN]);
            testCase.verifyEqual(edgeAll(p1, 'input_id'), {n2.base.id, m2.base.id});
        end

        function testDensity(testCase)
            % stage 12 (decision #65): the E. coli border amplitude fits, each
            % about a group of patches, and the estimates from them about the
            % C. elegans patches: each assay-plate patch at its encounters, each
            % acclimation-plate patch at the pick
            testCase.assumeTrue(ndi.setup.V2.schemaHasLeaf('time_calculation'), ...
                'DID_SCHEMA_PATH does not hold time_calculation (did-schema PR #87)');
            result = testCase.write(["ecoli_0001", "concentration_0001"], ...
                ["metadata", "observations", "calculations", "encounters", "density"]);
            de = result.density;
            c = de.counts;
            testCase.verifyEqual([c.fits, c.groups, c.members, c.inputs, c.refit_checked], ...
                [2 2 24 22 2], ['the OD600 1 fit and the joint low-OD fit, each about the 12 ' ...
                'patches of plate 1, from the 11 included values; the 200 uL fit has no image']);
            testCase.verifyTrue(any(contains(de.skipped, '200 uL')));
            testCase.verifyEqual([c.worms, c.patches], [2 2], ...
                'patch 1 of plate 12 (worm 121) and of plate 11 (worm 111)');
            testCase.verifyEqual(c.estimates, c.patches + c.acclimation_patches);
            testCase.verifyEqual(c.encounters_checked, 6);
            testCase.verifyEmpty(de.checks.encounterDisagrees, 'encounter.mat reproduces from the fits');

            dd = de.datasetDocuments;
            dc = cellfun(@ndi.v2.leafName, dd, 'UniformOutput', false);
            fits = dd(strcmp(dc, 'model_fit_calculation'));
            groups = dd(strcmp(dc, 'subject'));
            testCase.verifyNumElements(groups, 2);
            testCase.verifyEqual(sum(strcmp(dc, 'directed_relation')), 24);
            lin = newNames(fits{cellfun(@(d) strcmp(d.model_fit.value.equation, 'f = slope*t + intercept'), fits)});
            testCase.verifyTrue(ismember(edge(lin, 'entity_id'), ...
                cellfun(@(d) d.base.id, groups, 'UniformOutput', false)), 'the fit is about a group');
            testCase.verifyEqual(lin.statement.variable.node, 'NCIT:C184706');
            testCase.verifyEqual(methodOf(lin), 'ordinary least squares estimation');
            testCase.verifyEqual(lin.model_fit.value.dependent_variable.unit.node, 'EMPTY:0000261');
            co = entries(lin.model_fit.value.coefficients);
            testCase.verifyEqual(co{1}.variable.node, 'STATO:0000656');
            testCase.verifyEqual(co{1}.value, 1 / 3000, 'AbsTol', 1e-15);
            testCase.verifyEqual(co{2}.variable.node, 'STATO:0000657');
            testCase.verifyEqual(co{2}.value, 94 / 300, 'AbsTol', 1e-15);
            testCase.verifyEqual(conditionTerms(lin), {'nematode growth medium'});
            % the OD600 the patches were seeded at is the PLANNED one, said by its
            % term (decision #110, tenet T19): target seeding OD600, not OD600
            cv = cellfun(@(e) e.variable.node, conditionsOf(lin), 'UniformOutput', false);
            testCase.verifyTrue(ismember('EMPTY:0000105', cv), 'the one-OD600 fit''s target OD600');
            testCase.verifyFalse(ismember('MCO:0000059', cv), 'no measured OD600 is claimed');
            jt = fits(cellfun(@(d) strcmp(d.model_fit.value.equation, 'f = a*OD600 + b*t'), fits));
            if ~isempty(jt)
                xv = entries(newNames(jt{1}).model_fit.value.independent_variables);
                testCase.verifyEqual(xv{1}.variable.node, 'EMPTY:0000105');
                testCase.verifyEqual(xv{1}.variable.name, 'target seeding OD600');
            end
            testCase.verifyNumElements(edgeAll(lin, 'input_id'), 11, 'row 12 is excluded');

            % the estimates, about the patches of the C. elegans session
            k = find(strcmp(result.sessions.local_identifier, 'concentration_0001'));
            docs = testCase.documents(result.sessions.path{k});
            classes = cellfun(@(d) d.document_class.class_name, docs, 'UniformOutput', false);
            subj = docs(strcmp(classes, 'subject'));
            locals = cellfun(@(d) d.subject.local_identifier, subj, 'UniformOutput', false);
            idOf = containers.Map(locals, cellfun(@(d) d.base.id, subj, 'UniformOutput', false));
            about = @(id) docs(strcmp(classes, 'intensity_calculation') & cellfun(@(d) ...
                strcmp(edge(d, 'entity_id'), id) && isfield(d, 'statement') ...
                && strcmp(d.statement.variable.name, 'Fluorescence Intensity'), docs));
            e12 = about(idOf('concentration_assayPlate0012_patch0001'));
            testCase.verifyNumElements(e12, 1);
            testCase.verifyEqual(numbers(e12{1}.intensity.value, 'arbitrary_units'), ...
                94 / 300 + [74 80] / 3000, 'AbsTol', 1e-12);
            testCase.verifyEqual(methodOf(e12{1}), 'prediction from a fitted model');
            ek = entries(e12{1}.data.keys);
            testCase.verifyEqual(ek{1}.variable.name, 'encounter onset time');
            testCase.verifyEqual(ek{1}.quantity.value(:)', [1 3] / 2.9991, 'AbsTol', 1e-9, ...
                'at worm 121''s two encounter onsets');
            testCase.verifyTrue(ismember(lin.base.id, edgeAll(e12{1}, 'input_id')), ...
                'from the OD600 1 fit');
            testCase.verifyEqual(conditionValues(e12{1}), 0, 'the 0 h growth duration bin');
            testCase.verifyNumElements(about(idOf('concentration_assayPlate0011_patch0001')), 1);
            testCase.verifyEmpty(about(idOf('concentration_worm0121')), 'no estimate is about a worm');

            % an acclimation plate's patch, at the pick, when stage 4 made one
            acc = locals(~cellfun(@isempty, regexp(locals, '_acclimationPlate\d{4}_patch0001$', 'once')));
            if isempty(acc)
                testCase.verifyEqual(c.acclimation_patches, 0);
                testCase.verifyTrue(any(contains(de.skipped, 'no estimate at the pick')));
            else
                est = cellfun(@(a) about(idOf(a)), acc, 'UniformOutput', false);
                est = [est{:}];
                testCase.verifyNumElements(est, c.acclimation_patches);
                testCase.verifyGreaterThan(numel(est), 0);
                for j = 1:numel(est)
                    testCase.verifyEqual(est{j}.intensity.value.arbitrary_units, ...
                        55.7 - 0.0068 * 3060, 'AbsTol', 1e-9);
                end
            end

            % the relative density beside each estimate (decision #99): 10 x the
            % estimate / the reference, 2.5 (the fixture's one OD600 10 encounter)
            if ~ndi.setup.V2.schemaHasLeaf('concentration_calculation')
                testCase.verifyEqual(c.relative_density, 0);
                testCase.verifyTrue(any(contains(de.skipped, 'no relative density')));
                return;
            end
            testCase.verifyEqual(c.relative_density, c.estimates, 'one per estimate');
            rdOf = @(id) docs(strcmp(classes, 'concentration_calculation') & cellfun(@(d) ...
                strcmp(edge(d, 'entity_id'), id), docs));
            r12 = rdOf(idOf('concentration_assayPlate0012_patch0001'));
            testCase.verifyNumElements(r12, 1);
            testCase.verifyEqual(r12{1}.statement.variable.node, 'EMPTY:0000322');
            testCase.verifyEqual(numbers(r12{1}.concentration.value, 'source_value'), ...
                10 * (94 / 300 + [74 80] / 3000) / 2.5, 'AbsTol', 1e-12);
            testCase.verifyEqual(unique(cellfun(@(e) e.source_unit, entries(r12{1}.concentration.value), ...
                'UniformOutput', false)), {'OD600'});
            if ndi.setup.V2.schemaHasField('concentration', 'value.od600')
                testCase.verifyEqual(numbers(r12{1}.concentration.value, 'od600'), ...
                    10 * (94 / 300 + [74 80] / 3000) / 2.5, 'AbsTol', 1e-12, 'in the od600 canonical');
                v = ndi.value('concentration', r12{1}.concentration.value);
                testCase.verifyEqual(v.unit(), 'od600', 'ndi.value reads the slot the cells fill');
            end
            testCase.verifyEqual(edgeAll(r12{1}, 'input_id'), {e12{1}.base.id}, 'from its estimate');
            testCase.verifyEqual(r12{1}.interaction.method.node, 'OBI:0200169');
            pm = entries(r12{1}.interaction.method_parameters);
            pv = cellfun(@(e) e.variable.node, pm, 'UniformOutput', false);
            testCase.verifyEqual(sort(pv), sort({'EMPTY:0000323', 'EMPTY:0000105', 'EMPTY:0000324'}), ...
                'the reference, its target seeding OD600 (#110) and the floor');
            ek12 = entries(r12{1}.data.keys);
            testCase.verifyEqual(ek12{1}.variable.name, 'encounter onset time', 'keyed as its estimate');
            if ~isempty(acc)
                ra = rdOf(idOf(acc{1}));
                testCase.verifyNumElements(ra, 1);
                testCase.verifyEqual(numbers(ra{1}.concentration.value, 'source_value'), ...
                    10 * (55.7 - 0.0068 * 3060) / 2.5, 'AbsTol', 1e-9, 'at the pick, not floored');
            end
        end

        function testDataset(testCase)
            % stage 13 (decision #66): one V2 database holding the dataset-level
            % documents and both sessions, ingested; checked, and opened as NDI does
            testCase.assumeTrue(ndi.setup.V2.schemaHasLeaf('time_calculation'), ...
                'DID_SCHEMA_PATH does not hold time_calculation (did-schema PR #87)');
            result = testCase.write(["ecoli_0001", "concentration_0001"], ...
                ["metadata", "observations", "calculations", "encounters", "density", "dataset"]);
            r = result.dataset.report;
            testCase.verifyEqual(r.sessions.found, 2);
            testCase.verifyEmpty(r.sessions.notInDataset, 'each session is part_of a study of the dataset');
            testCase.verifyEmpty(r.duplicateIds);
            testCase.verifyGreaterThan(r.edges.checked, 0);
            testCase.verifyEqual(height(r.edges.dangling), 0, evalc('disp(r.edges.dangling)'));

            ds = ndi.dataset.dir(result.dataset.path);
            testCase.verifyEqual(ds.id(), result.datasetSessionId);
            [refs, ids] = ds.session_list();
            testCase.verifyEqual(sort(refs), {'concentration_0001', 'ecoli_0001'});
            s = ds.open_session(ids{strcmp(refs, 'ecoli_0001')});
            testCase.verifyNotEmpty(s.database_search(ndi.v2.isaQuery('subject')), ...
                'an ingested session reads its own documents from the dataset''s database');
            again = ndi.dataset.dir(result.dataset.path);
            testCase.verifyEqual(again.id(), result.datasetSessionId, ...
                'still the dataset after a session was opened in its folder');
            testCase.verifyNumElements(again.database_search(ndi.v2.isaQuery('model_fit_calculation')), 2, ...
                'stage 12''s fits are in the dataset');

            % the run's own record, beside the dataset
            testCase.verifyTrue(isfolder(result.runFolder), 'a run folder is made with ''Write''');
            for f = {'import_log.txt', 'import_report.mat', 'skipped.txt'}
                testCase.verifyTrue(isfile(fullfile(result.runFolder, f{1})), f{1});
            end
            rep = load(fullfile(result.runFolder, 'import_report.mat'));
            testCase.verifyFalse(rep.report.failed);
            testCase.verifyEqual(rep.report.dataset.id, result.dataset.id);
            testCase.verifySubstring(fileread(fullfile(result.runFolder, 'import_log.txt')), ...
                '== stage 13: check & write the dataset ==');

            % the verification the import's user runs afterwards: every check passes,
            % and its census is the import's own count
            v = ndi.setup.conv.haley.verifyDataset(result.dataset.path, 'Expected', result);
            testCase.verifyEmpty(v.failed, evalc('disp(v.census.differences)'));
            testCase.verifyEqual(v.census.total, sum(r.documents.byClass.GroupCount));
            testCase.verifyEqual(v.edges.dangling, 0);
            testCase.verifyGreaterThan(v.files.ingested, 0);
            testCase.verifyGreaterThan(v.hashes.checked, 0, 'ingested bodies record an MD5');

            % the term inventory: plain-text and ontology terms, with where they sit
            csv = [tempname '.csv'];
            T = ndi.setup.conv.haley.termInventory(result.dataset.path, 'OutFile', csv);
            testCase.addTeardown(@() delete(csv));
            fprintf('TERM INVENTORY (test dataset):\n%s\nEND TERM INVENTORY\n', fileread(csv));
            testCase.verifyTrue(isfile(csv));
            testCase.verifyTrue(any(T.kind == "ontology" & T.name == "Imaging Signal Intensity" ...
                & T.node == "NCIT:C221750"), 'the recordings'' variable carries its node');
            testCase.verifyTrue(any(T.kind == "ontology"), 'species carry ontology nodes');
            testCase.verifyEqual(sum(T.kind == "ontology" & T.node == ""), 0);
        end

        function testOccupiedFolderStopsTheRunFirst(testCase)
            % a session folder that already holds a database is found
            % before anything is built, not after the dataset is written
            testCase.write("concentration_0001");
            testCase.verifyError(@() ndi.setup.conv.haley.import_V2(testCase.Root, ...
                'Stages', ["sessions", "subjects", "acquisition"], ...
                'Sessions', "concentration_0001", 'OutputRoot', testCase.Out, ...
                'Write', true, 'ReadVideos', false), 'ndi:setup:conv:haley:foldersTaken');
        end

        function testUnknownSessionIsAnError(testCase)
            testCase.verifyError(@() ndi.setup.conv.haley.import_V2(testCase.Root, ...
                'Stages', "sessions", 'Sessions', "concentration_0099", ...
                'OutputRoot', testCase.Out), 'ndi:setup:conv:haley:unknownSession');
        end
    end

    methods
        function result = write(testCase, which, more)
            arguments
                testCase (1,1) ndi.unittest.setup.V2.TestHaleyWrite
                which
                more = string.empty
            end
            result = ndi.setup.conv.haley.import_V2(testCase.Root, ...
                'Stages', ["sessions", "subjects", "acquisition", "relations", more], 'Sessions', which, ...
                'OutputRoot', testCase.Out, 'Write', true, 'Overwrite', true, ...
                'ReadVideos', false);
        end

        function v = bodyValues(testCase, sessionPath, docs, classes, ownerId, precision)
            % the values of the ingested body owned by OWNERID, read back
            arguments
                testCase (1,1) ndi.unittest.setup.V2.TestHaleyWrite %#ok<INUSA> a method for call syntax; needs no state
                sessionPath {mustBeText}
                docs cell
                classes cell
                ownerId {mustBeText}
                precision {mustBeText}
            end
            b = docs(strcmp(classes, 'sampled_body'));
            b = b{cellfun(@(d) strcmp(edge(d, 'owner_id'), ownerId), b)};
            db = did2.database.sqlitedb(fullfile(sessionPath, '.ndi', ...
                ndi.database.implementations.database.did2sqlite.DEFAULTFILENAME()));
            held = db.filePath(b.base.id, 'body_data_0');
            db.close();
            tmp = [tempname '.bin.gz'];
            copyfile(held, tmp);
            raw = gunzip(tmp);
            fid = fopen(raw{1}, 'r', 'ieee-le');
            v = fread(fid, Inf, [precision '=>' precision]);
            fclose(fid);
            delete(tmp); delete(raw{1});
        end

        function docs = documents(testCase, sessionPath)
            arguments
                testCase (1,1) ndi.unittest.setup.V2.TestHaleyWrite %#ok<INUSA> a method for call syntax; needs no state
                sessionPath {mustBeText}
            end
            db = did2.database.sqlitedb(fullfile(sessionPath, '.ndi', ...
                ndi.database.implementations.database.did2sqlite.DEFAULTFILENAME()));
            ids = db.allIds();
            docs = cellfun(@(i) newNames(db.get(i).documentProperties), ids, 'UniformOutput', false);
            db.close();
        end
    end
end

function d = newNames(d)
% a document as V_eta names it since 2026-10-08 (did-schema V_eta_tenets.md, T2
% amendment), whichever schema wrote it: the statement blocks lose `subject_`,
% `data_type` is `value`, and a statement's `subject_id` edge is `entity_id`
arguments
    d (1,1) struct
end
for old = {'subject_statement', 'subject_assertion', 'subject_interaction', ...
        'subject_observation', 'subject_manipulation', 'subject_calculation', 'data_type'}
    if isfield(d, old{1}) && isstruct(d.(old{1}))
        d.(ndi.v2.vetaName(old{1})) = d.(old{1});
        d = rmfield(d, old{1});
    end
end
if isfield(d, 'statement') && isfield(d, 'depends_on') && isstruct(d.depends_on)
    for k = 1:numel(d.depends_on)
        if strcmp(d.depends_on(k).name, 'subject_id'), d.depends_on(k).name = 'entity_id'; end
    end
end
% ... and as the per-leaf classes name it (did-schema
% V_eta_entity_composition_plan.md, 2026-10-08): an `observation` listing
% `temperature` is a temperature_observation, and an `entity` of type organism a
% `subject` (its fields under `subject`), so these tests read both schemas
[name, block] = ndi.v2.leafName(d);
if strcmp(block, 'entity') && ~strcmp(name, 'entity')
    d.(name) = d.entity;
    d = rmfield(d, 'entity');
end
d.document_class.class_name = name;
end

function v = edge(doc, name)
arguments
    doc (1,1) struct
    name {mustBeText}
end
v = edgeAll(doc, name);
if isempty(v)
    v = '';
else
    v = v{1};
end
end

function id = epochRefOf(docs, classes, n)
% the id of the relative time reference onto the epoch of E. coli image N
arguments
    docs cell
    classes cell
    n (1,1) {mustBeNumeric}
end
ep = docs(strcmp(classes, 'epoch'));
e = ep{cellfun(@(d) strcmp(d.epoch.local_identifier, sprintf('ecoli_image%04d', n)), ep)};
rr = docs(strcmp(classes, 'relative_time_reference'));
r = rr(cellfun(@(d) strcmp(edge(d, 'referent_id'), e.base.id), rr));
id = r{1}.base.id;
end

function name = methodOf(doc)
% a statement's method name, '' when it has none
arguments
    doc struct
end
name = '';
if isfield(doc, 'interaction') && isfield(doc.interaction, 'method') && isstruct(doc.interaction.method)
    name = doc.interaction.method.name;
end
end

function name = conditionTerm(doc, variable)
% the term name of a statement's condition VARIABLE, '' when it has none
arguments
    doc struct
    variable (1,:) char
end
name = '';
if ~isfield(doc, 'statement') || ~isfield(doc.statement, 'conditions'), return; end
c = entries(doc.statement.conditions);
for i = 1:numel(c)
    if strcmp(c{i}.variable.name, variable) && isfield(c{i}, 'term')
        name = c{i}.term.name;
        return;
    end
end
end

function c = entries(x)
% a decoded list as a cell array (jsondecode gives a struct array when its
% entries share fields, a cell array when they do not)
arguments
    x
end
if iscell(x), c = reshape(x, 1, []); else, c = num2cell(reshape(x, 1, [])); end
c = cellfun(@asEntry, c, 'UniformOutput', false);
end

function e = asEntry(e)
% a key, condition or method parameter in the one-entry shape (data_body
% AMENDMENT 3), whichever shape the schema in use stores: before it, a
% condition held term.value / count.value and a key labels / values
arguments
    e
end
if ~isstruct(e) || ~isscalar(e) || ~isfield(e, 'variable'), return; end
if isfield(e, 'term') && isstruct(e.term) && isfield(e.term, 'value') && ~isfield(e.term, 'node')
    e.term = e.term.value;
end
if isfield(e, 'labels') && ~isempty(e.labels) && (~isfield(e, 'term') || isempty(e.term))
    e.term = e.labels;
end
if isfield(e, 'values') && isstruct(e.values) && ~isempty(e.values) ...
        && (~isfield(e, 'quantity') || isempty(e.quantity))
    q = struct('value', e.values.values, 'source_value', []);
    if isfield(e.values, 'source_values'), q.source_value = e.values.source_values; end
    e.quantity = q;
end
if isfield(e, 'quantity') && isstruct(e.quantity) && isscalar(e.quantity) ...
        && isfield(e.quantity, 'value') && isstruct(e.quantity.value) && isfield(e.quantity.value, 'value')
    e.quantity = e.quantity.value;     % a condition's {value: {value, source_value}}
end
if isfield(e, 'count') && isstruct(e.count) && isfield(e.count, 'value')
    e.count = e.count.value;
end
end

function v = edgeAll(doc, name)
arguments
    doc (1,1) struct
    name {mustBeText}
end
v = {};
if ~isfield(doc, 'depends_on') || isempty(doc.depends_on)
    return;
end
d = doc.depends_on;
if iscell(d), d = [d{:}]; end
hit = d(strcmp({d.name}, name));
if isempty(hit) && strcmp(name, 'entity_id')
    hit = d(strcmp({d.name}, 'subject_id'));   % the edge's name before 2026-10-08
end
v = {hit.document_id};
v = v(~cellfun(@isempty, v));
end

function t = subjectType(byLocal, local)
arguments
    byLocal
    local {mustBeText}
end
d = byLocal(local);
t = d.subject.type.name;
end

function c = conditionsOf(doc)
% a statement's conditions, as a cell array of entries
arguments
    doc (1,1) struct
end
c = {};
if isfield(doc, 'statement') && isfield(doc.statement, 'conditions') && ~isempty(doc.statement.conditions)
    c = entries(doc.statement.conditions);
end
end

function names = conditionTerms(doc)
% the names of a statement's categorical condition values, in order
arguments
    doc (1,1) struct
end
c = conditionsOf(doc);
c = c(cellfun(@(e) isfield(e, 'term') && ~isempty(e.term), c));
names = cellfun(@(e) e.term.name, c, 'UniformOutput', false);
end

function v = conditionValues(doc)
% the numbers of a statement's numeric condition values, in order
arguments
    doc (1,1) struct
end
c = conditionsOf(doc);
c = c(cellfun(@(e) isfield(e, 'quantity') && ~isempty(e.quantity), c));
v = cellfun(@(e) e.quantity.value, c);
end

function v = numbers(x, field)
% one number per value entry of a decoded value list; NaN where the entry
% holds none (a NaN is stored as null)
arguments
    x
    field {mustBeText}
end
c = entries(x);
v = NaN(1, numel(c));
for k = 1:numel(c)
    if isfield(c{k}, field) && isnumeric(c{k}.(field)) && ~isempty(c{k}.(field))
        v(k) = c{k}.(field);
    end
end
end
