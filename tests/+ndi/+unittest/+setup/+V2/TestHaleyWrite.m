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
            % plates (the fixture's plates were picked at three times)
            testCase.verifyEqual(count('subject'), 4 + 4 + 8 + 3);
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
                'Stages', ["sessions", "subjects", "acquisition"], 'Sessions', which, ...
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
