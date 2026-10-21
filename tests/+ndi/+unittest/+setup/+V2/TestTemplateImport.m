classdef TestTemplateImport < matlab.unittest.TestCase
%TESTTEMPLATEIMPORT The starter V2 importer, run end to end so it cannot rot.
%
%   ndi.setup.conv.template.import_V2 is the folder a new import is copied
%   from. These tests run it over a tiny data folder they write (one session
%   folder with a two-row source table and one recording, plus a hidden folder
%   the session rule skips), check every stage report's denominators, write
%   the dataset, and read the documents back through the object layer. They
%   also pin the template's rules: a row's error is thrown in test mode and
%   reported otherwise, an unregistered term stops the write, a correction is
%   applied only while the source reads its `was` and is recorded, the raw
%   data is never copied or written to, and stages run one at a time.
%
%   Needs did2.build (DID-matlab V2) and a did-schema #88 schema with a term
%   registry on DID_SCHEMA_PATH; without them each test is filtered, which
%   test-import-v2.yml counts as a failure.

    properties
        Root
        Raw
    end

    methods (TestMethodSetup)
        function fixture(testCase)
            testCase.assumeTrue(~isempty(which('did2.build.document')), ...
                'did2.build (DID-matlab V2) is not on the path');
            schemaPath = getenv('DID_SCHEMA_PATH');
            testCase.assumeTrue(~isempty(schemaPath) && isfile(fullfile(schemaPath, 'entity.json')) ...
                && isfile(fullfile(schemaPath, 'term_registry_meta.json')), ...
                'DID_SCHEMA_PATH does not hold a did-schema #88 schema with a term registry');
            testCase.Root = tempname;
            mkdir(testCase.Root);
            testCase.addTeardown(@() rmdir(testCase.Root, 's'));
            testCase.Raw = fullfile(testCase.Root, 'raw');
            ndi.unittest.setup.V2.TestTemplateImport.writeFixture(testCase.Raw, '21.5');
        end
    end

    methods (Test)
        function testEveryStageEndToEnd(testCase)
            out = fullfile(testCase.Root, 'out');
            before = rawListing(testCase.Raw);
            % the default spec: the shipped skeleton, all its values empty
            r = ndi.setup.conv.template.import_V2(testCase.Raw, 'OutputRoot', out, ...
                'Write', true, 'RunFolder', 'none');

            % ---- each stage's denominators: read = written + skipped + errors
            %      stage            read written skipped errors documents
            expected = {'sessions',      2, 1, 1, 0, 3; ...   % dataset, study, included_in
                        'entities',      2, 2, 0, 0, 2; ...
                        'acquisition',   2, 1, 1, 0, 5; ...   % UTC, epoch, epoch clock, statement, body
                        'manipulations', 2, 1, 1, 0, 2; ...   % its time, the statement
                        'observations',  2, 1, 1, 0, 1; ...
                        'calculations',  2, 1, 1, 0, 1};
            for k = 1:size(expected, 1)
                rep = r.reports.(expected{k, 1});
                got = [rep.read, rep.written, rep.skipped, rep.errors, rep.documents];
                testCase.verifyEqual(got, [expected{k, 2:6}], sprintf(['%s: [read written ' ...
                    'skipped errors documents]; skipped: %s; errors: %s'], expected{k, 1}, ...
                    strjoin(rep.skippedList, ' | '), strjoin(rep.errorList, ' | ')));
                testCase.verifyEqual(rep.read, rep.written + rep.skipped + rep.errors, ...
                    [expected{k, 1} ': the denominator adds up']);
            end
            testCase.verifyEmpty(r.unregisteredTerms, 'every term the template writes is registered');

            % ---- read back: the dataset links its one session -------------------
            ds = ndi.dataset.dir(r.write.path);
            [refs, ids] = ds.session_list();
            testCase.verifyEqual(refs, {'session_0001'});
            notes = ds.session_notes();
            testCase.verifyTrue(contains(notes{1}, '0 ingested and 1 linked'), notes{1});
            S = ds.open_session(ids{1});
            testCase.verifyNotEmpty(S.database_search_with_dataset(ndi.v2.isaQuery('study')), ...
                'the session, opened through its dataset, reaches the study');
            e = ndi.entity.search(S, {'local_identifier', 'session_0001_worm0001'});
            testCase.verifyNumElements(e, 1);
            w = e{1};
            testCase.verifyNumElements(w.manipulations(), 1);
            testCase.verifyNumElements(w.calculations(), 1);
            obs = w.observations({'variable', 'Environmental Temperature'});
            testCase.verifyNumElements(obs, 1);
            testCase.verifyEqual(double(obs{1}.value()), 21.5, 'AbsTol', 1e-9);
            calc = w.calculations();
            testCase.verifyEqual(double(calc{1}.value()), 0.030, 'AbsTol', 1e-12, ...
                'the diameter, 30 mm, in metres');
            testCase.verifyNumElements(calc{1}.inputs(), 1, 'computed from the recording');
            e2 = ndi.entity.search(S, {'local_identifier', 'session_0001_worm0002'});
            testCase.verifyNumElements(e2, 1, 'a row with no values is still an entity');

            % ---- the raw data: not copied, not written to ------------------------
            testCase.verifyEqual(rawListing(testCase.Raw), before, 'the raw folder is unchanged');
            copies = dir(fullfile(out, '**', 'recording_0001.mp4'));
            testCase.verifyEmpty(copies, 'the recording is recorded by location, never copied');
            body = S.database_search(ndi.v2.isaQuery('opaque_body'));
            testCase.verifyNumElements(body, 1);
            p = ndi.v2.props(body{1});
            [tf, where] = ndi.database.fun.externalFileLocation(p, 'body_data_0');
            testCase.verifyTrue(tf, 'the body names its file by location');
            testCase.verifyEqual(where, fullfile(testCase.Raw, 'session_0001', 'recording_0001.mp4'));
            testCase.verifyEqual(double(p.files.file_info.locations.ingest), 0);
        end

        function testStagesRunOneAtATime(testCase)
            r1 = ndi.setup.conv.template.import_V2(testCase.Raw, 'Stages', "sessions", 'RunFolder', 'none');
            testCase.verifyEqual(height(r1.sessions), 1);
            testCase.verifyFalse(isfield(r1, 'entities'));
            r2 = ndi.setup.conv.template.import_V2(testCase.Raw, 'Stages', "entities", ...
                'Previous', r1, 'RunFolder', 'none');
            testCase.verifyEqual(r2.reports.entities.written, 2);
            testCase.verifyEqual(r2.reports.sessions.written, 1, 'the earlier stage''s report is kept');
            testCase.verifyEqual(r2.entities.ids.session, {'session_0001'; 'session_0001'});
            testCase.verifyError(@() ndi.setup.conv.template.import_V2(testCase.Raw, ...
                'Stages', "observations", 'Previous', r2, 'RunFolder', 'none'), ...
                'ndi:setup:conv:template:stageOrder', 'observations need the acquisition stage');
        end

        function testARowErrorIsThrownInTestModeAndReportedOtherwise(testCase)
            ndi.unittest.setup.V2.TestTemplateImport.writeFixture(testCase.Raw, 'warm');
            testCase.verifyError(@() ndi.setup.conv.template.import_V2(testCase.Raw, ...
                'RunFolder', 'none'), 'ndi:setup:conv:template:rowError');
            % a normal run reports it, writes the rest, and keeps a record
            out = fullfile(testCase.Root, 'out');
            runDir = fullfile(testCase.Root, 'run');
            r = ndi.setup.conv.template.import_V2(testCase.Raw, 'OutputRoot', out, ...
                'Write', true, 'RunFolder', runDir);
            rep = r.reports.observations;
            testCase.verifyEqual([rep.read, rep.written, rep.skipped, rep.errors], [2 0 1 1]);
            testCase.verifyTrue(contains(rep.errorList{1}, 'warm'), rep.errorList{1});
            testCase.verifyTrue(isfile(fullfile(runDir, 'import_log.txt')));
            saved = load(fullfile(runDir, 'import_report.mat'));
            testCase.verifyEqual(saved.report.reports.observations.errors, 1);
            testCase.verifyFalse(saved.report.failed);
            testCase.verifyEqual(r.reports.calculations.written, 1, 'the other stages went on');
        end

        function testAnUnregisteredTermStopsTheWrite(testCase)
            spec = testCase.writeSpec(struct('observations', ...
                struct('variable', 'template test term that is not registered')));
            out = fullfile(testCase.Root, 'out');
            testCase.verifyError(@() ndi.setup.conv.template.import_V2(testCase.Raw, ...
                'Spec', spec, 'OutputRoot', out, 'Write', true, 'RunFolder', 'none'), ...
                'ndi:setup:conv:template:unregisteredTerms');
            testCase.verifyFalse(isfolder(fullfile(out, 'dataset')), 'nothing was written');
            % without 'Write' the run lists it, so one run finds them all
            r = ndi.setup.conv.template.import_V2(testCase.Raw, 'Spec', spec);
            names = {r.unregisteredTerms.name};
            testCase.verifyTrue(any(strcmp(names, 'template test term that is not registered')), ...
                strjoin(names, ', '));
        end

        function testACorrectionIsAppliedOnlyWhileTheSourceReadsWas(testCase)
            fix = struct('key', {'probe', 'stale'}, 'session', 'session_0001', 'row', 'worm0001', ...
                'column', {'temperature_C', 'diameter_mm'}, 'was', {'21.5', '99'}, ...
                'value', {'22', '31'}, 'reason', {'the probe was misread', 'fixed upstream'});
            spec = testCase.writeSpec(struct('corrections', fix));
            r = ndi.setup.conv.template.import_V2(testCase.Raw, 'Spec', spec, 'RunFolder', 'none');
            testCase.verifyNumElements(r.reports.observations.corrected, 1);
            testCase.verifyNumElements(r.reports.calculations.notCorrected, 1, ...
                'the source reads 30, not the correction''s was 99: refused');
            st = jsonencode(r.observations.documents{1}{1});
            testCase.verifyTrue(contains(st, 'Corrected from 21.5: the probe was misread (correction probe)'), st);
            testCase.verifyTrue(contains(st, '"celsius":22'), st);
            calc = jsonencode(r.calculations.documents{1}{1});
            testCase.verifyFalse(contains(calc, 'Corrected'), calc);
        end
    end

    methods
        function file = writeSpec(testCase, s)
            file = fullfile(testCase.Root, ['spec_' char(ndi.ido.unique_id()) '.json']);
            fid = fopen(file, 'w');
            fprintf(fid, '%s', jsonencode(s));
            fclose(fid);
        end
    end

    methods (Static)
        function writeFixture(raw, temperature)
            % raw/session_0001/subjects.csv: worm0001 with a recording and a
            % value in every column; worm0002 with nothing but its id.
            % raw/session_0001/recording_0001.mp4: the raw file (its bytes are
            % never opened). raw/.cache: a folder the session rule skips.
            arguments
                raw {mustBeText}
                temperature {mustBeText}
            end
            s = fullfile(raw, 'session_0001');
            if ~isfolder(s), mkdir(s); end
            if ~isfolder(fullfile(raw, '.cache')), mkdir(fullfile(raw, '.cache')); end
            writelines(["subject,recording,recorded_at,duration_s,incubated_at,incubator_C,temperature_C,diameter_mm"; ...
                "worm0001,recording_0001.mp4,2026-01-05T10:00:00,60,2026-01-05 09:00,20," + temperature + ",30"; ...
                "worm0002,,,,,,,"], fullfile(s, 'subjects.csv'));
            fid = fopen(fullfile(s, 'recording_0001.mp4'), 'w');
            fwrite(fid, uint8(1:64));
            fclose(fid);
        end
    end
end

function L = rawListing(raw)
% every path under RAW with its size and time, to show it was not touched
arguments
    raw {mustBeText}
end
d = dir(fullfile(raw, '**', '*'));
d = d(~ismember({d.name}, {'.', '..'}));
L = sort(compose("%s/%s|%d|%.8f", string({d.folder}'), string({d.name}'), [d.bytes]', [d.datenum]'));
end
