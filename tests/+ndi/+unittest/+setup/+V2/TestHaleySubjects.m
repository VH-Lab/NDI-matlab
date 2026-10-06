classdef TestHaleySubjects < matlab.unittest.TestCase
%TESTHALEYSUBJECTS Stage 4 of the Haley V2 import (subjects), over a synthetic fixture.
%
%   Writes a small stand-in for the raw data -- a tableOfContents.xlsx and
%   an experimentInfo.mat `info` table per C. elegans folder (column names
%   and types as in the real files), and ecoli/bacteria.mat with `info` and
%   `metaData` -- then checks the subjects listed for each session, their
%   identifiers, the acclimation-plate numbering and the source checks.
%
%   Needs no schema and no did2: it builds no documents.

    properties
        Root
        Spec
    end

    methods (TestClassSetup)
        function fixture(testCase)
            testCase.Root = tempname;
            testCase.addTeardown(@() rmdir(testCase.Root, 's'));
            specFile = fullfile(fileparts(which('ndi.setup.conv.haley.import_V2')), ...
                'import_V2_spec.json');
            testCase.Spec = jsondecode(fileread(specFile));
            ce = fullfile(testCase.Root, 'haley', 'celegans');

            % foragingConcentration: day 1 has plates 1 and 2 (worms 1-8, one
            % acclimation plate); day 2 has plate 3, filmed twice (worms 9-12), and
            % a tableOfContents range that is wrong (9-14). Plate 4's expNum
            % has no tableOfContents row.
            f = fullfile(ce, 'foragingConcentration');
            writeToc(f, {'0001', '22-02-01', 'nb1', '0001-0008', 'grid [OD600 = 1]', 'yes', ''; ...
                         '0002', '22-02-04', 'nb2', '0009-0014', 'grid [OD600 = 1]', 'yes', ''});
            pick1 = datetime(2022, 1, 31, 13, 4, 0);
            pick2 = datetime(2022, 2, 3, 10, 0, 0);
            writeInfo(f, [1 1 2 2 9], [1 2 3 3 4], [1 1 1 2 1], ...
                {[1 2 3 4], [5 6 7 8], [9 10 11 12], [9 10 11 12], [99 100]}, ...
                {'N2', 'N2', 'N2', 'N2', 'N2'}, [pick1 pick1 pick2 pick2 pick2], ...
                {zeros(3, 2), zeros(2, 2), zeros(1, 2), zeros(1, 2), zeros(1, 2)}, ...
                {zeros(3, 1), zeros(1, 1), zeros(1, 1), zeros(1, 1), zeros(1, 1)}, ...
                [true false false false false]);

            % foragingMutants: one day, three strains picked at two times
            % (TU253 at 10:46 on two plates, MT15434 at 10:07), and a plate
            % with no lawnCenters.
            f = fullfile(ce, 'foragingMutants');
            writeToc(f, {'0001', '23-11-03', 'nb', '0001-0020', 'grid [OD600 = 1]', 'yes', ''});
            d = datetime(2023, 11, 2);
            % Plate 5 is filmed twice and its FIRST video is a failed start
            % with no lawnCenters (as Mutants plate 1 is, 3 Nov 2023).
            writeInfo(f, [1 1 1 1 1 1], [1 2 3 4 5 5], [1 1 1 1 1 2], ...
                {[1 2 3 4], [5 6 7 8], [9 10 11 12], [13 14 15 16], [17 18 19 20], [17 18 19 20]}, ...
                {'TU253', 'MT15434', 'TU253', 'N2', 'N2', 'N2'}, ...
                [d + duration(10, 46, 0), d + duration(10, 7, 0), d + duration(10, 46, 0), ...
                 d + duration(10, 39, 0), d + duration(10, 39, 0), d + duration(10, 39, 0)], ...
                {zeros(2, 2), zeros(2, 2), zeros(2, 2), [], [], zeros(3, 2)}, ...
                {zeros(2, 1), zeros(2, 1), zeros(2, 1), [], [], zeros(3, 1)}, false(1, 6));

            % The other three folders: one day, one plate, worms matching.
            for name = {'foragingMatching', 'foragingMini', 'foragingSensory'}
                f = fullfile(ce, name{1});
                writeToc(f, {'0001', '23-02-24', 'nb', '0001-0004', 'grid [OD600 = 1]', 'yes', ''});
                writeInfo(f, 1, 1, 1, {[1 2 3 4]}, {'N2'}, datetime(2023, 2, 23, 12, 50, 0), ...
                    {zeros(1, 2)}, {zeros(1, 1)}, false);
            end
            % Matching is a grid template (multi-density): OD600 has one value
            % per template position, more than there are patches (the real
            % plates: 19 positions, the empty centre OD600 0, 18 patches), and
            % lawnClosestOD600 maps each pixel to its nearest patch's OD600.
            % Two patches, at [x y] = [10 20] and [30 40]; template [5 0 10].
            f = fullfile(ce, 'foragingMatching');
            M = zeros(50, 50);  M(20, 10) = 5;  M(40, 30) = 10;
            writeInfo(f, 1, 1, 1, {[1 2 3 4]}, {'N2'}, datetime(2023, 2, 23, 12, 50, 0), ...
                {[10 20; 30 40]}, {[1; 1]}, false, ...
                struct('OD600', {{[5 0 10]}}, 'lawnClosestOD600', {{M}}));

            % E. coli: a rectangle plate, a 'none' plate with one lawn, a
            % 'none' blank plate, and a rectangle plate with no bacteria.
            ec = fullfile(testCase.Root, 'haley', 'ecoli');
            mkdir(ec);
            info = table([1; 1; 1; 2; 2], [1; 2; 3; 4; 5], {'rectangle'; 'none'; 'none'; 'rectangle'; 'none'}, ...
                [1; 1; 0; 1; 0], [0.5; 200; 0; 0; 20], ...
                'VariableNames', {'expNum', 'plateNum', 'template', 'OD600', 'lawnVolume'}); %#ok<NASGU>
            metaData = table([1; 2], [1; 2], ...
                datetime({'30-Dec-2023 09:39:10'; '05-Jan-2024 08:00:00'}), ...
                'VariableNames', {'expNum', 'imageNum', 'acquisitionTime'}); %#ok<NASGU>
            save(fullfile(ec, 'bacteria.mat'), 'info', 'metaData');
        end
    end

    methods (Test)
        function testIdentifiersUseTheFolderPrefix(testCase)
            [S, ~] = testCase.list();
            ids = S.local_identifier;
            for want = {'concentration_assayPlate0001', 'concentration_assayPlate0001_patch0003', ...
                        'concentration_worm0012', 'concentration_0001_acclimationPlate0001', ...
                        'mutants_assayPlate0002', 'ecoli_plate0001_patch0012', 'ecoli_plate0002_patch0001'}
                testCase.verifyTrue(ismember(want{1}, ids), want{1});
            end
            testCase.verifyFalse(any(startsWith(ids, 'foraging')), ...
                'no local_identifier keeps the `foraging` prefix');
            testCase.verifyEqual(numel(unique(ids)), height(S));
        end

        function testAPlateFilmedTwiceIsOneSubject(testCase)
            [S, ~] = testCase.list();
            p3 = S(strcmp(S.local_identifier, 'concentration_assayPlate0003'), :);
            testCase.verifyEqual(height(p3), 1);
            testCase.verifySubstring(p3.description{1}, 'filmed in 2 video(s)');
            testCase.verifyEqual(sum(strcmp(S.kind, 'worm') & S.plate == 3 ...
                & strcmp(S.folder, 'foragingConcentration')), 4, 'its worms are listed once');
        end

        function testGridTemplatePatchesTakeTheirOwnDensity(testCase)
            % Matching: OD600 is the template (3 positions, 2 patches); each
            % patch's OD600 is the lawnClosestOD600 map at its centre, and the
            % template's non-zero positions agree, so nothing is reported
            [S, checks] = testCase.list();
            pk = S(strcmp(S.kind, 'patch') & strcmp(S.folder, 'foragingMatching'), :);
            testCase.verifyEqual(height(pk), 2);
            testCase.verifyEqual(arrayfun(@(j) pk.prep(j).od600, 1:2), [5 10]);
            testCase.verifyEmpty(checks.patchOD600, strjoin(checks.patchOD600, newline));
        end

        function testPatchesFollowLawnCenters(testCase)
            [S, checks] = testCase.list();
            n = @(folder, p) sum(strcmp(S.kind, 'patch') & strcmp(S.folder, folder) & S.plate == p);
            testCase.verifyEqual(n('foragingConcentration', 1), 3);
            testCase.verifyEqual(n('foragingMutants', 4), 0, 'no lawnCenters -> no patches');
            testCase.verifyEqual(n('foragingMutants', 5), 3, ...
                'a failed first video: patches come from the restart');
            testCase.verifyFalse(any(contains(checks.noLawnCenters, 'plate 5')));
            testCase.verifyTrue(any(contains(checks.noLawnCenters, 'plate 4')));
            testCase.verifyTrue(any(contains(checks.patchCountDisagrees, 'plate 2')), ...
                'Concentration plate 2 lists 2 centres and 1 radius');
        end

        function testAcclimationPlatesAreNumberedByPickTime(testCase)
            [S, ~] = testCase.list();
            g = S(strcmp(S.kind, 'acclimation_plate') & strcmp(S.session, 'mutants_0001'), :);
            testCase.verifyEqual(height(g), 3, 'one per (strain, pick time)');
            g1 = g(strcmp(g.local_identifier, 'mutants_0001_acclimationPlate0001'), :);
            testCase.verifyEqual(g1.strain{1}, 'MT15434', 'the earliest pick (10:07) is 0001');
            p1 = S(strcmp(S.local_identifier, 'mutants_assayPlate0001'), :);
            p3 = S(strcmp(S.local_identifier, 'mutants_assayPlate0003'), :);
            testCase.verifyEqual(p1.acclimation{1}, p3.acclimation{1}, 'same strain and pick -> same acclimation plate');
            w = S(strcmp(S.local_identifier, 'mutants_worm0005'), :);
            testCase.verifyEqual(w.acclimation{1}, 'mutants_0001_acclimationPlate0001');
        end

        function testSourceChecksReportWithoutChanging(testCase)
            [S, checks] = testCase.list();
            testCase.verifyTrue(any(contains(checks.plateWithoutSession, 'plate 4 (expNum 9)')));
            testCase.verifyFalse(any(strcmp(S.local_identifier, 'concentration_assayPlate0004')));
            testCase.verifyTrue(any(contains(checks.wormRange, 'concentration_0002')), ...
                'the 9-14 range against worms 9-12');
            testCase.verifyFalse(any(contains(checks.wormRange, 'concentration_0001')));
            testCase.verifyTrue(any(contains(checks.ecoliSeeding, 'plate 4')), ...
                'rectangle template with lawnVolume 0');
            testCase.verifyFalse(any(contains(checks.ecoliSeeding, 'plate 5')), ...
                'an LB-only patch is not a finding');
        end

        function testEcoliPatchesFollowTheTemplate(testCase)
            [S, ~] = testCase.list();
            n = @(p) sum(strcmp(S.kind, 'patch') & strcmp(S.folder, 'ecoli') & S.plate == p);
            testCase.verifyEqual(n(1), 12, 'rectangle: a 3 x 4 grid');
            testCase.verifyEqual(n(2), 1, 'none with bacteria: one lawn');
            testCase.verifyEqual(n(3), 0, 'none without bacteria: blank');
            p3 = S(strcmp(S.local_identifier, 'ecoli_plate0003'), :);
            testCase.verifySubstring(p3.description{1}, 'no bacteria');
            testCase.verifyEqual(n(5), 1, '20 ul of LB alone (OD600 0) is a patch');
            p5 = S(strcmp(S.local_identifier, 'ecoli_plate0005'), :);
            testCase.verifySubstring(p5.description{1}, 'LB alone');
        end

        function testNamesFollowThePaper(testCase)
            [S, ~] = testCase.list();
            nm = @(id) S.name{strcmp(S.local_identifier, id)};
            testCase.verifyEqual(nm('concentration_assayPlate0001'), 'Assay Plate 0001');
            testCase.verifyEqual(nm('concentration_assayPlate0001_patch0003'), 'Patch 0003 on Assay Plate 0001');
            testCase.verifyEqual(nm('concentration_worm0012'), 'Worm 0012');
            testCase.verifyEqual(nm('mutants_0001_acclimationPlate0001'), 'Acclimation Plate 0001');
            testCase.verifyEqual(nm('ecoli_plate0001'), 'Plate 0001');
            testCase.verifyEqual(nm('ecoli_plate0001_patch0012'), 'Patch 0012 on Plate 0001');
            testCase.verifyEqual(nm('concentration_assayPlate0001_worms'), 'Worms on Assay Plate 0001');
            testCase.verifyTrue(all(ismember(S.kind, {'assay_plate', 'acclimation_plate', 'plate', ...
                'patch', 'cohort', 'worm'})));
        end

        function testEachPlateOfWormsIsOneCohort(testCase)
            % decision #55: the worms of an assay plate, moved together, are one
            % group subject; each worm names it
            [S, ~] = testCase.list();
            c = S(strcmp(S.kind, 'cohort') & strcmp(S.folder, 'foragingConcentration'), :);
            testCase.verifyEqual(sort(c.local_identifier'), {'concentration_assayPlate0001_worms', ...
                'concentration_assayPlate0002_worms', 'concentration_assayPlate0003_worms'});
            c1 = c(strcmp(c.local_identifier, 'concentration_assayPlate0001_worms'), :);
            testCase.verifyEqual(c1.strain{1}, 'N2');
            testCase.verifyEqual(c1.acclimation{1}, 'concentration_0001_acclimationPlate0001', ...
                'the cohort carries the plates its worms were on');
            w = S(strcmp(S.local_identifier, 'concentration_worm0003'), :);
            testCase.verifyEqual(w.cohort{1}, 'concentration_assayPlate0001_worms');
            testCase.verifyEmpty(S.cohort{strcmp(S.local_identifier, 'concentration_assayPlate0001')});
        end

        function testTypesAndBacteria(testCase)
            % subject.type and each patch's bacteria (decisions #54, #55)
            [S, ~] = testCase.list();
            row = @(id) S(strcmp(S.local_identifier, id), :);
            testCase.verifyEqual(row('concentration_worm0003').type{1}, 'organism');
            testCase.verifyEqual(row('concentration_assayPlate0001_worms').type{1}, 'group');
            testCase.verifyEqual(row('concentration_assayPlate0001').type{1}, 'material');
            testCase.verifyEqual(row('mutants_0001_acclimationPlate0001').type{1}, 'material');
            testCase.verifyEqual(row('ecoli_plate0001').type{1}, 'material');
            p = row('concentration_assayPlate0001_patch0001');
            testCase.verifyEqual(p.bacteria{1}, 'OP50', 'OP50 on every C. elegans plate');
            testCase.verifyEqual(p.type{1}, 'culture');
            p = row('ecoli_plate0002_patch0001');
            testCase.verifyEqual(p.bacteria{1}, 'OP50-GFP', 'OP50-GFP on the E. coli plates');
            testCase.verifyEqual(p.type{1}, 'culture');
            p = row('ecoli_plate0005_patch0001');
            testCase.verifyEmpty(p.bacteria{1}, 'OD600 0: LB alone, no bacteria');
            testCase.verifyEqual(p.type{1}, 'material');
        end

        function testExcludeIsCarriedForTheAssertionsStage(testCase)
            [S, ~] = testCase.list();
            testCase.verifyTrue(S.exclude(strcmp(S.local_identifier, 'concentration_assayPlate0001')));
            testCase.verifyFalse(S.exclude(strcmp(S.local_identifier, 'concentration_assayPlate0002')));
        end
    end

    methods
        function [S, checks] = list(testCase)
            T = ndi.setup.conv.haley.sessionList(testCase.Root, testCase.Spec);
            [S, checks] = ndi.setup.conv.haley.subjectList(testCase.Root, T);
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

function writeInfo(folder, expNum, plateNum, videoNum, wormNum, strainID, picked, centers, radii, exclude, extra)
info = table(uint16(expNum(:)), uint16(plateNum(:)), uint16(videoNum(:)), wormNum(:), ...
    strainID(:), picked(:), centers(:), radii(:), logical(exclude(:)), ...
    'VariableNames', {'expNum', 'plateNum', 'videoNum', 'wormNum', 'strainID', ...
    'growthTimePicked', 'lawnCenters', 'lawnRadii', 'exclude'});
if nargin > 10
    for f = reshape(fieldnames(extra), 1, [])
        info.(f{1}) = reshape(extra.(f{1}), [], 1);
    end
end
save(fullfile(folder, 'experimentInfo.mat'), 'info');
end
