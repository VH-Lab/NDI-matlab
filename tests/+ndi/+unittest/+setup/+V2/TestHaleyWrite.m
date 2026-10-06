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
            testCase.Root = tempname;
            testCase.addTeardown(@() rmdir(testCase.Root, 's'));
            ndi.unittest.setup.V2.TestHaleyRecordings.writeFixture(testCase.Root);
            % the output beside the raw data (nothing is written there)
            testCase.Out = fullfile(testCase.Root, 'haley_V2');
        end
    end

    methods (Test)
        function testConcentrationSession(testCase)
            result = testCase.write("concentration_0001");
            testCase.verifyEqual(height(result.sessions), 1);
            sessionPath = result.sessions.path{1};

            docs = testCase.documents(sessionPath);
            classes = cellfun(@(d) d.document_class.class_name, docs, 'UniformOutput', false);
            count = @(c) sum(strcmp(classes, c));
            % plates 11-14, one patch each, two worms each, one cohort each
            % (decision #55); three acclimation plates (the fixture's plates
            % were picked at three times); one food deprivation plate (plate
            % 14's worms)
            testCase.verifyEqual(count('subject'), 4 + 4 + 8 + 4 + 3 + 1);
            % plate 11 twice + 12 + 14 (behaviour) + 2 lawn clips
            testCase.verifyEqual(count('epoch'), 6);
            testCase.verifyEqual(count('intensity_observation'), 6);
            testCase.verifyEqual(count('opaque_body'), 6);
            testCase.verifyEqual(count('acquisition_system'), 2, 'camera1 and camera2');
            testCase.verifyEqual(count('session'), 1);

            s = docs{strcmp(classes, 'session')};
            testCase.verifyNotEmpty(s.depends_on, 'the session names its UTC extent');

            b = docs(strcmp(classes, 'opaque_body'));
            b = b{cellfun(@(d) strcmp(d.data_body.filename, '2022-02-04_12-10-51_2.mp4'), b)};
            testCase.verifyEqual(b.data_body.format, 'video/mp4');
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
            testCase.verifyEqual(numel(rel), 4 + 8 + 4 + 4 + 1, ['4 patch part_of plate, 8 worms ' ...
                'member_of their cohort, 4 cohorts in their assay plate, 4 in their acclimation ' ...
                'plate, 1 (plate 14) in a food deprivation plate (decision #55)']);
            find1 = @(child, parent, name) rel(cellfun(@(r) ...
                strcmp(edge(r, 'child_id'), idOf(child)) && strcmp(edge(r, 'parent_id'), idOf(parent)) ...
                && strcmp(r.directed_relation.relation.name, name), rel));

            r = find1('concentration_assayPlate0012_patch0001', 'concentration_assayPlate0012', 'part_of');
            testCase.verifyNumElements(r, 1);
            testCase.verifyEmpty(edgeAll(r{1}, 'time_reference_id'), 'a patch is part of its plate, timeless');

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
            about = @(local, variable) ta(cellfun(@(a) strcmp(edge(a, 'subject_id'), idOf(local)) ...
                && strcmp(a.subject_statement.variable.name, variable), ta));

            % 4 cohorts and 4 seeded patches, each with a species and a strain;
            % plate 13 excluded
            testCase.verifyNumElements(ta, 4 * 2 + 4 * 2 + 1);
            a = about('concentration_assayPlate0012_worms', 'species');
            testCase.verifyNumElements(a, 1);
            testCase.verifyEqual(a{1}.term.value.node, 'NCBITaxon:6239');
            a = about('concentration_assayPlate0012_worms', 'strain');
            testCase.verifyNumElements(a, 1);
            testCase.verifyEqual(a{1}.term.value.name, 'N2');
            testCase.verifyEqual(edge(a{1}, 'strain_id'), result.metadata.ids('N2'), ...
                'the strain assertion names the dataset-level strain document');
            if ndi.setup.V2.schemaHasField('subject_statement', 'distributive')
                testCase.verifyTrue(logical(a{1}.subject_statement.distributive), ...
                    'stated on the cohort, it holds of each worm');
            end
            testCase.verifyEmpty(about('concentration_worm0121', 'species'), ...
                'a worm inherits its cohort''s species; it is not repeated');
            a = about('concentration_assayPlate0012_patch0001', 'strain');
            testCase.verifyNumElements(a, 1);
            testCase.verifyEqual(a{1}.term.value.name, 'OP50');
            a = about('concentration_assayPlate0012_patch0001', 'species');
            testCase.verifyEqual(a{1}.term.value.node, 'NCBITaxon:562');
            a = about('concentration_assayPlate0013', 'inclusion in analysis');
            testCase.verifyNumElements(a, 1);
            testCase.verifyEqual(a{1}.term.value.name, 'excluded');
            testCase.verifyEmpty(about('concentration_assayPlate0012', 'inclusion in analysis'));

            % subject.type, once the schema has it (#84)
            if ndi.setup.V2.schemaHasField('subject', 'type')
                type = @(local) subjectType(byLocal, local);
                testCase.verifyEqual(type('concentration_worm0121'), 'organism');
                testCase.verifyEqual(type('concentration_assayPlate0012_worms'), 'group');
                testCase.verifyEqual(type('concentration_assayPlate0012_patch0001'), 'culture');
                testCase.verifyEqual(type('concentration_assayPlate0012'), 'material');
                testCase.verifyEqual(type('concentration_0001_acclimationPlate0001'), 'material');
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
            testCase.verifyEqual(c.seed_acclimation_plate, 3);
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
            on = @(set, local) set(cellfun(@(a) strcmp(edge(a, 'subject_id'), idOf(local)), set));
            liters = @(d) d.dose.value.volume.liters;
            dm = docs(strcmp(classes, 'dose_manipulation'));

            % the patch: 0.5 uL of that day's OD600 1 dilution, at the seeding
            seed = on(dm, 'concentration_assayPlate0012_patch0001');
            testCase.verifyNumElements(seed, 1);
            testCase.verifyEqual(liters(seed{1}), 0.5e-6, 'AbsTol', 1e-15);
            testCase.verifyEqual(edge(seed{1}, 'formulation_id'), ...
                result.metadata.ids('suspension_op50_20220202_od1'));
            % the plate: 25 mL of NGM, poured before that seeding
            pour = on(dm, 'concentration_assayPlate0012');
            testCase.verifyNumElements(pour, 1);
            testCase.verifyEqual(liters(pour{1}), 0.025, 'AbsTol', 1e-12);
            testCase.verifyEqual(edge(pour{1}, 'formulation_id'), result.metadata.ids('ngm'));
            testCase.verifyEqual(pour{1}.subject_statement.variable.name, 'NGM agar');
            when = byId(edge(pour{1}, 'time_reference_id'));
            testCase.verifyEqual(when.document_class.class_name, 'relative_time_reference');
            testCase.verifyEqual(edge(when, 'referent_id'), edge(seed{1}, 'time_reference_id'));
            % the acclimation plate: 200 uL of the same dilution
            acc = on(dm, 'concentration_0001_acclimationPlate0001');
            acc = acc(cellfun(@(d) abs(liters(d) - 200e-6) < 1e-12, acc));
            testCase.verifyNumElements(acc, 1);
            testCase.verifyEqual(edge(acc{1}, 'formulation_id'), ...
                result.metadata.ids('suspension_op50_20220202_od1'));

            % plate 12: into the cold room (4 C), then room temperature (20 C)
            tm = on(docs(strcmp(classes, 'temperature_manipulation')), 'concentration_assayPlate0012');
            testCase.verifyEqual(reshape(sort(cellfun(@(d) d.temperature.value.celsius, tm)), 1, []), [4 20]);
            methods = sort(cellfun(@(d) d.subject_interaction.method.name, tm, 'UniformOutput', false));
            testCase.verifyEqual(reshape(methods, 1, []), {'ambient exposure', 'refrigeration'});

            % the cohort's moves, at its contained_in times
            tmn = docs(strcmp(classes, 'term_manipulation'));
            mine = on(tmn, 'concentration_assayPlate0012_worms');
            toAssay = mine(cellfun(@(d) strcmp(d.term.value.name, 'assay plate'), mine));
            testCase.verifyNumElements(toAssay, 1);
            testCase.verifyEqual(toAssay{1}.subject_statement.variable.name, 'location');
            testCase.verifyEqual(toAssay{1}.subject_interaction.method.name, 'agar plug transfer');
            mp = toAssay{1}.subject_interaction.method_parameters;
            if iscell(mp), mp = [mp{:}]; end
            testCase.verifyTrue(any(arrayfun(@(q) strcmp(q.variable.name, 'cleaning step'), mp)));
            dr = docs(strcmp(classes, 'directed_relation'));
            rel = dr(cellfun(@(r) strcmp(edge(r, 'child_id'), idOf('concentration_assayPlate0012_worms')) ...
                && strcmp(edge(r, 'parent_id'), idOf('concentration_assayPlate0012')), dr));
            testCase.verifyNumElements(rel, 1);
            testCase.verifyEqual(edge(toAssay{1}, 'time_reference_id'), edge(rel{1}, 'time_reference_id'), ...
                'the move is stated at the time of the relation it makes');
            fd = on(tmn, 'concentration_assayPlate0014_worms');
            fd = fd(cellfun(@(d) strcmp(d.subject_statement.variable.name, 'food availability'), fd));
            testCase.verifyNumElements(fd, 1);
            testCase.verifyEqual(fd{1}.term.value.name, 'none');
            toDep = on(tmn, 'concentration_assayPlate0014_worms');
            toDep = toDep(cellfun(@(d) strcmp(d.term.value.name, 'food deprivation plate'), toDep));
            testCase.verifyNumElements(toDep, 1);
            testCase.verifyEqual(toDep{1}.subject_interaction.method.name, 'agar plug transfer');
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
            on = @(set, local) set(cellfun(@(a) strcmp(edge(a, 'subject_id'), idOf(local)), set));
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
            testCase.verifyEqual(t12{1}.subject_statement.variable.name, 'ambient temperature');
            testCase.verifyEqual(h12{1}.subject_statement.variable.name, 'relative humidity');
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
            rec = rec(cellfun(@(d) strcmp(edge(d, 'subject_id'), idOf('concentration_assayPlate0012')), rec));
            cs = docs(strcmp(classes, 'coordinate_system'));
            cs = cs(cellfun(@(d) any(strcmp(edge(d, 'referent_id'), cellfun(@(r) r.base.id, rec, ...
                'UniformOutput', false))), cs));
            testCase.verifyNumElements(cs, 1);
            dims = cs{1}.coordinate_system.dimensions;
            testCase.verifyEqual(dims(1).positive_direction.name, 'image right');
            testCase.verifyEqual(dims(2).positive_direction.name, 'image down');
            testCase.verifyEqual(dims(1).spacing.meters, 1e-3 / 33, 'AbsTol', 1e-15);
            video = byId(edge(cs{1}, 'referent_id'));

            % its arena mask: a label calculation of the plate from the video,
            % run by the analysis package in MATLAB on macOS
            masks = docs(strcmp(classes, 'label_calculation'));
            arena = masks(cellfun(@(d) strcmp(d.subject_statement.variable.name, 'arena region') ...
                && strcmp(edge(d, 'subject_id'), idOf('concentration_assayPlate0012')), masks));
            testCase.verifyNumElements(arena, 1);
            a = arena{1};
            testCase.verifyEqual(edgeAll(a, 'input_id'), {video.base.id});
            testCase.verifyEqual(edge(a, 'software_id'), ids('haley_analysis'));
            testCase.verifyEqual(edge(a, 'interpreter_id'), ids('matlab'));
            testCase.verifyEqual(edge(a, 'operating_system_id'), ids('macos'));
            testCase.verifyEqual(a.data_type.datum_type, 'bool');
            mp = entries(a.subject_interaction.method_parameters);
            testCase.verifyEqual(mp{1}.variable.name, 'arena diameter');

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

            % the lawn mask's method: every patch was found by template
            lawn = masks(cellfun(@(d) strcmp(d.subject_statement.variable.name, 'bacterial lawn region') ...
                && strcmp(edge(d, 'subject_id'), idOf('concentration_assayPlate0012')), masks));
            testCase.verifyEqual(lawn{1}.subject_interaction.method.name, 'patch detection by template');

            % the registration fit: from both the video and the lawn clip
            sc = docs(strcmp(classes, 'score_calculation'));
            sc = sc(cellfun(@(d) strcmp(edge(d, 'subject_id'), idOf('concentration_assayPlate0012')), sc));
            testCase.verifyNumElements(sc, 1);
            testCase.verifyEqual(sc{1}.score.value.score, 0.98, 'AbsTol', 1e-12);
            testCase.verifyNumElements(edgeAll(sc{1}, 'input_id'), 2);

            if hasItem
                near = docs(strcmp(classes, 'item_calculation'));
                near = near(cellfun(@(d) strcmp(edge(d, 'subject_id'), idOf('concentration_assayPlate0012')), near));
                testCase.verifyNumElements(near, 1);
                testCase.verifyEqual(edgeAll(near{1}, 'item_id'), {idOf('concentration_assayPlate0012_patch0001')});
            end
        end

        function testTracks(testCase)
            % stage 10 part B (decision #61): per worm and video, the midpoint
            % track, speed, distance to the patch edge and nearest patch, keyed
            % by the 0-based video frame. Videos on disk: plate 11 twice, 12,
            % 14, two worms each -> 8 tracks.
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
                strcmp(edge(d, 'subject_id'), idOf(local)), docs));

            % worm 121, filmed once (plate 12)
            pos = of('position_calculation', 'concentration_worm0121');
            testCase.verifyNumElements(pos, 1);
            p = pos{1};
            testCase.verifyEqual(p.subject_statement.variable.name, 'midpoint position');
            cs = docs(strcmp(classes, 'coordinate_system'));
            testCase.verifyTrue(any(cellfun(@(d) strcmp(d.base.id, edge(p, 'coordinate_system_id')), cs)), ...
                'the positions are in their video''s coordinate system');
            k1 = entries(p.data.keys);
            testCase.verifyEqual(k1{1}.variable.name, 'video frame');
            testCase.verifyEqual(k1{1}.n, 5);
            names = cellfun(@(m) m.variable.name, entries(p.subject_interaction.method_parameters), ...
                'UniformOutput', false);
            testCase.verifyEqual(sort(names(:)'), {'gap filling', 'longest gap filled'});

            % its bytes: x = frame + 12.1 - 0.5, y = 3.5 (pixels from the corner)
            xy = testCase.bodyValues(sessionPath, docs, classes, p.base.id, 'double');
            testCase.verifyEqual(reshape(xy, 5, 2), [(1:5)' + 12.1 - 0.5, 3.5 * ones(5, 1)], 'AbsTol', 1e-12);

            sp = of('velocity_calculation', 'concentration_worm0121');
            testCase.verifyNumElements(sp, 1);
            testCase.verifyEqual(edgeAll(sp{1}, 'input_id'), {p.base.id});
            v = testCase.bodyValues(sessionPath, docs, classes, sp{1}.base.id, 'double');
            testCase.verifyEqual(v(:)', 121e-6 * ones(1, 5), 'AbsTol', 1e-15, 'm/s');

            de = of('length_calculation', 'concentration_worm0121');
            testCase.verifyNumElements(de, 1);
            testCase.verifyNumElements(edgeAll(de{1}, 'input_id'), 2, 'the positions and the lawn mask');
            v = testCase.bodyValues(sessionPath, docs, classes, de{1}.base.id, 'double');
            testCase.verifyEqual(v(:)', 2 * 1e-3 / 33 * ones(1, 5), 'AbsTol', 1e-15);

            if hasItem
                np = of('item_calculation', 'concentration_worm0121');
                testCase.verifyNumElements(np, 1);
                v = testCase.bodyValues(sessionPath, docs, classes, np{1}.base.id, 'uint8');
                testCase.verifyEqual(v(:)', uint8([0 0 255 0 0]), 'frame 3 is noTrack: the fill value');
            end
        end

        function testEcoliSession(testCase)
            result = testCase.write("ecoli_0001");
            docs = testCase.documents(result.sessions.path{1});
            classes = cellfun(@(d) d.document_class.class_name, docs, 'UniformOutput', false);
            testCase.verifyEqual(sum(strcmp(classes, 'epoch')), 3, 'raw images 2, 3 and background 9');
            testCase.verifyEqual(sum(strcmp(classes, 'acquisition_system')), 1, 'the microscope');
            r = docs(strcmp(classes, 'acquisition_reader'));
            testCase.verifyEqual(r{1}.acquisition_reader.reader_string, 'tiffstack');
            session = ndi.session.dir(result.sessions.path{1});
            sys = session.daqsystem_load();
            et = sys.filenavigator.epochtable();
            testCase.verifyEqual(sort({et.epoch_id}), {'ecoli_image0002', 'ecoli_image0003', 'ecoli_image0009'});
            e2 = et(strcmp({et.epoch_id}, 'ecoli_image0002'));
            testCase.verifyEqual(e2.epochprobemap.type, 'wide-field-imaging');
            testCase.verifyEqual(e2.underlying_epochs.underlying, ...
                {fullfile(testCase.Root, 'haley', 'ecoli', 'raw', '0002.tiff')}, ...
                'the epoch is the raw image (decision #64)');
        end

        function testEncounters(testCase)
            % stage 11 (decision #63): per worm, an encounter-onset list and the
            % per-encounter values keyed by it. Worm 121 (plate 12): two
            % encounters and the gap before them; worm 111 (plate 11, filmed
            % twice): one encounter in the second video.
            testCase.assumeTrue(isfile(fullfile(getenv('DID_SCHEMA_PATH'), 'time_calculation.json')), ...
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
                strcmp(edge(d, 'subject_id'), idOf(local)) && isfield(d, 'subject_statement') ...
                && strcmp(d.subject_statement.variable.name, var), docs));

            fr = 2.9991;
            list = named('time_calculation', 'concentration_worm0121', 'encounter onset');
            testCase.verifyNumElements(list, 1);
            testCase.verifyEqual([list{1}.time.value.seconds], [1 3] / fr, 'AbsTol', 1e-9, ...
                'rows 2 and 4 of a one-video track: frames 2 and 4');
            l111 = named('time_calculation', 'concentration_worm0111', 'encounter onset');
            testCase.verifyEqual(l111{1}.time.value.seconds, 3671 + 1 / fr, 'AbsTol', 1e-6, ...
                'row 7 = frame 2 of the second video, which started 3671 s after the first');

            sp = named('velocity_calculation', 'concentration_worm0121', 'median speed on patch');
            testCase.verifyEqual([sp{1}.velocity.value.meters_per_second], [10 20] * 1e-6, 'AbsTol', 1e-15);
            testCase.verifyTrue(ismember(list{1}.base.id, edgeAll(sp{1}, 'input_id')), ...
                'a per-encounter value is computed over the encounter list');
            de = named('acceleration_calculation', 'concentration_worm0121', 'deceleration on entry');
            testCase.verifyEqual([de{1}.acceleration.value.meters_per_second_squared], [-40 -50] * 1e-6, 'AbsTol', 1e-15);
            lb = named('label_calculation', 'concentration_worm0121', 'encounter type');
            testCase.verifyEqual({lb{1}.label.value.name}, {'exploit', 'sample'});
            pr = named('score_calculation', 'concentration_worm0121', 'probability of exploitation');
            testCase.verifyEqual([pr{1}.score.value.score], [0.9 0.2], 'AbsTol', 1e-12);
            g0 = named('velocity_calculation', 'concentration_worm0121', ...
                'median speed off patch before the first encounter');
            testCase.verifyEqual(g0{1}.velocity.value.meters_per_second, 50e-6, 'AbsTol', 1e-15);

            % the key takes its positions from the list, once both repositories have key_id
            keys = entries(sp{1}.data.keys);
            if isfield(keys{1}, 'positions_from') && ~isempty(keys{1}.positions_from)
                testCase.verifyEqual(edgeAll(sp{1}, 'key_id'), {list{1}.base.id});
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
            border = docs(strcmp(classes, 'intensity_calculation'));
            border = border(cellfun(@(d) strcmp(d.subject_statement.variable.name, 'patch border amplitude'), border));
            amp = @(local) cellfun(@(d) d.intensity.value.arbitrary_units, border(cellfun(@(d) ...
                strcmp(edge(d, 'subject_id'), idOf(local)), border)));
            testCase.verifyEqual(amp('ecoli_plate0001_patch0001'), 102, 'row 2 is the top-left patch');
            testCase.verifyEqual(amp('ecoli_plate0001_patch0002'), 101, 'row 1 is the bottom-left patch');
            testCase.verifyEqual(amp('ecoli_plate0002_patch0001'), 500, 'the one-patch plate');

            len = docs(strcmp(classes, 'length_calculation'));
            l1 = len(cellfun(@(d) strcmp(edge(d, 'subject_id'), idOf('ecoli_plate0002_patch0001')), len));
            testCase.verifyEqual(l1{1}.length.value.meters, 0.2e-3, 'AbsTol', 1e-15);

            masks = docs(strcmp(classes, 'label_calculation'));
            testCase.verifyNumElements(masks, 2);
            plates = {idOf('ecoli_plate0001'), idOf('ecoli_plate0002')};
            testCase.verifyTrue(all(cellfun(@(d) ismember(edge(d, 'subject_id'), plates), masks)), ...
                'a mask is a calculation of its plate');

            % decision #64: the TIFFs in images/ are background-normalised
            % images, calculated from the raw image and its background image
            testCase.verifyEqual([c.normalised_image, c.background_fit, c.profiles], [2 1 13]);
            ic = docs(strcmp(classes, 'intensity_calculation'));
            byVar = @(name) ic(cellfun(@(d) strcmp(d.subject_statement.variable.name, name), ic));
            norm = byVar('background-normalised fluorescence image');
            testCase.verifyNumElements(norm, 2);
            obs = docs(strcmp(classes, 'intensity_observation'));
            rawOf = @(n) obs{cellfun(@(d) any(cellfun(@(t) strcmp(t, epochRefOf(docs, classes, n)), ...
                edgeAll(d, 'time_reference_id'))), obs)}.base.id;
            n2 = norm{cellfun(@(d) strcmp(edge(d, 'subject_id'), idOf('ecoli_plate0001')), norm)};
            testCase.verifyEqual(sort(edgeAll(n2, 'input_id')), sort({rawOf(2), rawOf(9)}), ...
                'from the raw image and its background image');
            m2 = masks{cellfun(@(d) strcmp(edge(d, 'subject_id'), idOf('ecoli_plate0001')), masks)};
            testCase.verifyEqual(edgeAll(m2, 'input_id'), {n2.base.id}, ...
                'the mask is from the normalised image');

            % the background fit's quality, on the background's plate
            sc = docs(strcmp(classes, 'score_calculation'));
            rs = sc(cellfun(@(d) strcmp(d.subject_statement.variable.name, 'background fit r-squared'), sc));
            testCase.verifyNumElements(rs, 1);
            testCase.verifyEqual(rs{1}.score.value.score, 0.95);
            cc = docs(strcmp(classes, 'count_calculation'));
            testCase.verifyEqual(cc{1}.count.value.count, 7);

            % the profile curves: patch 1 (top-left) is row 2 of image 2
            curves = byVar('intensity by distance from patch edge');
            testCase.verifyNumElements(curves, 13);
            p1 = curves{cellfun(@(d) strcmp(edge(d, 'subject_id'), idOf('ecoli_plate0001_patch0001')), curves)};
            k = entries(p1.data.keys);
            testCase.verifyEqual(k{1}.variable.name, 'distance from patch edge');
            testCase.verifyEqual(k{1}.n, 5);
            v = testCase.bodyValues(result.sessions.path{1}, docs, classes, p1.base.id, 'double');
            testCase.verifyEqual(v(:)', [201 202 203 204 NaN]);
            testCase.verifyEqual(edgeAll(p1, 'input_id'), {n2.base.id, m2.base.id});
        end

        function testDensity(testCase)
            % stage 12 (decision #65): the E. coli border amplitude fits, each
            % about a group of patches, and each worm's per-encounter estimates
            testCase.assumeTrue(isfile(fullfile(getenv('DID_SCHEMA_PATH'), 'time_calculation.json')), ...
                'DID_SCHEMA_PATH does not hold time_calculation (did-schema PR #87)');
            result = testCase.write(["ecoli_0001", "concentration_0001"], ...
                ["metadata", "observations", "calculations", "encounters", "density"]);
            de = result.density;
            c = de.counts;
            testCase.verifyEqual([c.fits, c.groups, c.members, c.inputs, c.refit_checked], ...
                [2 2 24 22 2], ['the OD600 1 fit and the joint low-OD fit, each about the 12 ' ...
                'patches of plate 1, from the 11 included values; the 200 uL fit has no image']);
            testCase.verifyTrue(any(contains(de.skipped, '200 uL')));
            testCase.verifyEqual([c.worms, c.estimates], [2 4]);
            testCase.verifyEqual(c.encounters_checked, 6);
            testCase.verifyEmpty(de.checks.encounterDisagrees, 'encounter.mat reproduces from the fits');

            dd = de.datasetDocuments;
            dc = cellfun(@(d) d.document_class.class_name, dd, 'UniformOutput', false);
            fits = dd(strcmp(dc, 'model_fit_calculation'));
            groups = dd(strcmp(dc, 'subject'));
            testCase.verifyNumElements(groups, 2);
            testCase.verifyEqual(sum(strcmp(dc, 'directed_relation')), 24);
            lin = fits{cellfun(@(d) strcmp(d.model_fit.value.equation, 'f = slope*t + intercept'), fits)};
            testCase.verifyTrue(ismember(edge(lin, 'subject_id'), ...
                cellfun(@(d) d.base.id, groups, 'UniformOutput', false)), 'the fit is about a group');
            co = entries(lin.model_fit.value.coefficients);
            testCase.verifyEqual(co{1}.value, 1 / 3000, 'AbsTol', 1e-15);
            testCase.verifyEqual(co{2}.value, 94 / 300, 'AbsTol', 1e-15);
            testCase.verifyNumElements(edgeAll(lin, 'input_id'), 11, 'row 12 is excluded');

            % the estimates, in the C. elegans session
            k = find(strcmp(result.sessions.local_identifier, 'concentration_0001'));
            docs = testCase.documents(result.sessions.path{k});
            classes = cellfun(@(d) d.document_class.class_name, docs, 'UniformOutput', false);
            subj = docs(strcmp(classes, 'subject'));
            idOf = containers.Map(cellfun(@(d) d.subject.local_identifier, subj, 'UniformOutput', false), ...
                cellfun(@(d) d.base.id, subj, 'UniformOutput', false));
            named = @(local, var) docs(strcmp(classes, 'intensity_calculation') & cellfun(@(d) ...
                strcmp(edge(d, 'subject_id'), idOf(local)) && isfield(d, 'subject_statement') ...
                && strcmp(d.subject_statement.variable.name, var), docs));
            e121 = named('concentration_worm0121', 'estimated patch border amplitude');
            testCase.verifyNumElements(e121, 1);
            testCase.verifyEqual([e121{1}.intensity.value.arbitrary_units], ...
                94 / 300 + [74 80] / 3000, 'AbsTol', 1e-12);
            testCase.verifyTrue(ismember(lin.base.id, edgeAll(e121{1}, 'input_id')), ...
                'from the OD600 1 fit');
            g111 = named('concentration_worm0111', 'estimated cultivation plate border amplitude');
            testCase.verifyNumElements(g111, 1);
            testCase.verifyEqual(g111{1}.intensity.value.arbitrary_units, 55.7 - 0.0068 * 3060, 'AbsTol', 1e-9);
        end

        function testDataset(testCase)
            % stage 13 (decision #66): one V2 database holding the dataset-level
            % documents and both sessions, ingested; checked, and opened as NDI does
            testCase.assumeTrue(isfile(fullfile(getenv('DID_SCHEMA_PATH'), 'time_calculation.json')), ...
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
            testCase.verifyNotEmpty(s.database_search(ndi.query('', 'isa', 'subject')), ...
                'an ingested session reads its own documents from the dataset''s database');
            again = ndi.dataset.dir(result.dataset.path);
            testCase.verifyEqual(again.id(), result.datasetSessionId, ...
                'still the dataset after a session was opened in its folder');
            testCase.verifyNumElements(again.database_search(ndi.query('', 'isa', 'model_fit_calculation')), 2, ...
                'stage 12''s fits are in the dataset');

            % the verification the import's user runs afterwards: every check passes,
            % and its census is the import's own count
            v = ndi.setup.conv.haley.verifyDataset(result.dataset.path, 'Expected', result);
            testCase.verifyEmpty(v.failed, evalc('disp(v.census.differences)'));
            testCase.verifyEqual(v.census.total, sum(r.documents.byClass.GroupCount));
            testCase.verifyEqual(v.edges.dangling, 0);
            testCase.verifyGreaterThan(v.files.ingested, 0);
            testCase.verifyGreaterThan(v.hashes.checked, 0, 'ingested bodies record an MD5');
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
            if nargin < 3, more = string.empty; end
            result = ndi.setup.conv.haley.import_V2(testCase.Root, ...
                'Stages', ["sessions", "subjects", "acquisition", "relations", more], 'Sessions', which, ...
                'OutputRoot', testCase.Out, 'Write', true, 'Overwrite', true, ...
                'ReadVideos', false);
        end

        function v = bodyValues(~, sessionPath, docs, classes, ownerId, precision)
            % the values of the ingested body owned by OWNERID, read back
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

        function docs = documents(~, sessionPath)
            db = did2.database.sqlitedb(fullfile(sessionPath, '.ndi', ...
                ndi.database.implementations.database.did2sqlite.DEFAULTFILENAME()));
            ids = db.allIds();
            docs = cellfun(@(i) db.get(i).documentProperties, ids, 'UniformOutput', false);
            db.close();
        end
    end
end

function v = edge(doc, name)
v = edgeAll(doc, name);
if isempty(v)
    v = '';
else
    v = v{1};
end
end

function id = epochRefOf(docs, classes, n)
% the id of the relative time reference onto the epoch of E. coli image N
ep = docs(strcmp(classes, 'epoch'));
e = ep{cellfun(@(d) strcmp(d.epoch.local_identifier, sprintf('ecoli_image%04d', n)), ep)};
rr = docs(strcmp(classes, 'relative_time_reference'));
r = rr(cellfun(@(d) strcmp(edge(d, 'referent_id'), e.base.id), rr));
id = r{1}.base.id;
end

function c = entries(x)
% a decoded list as a cell array (jsondecode gives a struct array when its
% entries share fields, a cell array when they do not)
if iscell(x), c = reshape(x, 1, []); else, c = num2cell(reshape(x, 1, [])); end
end

function v = edgeAll(doc, name)
v = {};
if ~isfield(doc, 'depends_on') || isempty(doc.depends_on)
    return;
end
d = doc.depends_on;
if iscell(d), d = [d{:}]; end
hit = d(strcmp({d.name}, name));
v = {hit.document_id};
v = v(~cellfun(@isempty, v));
end

function t = subjectType(byLocal, local)
d = byLocal(local);
t = d.subject.type.name;
end
