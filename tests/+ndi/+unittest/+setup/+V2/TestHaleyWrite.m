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
            % plates 11-14, one patch each, two worms each; three acclimation
            % plates (the fixture's plates were picked at three times); one
            % food deprivation plate (plate 14's worms)
            testCase.verifyEqual(count('subject'), 4 + 4 + 8 + 3 + 1);
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
            testCase.verifyEqual(numel(rel), 4 + 8 + 8 + 2, ['4 patch part_of plate, 8 worms ' ...
                'in their assay plate, 8 in their acclimation plate, 2 (plate 14) in a food deprivation plate']);
            find1 = @(child, parent, name) rel(cellfun(@(r) ...
                strcmp(edge(r, 'child_id'), idOf(child)) && strcmp(edge(r, 'parent_id'), idOf(parent)) ...
                && strcmp(r.directed_relation.relation.name, name), rel));

            r = find1('concentration_assayPlate0012_patch0001', 'concentration_assayPlate0012', 'part_of');
            testCase.verifyNumElements(r, 1);
            testCase.verifyEmpty(edgeAll(r{1}, 'time_reference_id'), 'a patch is part of its plate, timeless');

            % worm 121 was on assay plate 12 while it was filmed: from its
            % first behaviour video, 2022-02-04 12:10:51 Los Angeles = 20:10:51 UTC
            r = find1('concentration_worm0121', 'concentration_assayPlate0012', 'contained_in');
            testCase.verifyNumElements(r, 1);
            t = edgeAll(r{1}, 'time_reference_id');
            testCase.verifyNumElements(t, 1);
            ref = byId(t{1});
            testCase.verifyEqual(ref.absolute_time_reference.value.start.utc, '2022-02-04T20:10:51.000Z');
            testCase.verifyTrue(logical(ref.absolute_time_reference.value.start.approximate), ...
                'the transfer was a few minutes before filming: the start is approximate');
            testCase.verifyTrue(logical(ref.absolute_time_reference.value.duration.approximate), ...
                'an approximate start makes the extent approximate');

            % ... and on its acclimation plate from the pick time (the day
            % before, 12:10:51) until filming, that end approximate
            r = find1('concentration_worm0121', 'concentration_0001_acclimationPlate0001', 'contained_in');
            testCase.verifyNumElements(r, 1);
            t = edgeAll(r{1}, 'time_reference_id');
            ref = byId(t{1});
            testCase.verifyEqual(ref.absolute_time_reference.value.start.utc, '2022-02-03T20:10:51.000Z');
            testCase.verifyEqual(ref.absolute_time_reference.value.duration.seconds, 86400, 'AbsTol', 1e-6);
            testCase.verifyTrue(logical(ref.absolute_time_reference.value.duration.approximate));
            testCase.verifyTrue(logical(ref.absolute_time_reference.value.start.approximate), ...
                'the pick time was written by hand: approximate');

            % plate 14 was food-deprived: acclimation plate (picked the day
            % before, 15:17:10) -> food deprivation plate (12:17:10, 3 h before
            % filming) -> assay plate (filmed from 15:17:10)
            r = find1('concentration_worm0141', 'concentration_0001_foodDeprivationPlate0001', 'contained_in');
            testCase.verifyNumElements(r, 1);
            t = edgeAll(r{1}, 'time_reference_id');
            ref = byId(t{1});
            testCase.verifyEqual(ref.absolute_time_reference.value.start.utc, '2022-02-04T20:17:10.000Z');
            testCase.verifyEqual(ref.absolute_time_reference.value.duration.seconds, 3 * 3600, 'AbsTol', 1e-6);
            r = find1('concentration_worm0141', 'concentration_0001_acclimationPlate0003', 'contained_in');
            testCase.verifyNumElements(r, 1);
            t = edgeAll(r{1}, 'time_reference_id');
            ref = byId(t{1});
            testCase.verifyEqual(ref.absolute_time_reference.value.duration.seconds, 21 * 3600, 'AbsTol', 1e-6, ...
                'the acclimation window ends when the worms move to the food deprivation plate');
            testCase.verifyTrue(logical(ref.absolute_time_reference.value.duration.approximate), ...
                'the pick (its start) is approximate, so the extent is');

            % plate 13 was never filmed: its worms are in it, with no time
            r = find1('concentration_worm0131', 'concentration_assayPlate0013', 'contained_in');
            testCase.verifyNumElements(r, 1);
            testCase.verifyEmpty(edgeAll(r{1}, 'time_reference_id'));
        end

        function testEcoliSession(testCase)
            result = testCase.write("ecoli_0001");
            docs = testCase.documents(result.sessions.path{1});
            classes = cellfun(@(d) d.document_class.class_name, docs, 'UniformOutput', false);
            testCase.verifyEqual(sum(strcmp(classes, 'epoch')), 2, 'images 2 and 3');
            testCase.verifyEqual(sum(strcmp(classes, 'acquisition_system')), 1, 'the microscope');
            r = docs(strcmp(classes, 'acquisition_reader'));
            testCase.verifyEqual(r{1}.acquisition_reader.reader_string, 'tiffstack');
            session = ndi.session.dir(result.sessions.path{1});
            sys = session.daqsystem_load();
            et = sys.filenavigator.epochtable();
            testCase.verifyEqual({et.epoch_id}, {'ecoli_image0002', 'ecoli_image0003'});
            testCase.verifyEqual(et(1).epochprobemap.type, 'wide-field-imaging');
            testCase.verifyEqual(et(1).underlying_epochs.underlying, ...
                {fullfile(testCase.Root, 'haley', 'ecoli', 'images', '0002.tiff')});
        end

        function testUnknownSessionIsAnError(testCase)
            testCase.verifyError(@() ndi.setup.conv.haley.import_V2(testCase.Root, ...
                'Stages', "sessions", 'Sessions', "concentration_0099", ...
                'OutputRoot', testCase.Out), 'ndi:setup:conv:haley:unknownSession');
        end
    end

    methods
        function result = write(testCase, which)
            result = ndi.setup.conv.haley.import_V2(testCase.Root, ...
                'Stages', ["sessions", "subjects", "acquisition", "relations"], 'Sessions', which, ...
                'OutputRoot', testCase.Out, 'Write', true, 'Overwrite', true, ...
                'ReadVideos', false);
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
