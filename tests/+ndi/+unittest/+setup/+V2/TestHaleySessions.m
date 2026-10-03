classdef TestHaleySessions < matlab.unittest.TestCase
%TESTHALEYSESSIONS Stage 3 of the Haley V2 import, over a synthetic fixture.
%
%   Writes a small stand-in for the raw data -- a tableOfContents.xlsx per
%   C. elegans study folder (column names and value formats copied from the
%   real foragingConcentration file) and an ecoli/bacteria.mat with `info`
%   and `metaData` tables -- then checks the session list and that
%   ndi.setup.V2.makeSessions creates openable sessions with the right
%   name, description and study.
%
%   Filtered (never passed) without did2.build or a V2 schema that has
%   `study` and `session.name` (did-schema PRs #78 and #79).
%
%   UNVERIFIED: written without MATLAB; test-import-v2.yml is the first run.

    properties
        Root
        Spec
    end

    methods (TestClassSetup)
        function fixture(testCase)
            testCase.assumeTrue(~isempty(which('did2.build.document')), ...
                'did2.build (DID-matlab V2) is not on the path');
            sp = getenv('DID_SCHEMA_PATH');
            testCase.assumeTrue(~isempty(sp) && isfile(fullfile(sp, 'study.json')), ...
                'DID_SCHEMA_PATH does not hold a V2 schema with `study`');
            testCase.assumeTrue(ndi.setup.V2.schemaHasField('session', 'name'), ...
                'the V2 schema has no session.name (did-schema PR #79)');

            testCase.Root = tempname;
            testCase.addTeardown(@() rmdir(testCase.Root, 's'));
            specFile = fullfile(fileparts(which('ndi.setup.conv.haley.import_V2')), ...
                'import_V2_spec.json');
            testCase.Spec = jsondecode(fileread(specFile));

            ce = fullfile(testCase.Root, 'haley', 'celegans');
            writeToc(fullfile(ce, 'foragingConcentration'), { ...
                '0001', '22-02-01', '220128_foraging_behavior', '0001-0040', ...
                'grid [OD600 = 0, 0.05, 0.1]', 'no', 'no contrast video, so patches are poorly aligned'; ...
                '0003', '22-02-16', '220210_foraging_behavior', '0081-0120', ...
                'single [OD600 = 0, 0.05]', 'yes', 'no L4 plate information'; ...
                '0014', '22-04-26', '220407_foraging_behavior', '0449-0546', ...
                'grid [OD600 = 1]', 'yes', ''});
            for f = {'foragingMatching', 'foragingMini', 'foragingMutants', 'foragingSensory'}
                writeToc(fullfile(ce, f{1}), {'0001', '23-02-24', 'nb', '0001-0010', ...
                    'grid [OD600 = 1]', 'yes', ''});
            end
            ec = fullfile(testCase.Root, 'haley', 'ecoli');
            mkdir(ec);
            info = table([1; 1; 2], [1; 2; 3], 'VariableNames', {'expNum', 'plateNum'}); %#ok<NASGU>
            metaData = table([1; 1; 2], [1; 2; 3], ...
                datetime({'30-Dec-2023 09:39:10'; '31-Dec-2023 10:00:00'; '05-Jan-2024 08:00:00'}), ...
                'VariableNames', {'expNum', 'imageNum', 'acquisitionTime'}); %#ok<NASGU>
            save(fullfile(ec, 'bacteria.mat'), 'info', 'metaData');
        end
    end

    methods (Test)
        function testOneRowPerExperiment(testCase)
            T = ndi.setup.conv.haley.sessionList(testCase.Root, testCase.Spec);
            testCase.verifyEqual(height(T), 3 + 4 + 2);
            testCase.verifyEqual(numel(unique(T.local_identifier)), height(T));
            testCase.verifyTrue(ismember('concentration_0001', T.local_identifier));
            testCase.verifyTrue(ismember('ecoli_0002', T.local_identifier));
        end

        function testConcentrationSplitsIntoTwoStudies(testCase)
            T = ndi.setup.conv.haley.sessionList(testCase.Root, testCase.Spec);
            r = @(id) T(strcmp(T.local_identifier, id), :);
            testCase.verifyEqual(r('concentration_0001').study_key{1}, 'single_density_multi_patch');
            testCase.verifyEqual(r('concentration_0003').study_key{1}, 'large_single_patch');
            testCase.verifyEqual(r('sensory_0001').study_key{1}, 'sensory_mutants');
        end

        function testDayMetadataIsKept(testCase)
            T = ndi.setup.conv.haley.sessionList(testCase.Root, testCase.Spec);
            r = T(strcmp(T.local_identifier, 'concentration_0001'), :);
            testCase.verifyFalse(r.include);
            testCase.verifySubstring(r.description{1}, 'no contrast video');
            testCase.verifySubstring(r.description{1}, '220128_foraging_behavior');
            testCase.verifySubstring(r.name{1}, '1 Feb 2022');
            typo = T(strcmp(T.local_identifier, 'concentration_0014'), :);
            testCase.verifyEqual([typo.worm_first, typo.worm_last], [449 546], ...
                'the range is carried as written; stage 5 checks it against the worms');
        end

        function testChecksFlagTheSourceIndexWithoutChangingIt(testCase)
            ce = fullfile(testCase.Root, 'haley', 'celegans', 'foragingConcentration', 'videos');
            mkdir(fullfile(ce, '22-02-01'));   % the day row 0001 names
            mkdir(fullfile(ce, '22-12-31'));   % a day no row names
            [T, checks] = ndi.setup.conv.haley.sessionList(testCase.Root, testCase.Spec);
            testCase.verifyEqual(height(T), 9, 'checks must not drop or alter rows');
            testCase.verifyTrue(any(contains(checks.unusedVideoDay, '22-12-31')));
            testCase.verifyTrue(any(contains(checks.noVideoFolder, '22-02-16')));
            testCase.verifyFalse(any(contains(checks.noVideoFolder, '22-02-01')));
            testCase.verifyFalse(any(contains(checks.ecoliSpread, 'experiment 1')), ...
                'fixture experiment 1 spans one day');
        end

        function testEcoliSessionsAreDatedByTheirFirstImage(testCase)
            T = ndi.setup.conv.haley.sessionList(testCase.Root, testCase.Spec);
            r = T(strcmp(T.local_identifier, 'ecoli_0001'), :);
            testCase.verifyEqual(r.date, datetime(2023, 12, 30));
            testCase.verifySubstring(r.description{1}, '2 plate(s)');
        end

        function testMakeSessionsCreatesOpenableSessions(testCase)
            studyIds = containers.Map({'single_density_multi_patch'}, {ndi.ido.unique_id()});
            T = ndi.setup.conv.haley.sessionList(testCase.Root, testCase.Spec, ...
                'StudyIds', studyIds, 'OutputRoot', fullfile(testCase.Root, 'out'));
            T = T(strcmp(T.local_identifier, 'concentration_0001'), :);
            [T, sessions] = ndi.setup.V2.makeSessions(T);
            s = ndi.session.dir(T.path{1});
            testCase.verifyEqual(s.id(), sessions{1}.id());
            testCase.verifyEqual(s.reference, 'concentration_0001');
            d = s.database_search(ndi.query('', 'isa', 'session'));
            testCase.verifySubstring(d{1}.document_properties.session.name, 'experiment 1');
            rel = s.database_search(ndi.query('', 'isa', 'directed_relation'));
            testCase.verifyNumElements(rel, 1);
        end

        function testABadTableCreatesNothing(testCase)
            T = table({'a'; 'a'}, {fullfile(testCase.Root, 'x1'); fullfile(testCase.Root, 'x2')}, ...
                'VariableNames', {'local_identifier', 'path'});
            testCase.verifyError(@() ndi.setup.V2.makeSessions(T), 'ndi:setup:V2:badSessionTable');
            testCase.verifyFalse(isfolder(fullfile(testCase.Root, 'x1')));
        end
    end
end

function writeToc(folder, rows)
if ~isfolder(folder), mkdir(folder); end
[~, name] = fileparts(folder);
T = cell2table([repmat({name}, size(rows, 1), 1), rows], 'VariableNames', ...
    {'experimentName', 'experimentNumber', 'directoryName', 'notebookName', ...
     'wormNumber', 'conditions', 'include', 'notes'});
writetable(T, fullfile(folder, 'tableOfContents.xlsx'));
end
