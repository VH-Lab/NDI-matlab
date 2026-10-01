classdef TestHaleyWrite < matlab.unittest.TestCase
%TESTHALEYWRITE The Haley V2 import, written: one C. elegans session and one
%E. coli session, over TestHaleyRecordings' synthetic fixture.
%
%   Runs import_V2 with 'Write', true and 'Sessions' set, then reads the
%   session back: the documents in its V2 database, the epoch folders with
%   their hard links and probe maps, and the acquisition systems as NDI
%   rebuilds them (daqsystem_load). The placeholder videos are not real
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
            % the output beside the raw data: one volume, so hard links work
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
            testCase.verifyFalse(isfield(b, 'files') && ~isempty(b.files), ...
                'the recording is not held in the database');

            % the epoch folder: a hard link to the raw file, and its probe map
            e = fullfile(sessionPath, 'concentration_2022-02-04_12-10-51_2');
            testCase.verifyTrue(isfile(fullfile(e, '2022-02-04_12-10-51_2.mp4')));
            map = fileread(fullfile(e, '2022-02-04_12-10-51_2.epochprobemap.ndi'));
            subj = docs(strcmp(classes, 'subject'));
            plate = subj{cellfun(@(d) strcmp(d.subject.local_identifier, ...
                'concentration_assayPlate0012'), subj)};
            testCase.verifySubstring(map, sprintf('camera2\t1\tbrightfield-imaging\tcamera2:image1\t%s', ...
                plate.base.id));

            % NDI rebuilds both cameras from the session's own database
            session = ndi.session.dir(sessionPath);
            sys = session.daqsystem_load('name', '(.*)');
            if ~iscell(sys), sys = {sys}; end
            names = sort(cellfun(@(x) x.name, sys, 'UniformOutput', false));
            testCase.verifyEqual(names, {'camera1', 'camera2'});
            testCase.verifyClass(sys{1}, 'ndi.daq.system.image');
            testCase.verifyClass(sys{1}.filenavigator, 'ndi.file.navigator.epochdir');
        end

        function testEcoliSession(testCase)
            result = testCase.write("ecoli_0001");
            docs = testCase.documents(result.sessions.path{1});
            classes = cellfun(@(d) d.document_class.class_name, docs, 'UniformOutput', false);
            testCase.verifyEqual(sum(strcmp(classes, 'epoch')), 2, 'images 2 and 3');
            testCase.verifyEqual(sum(strcmp(classes, 'acquisition_system')), 1, 'the microscope');
            r = docs(strcmp(classes, 'acquisition_reader'));
            testCase.verifyEqual(r{1}.acquisition_reader.reader_string, 'tiffstack');
            testCase.verifyTrue(isfile(fullfile(result.sessions.path{1}, 'ecoli_image0002', '0002.tiff')));
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
