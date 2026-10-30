classdef StacyImportTest < matlab.unittest.TestCase
% StacyImportTest - Offline tests for the Stacy LGN import helpers in ndi.setup.conv.vhlab.
%
%   Covers stacyExperimentTable, validateStacyDirectory, the 'ValidateOnly'
%   path of importStacyExperiment, approachMappingTable and treatmentTable,
%   using a small placeholder experiment directory made by
%   ndi.test.helper.stacyFixtureDirectory. No recorded data, network or
%   ontology lookup is needed.
%
%   See also: ndi.setup.conv.vhlab.importStacyExperiment

    properties
        TempFolder
    end

    methods (TestMethodSetup)
        function makeTempFolder(testCase)
            testCase.TempFolder = tempname;
            mkdir(testCase.TempFolder);
            testCase.addTeardown(@() rmdir(testCase.TempFolder, 's'));
        end
    end

    methods (Test)
        function experimentTableIsConsistent(testCase)
            T = ndi.setup.conv.vhlab.stacyExperimentTable();
            testCase.verifyEqual(height(T), 29);
            testCase.verifyEqual(numel(unique(T.experimentDate)), 29);
            testCase.verifyEqual(sum(T.contributedCells), 25);
            testCase.verifyTrue(all(~cellfun(@isempty, ...
                regexp(cellstr(T.subjectIdentifier), '^ferret_\d+\.\d+@vhlab\.org$', 'once'))));
            % every animal was born before its experiment
            testCase.verifyTrue(all(datetime(T.dateOfBirth) < datetime(T.experimentDate)));
        end

        function validDirectoryPasses(testCase)
            d = ndi.test.helper.stacyFixtureDirectory(testCase.TempFolder);
            [isValid, report] = ndi.setup.conv.vhlab.validateStacyDirectory(d, 'Verbose', false);
            testCase.verifyTrue(isValid);
            testCase.verifyEmpty(report);
        end

        function missingSubjectFileIsAnError(testCase)
            d = ndi.test.helper.stacyFixtureDirectory(testCase.TempFolder, 'WriteSubjectFiles', false);
            [isValid, report] = ndi.setup.conv.vhlab.validateStacyDirectory(d, 'Verbose', false);
            testCase.verifyFalse(isValid);
            testCase.verifyTrue(any(report.level == "error" & report.location == "subject.txt"));
            testCase.verifyTrue(any(report.level == "error" & report.location == "dob.txt"));
        end

        function unrenamedChannelGroupingIsReported(testCase)
            d = ndi.test.helper.stacyFixtureDirectory(testCase.TempFolder);
            epochDir = fullfile(d, 't00001');
            movefile(fullfile(epochDir, 'vhintan_channelgrouping.txt'), ...
                fullfile(epochDir, 'vhlv_channelgrouping.txt'));
            [isValid, report] = ndi.setup.conv.vhlab.validateStacyDirectory(d, 'Verbose', false);
            testCase.verifyFalse(isValid);
            testCase.verifyTrue(any(contains(report.message, 'vhlv_channelgrouping.txt')));
        end

        function cellWithoutReferenceIsAnError(testCase)
            d = ndi.test.helper.stacyFixtureDirectory(testCase.TempFolder);
            fid = fopen(fullfile(d, 't00001', 'reference.txt'), 'w');
            fprintf(fid, 'name\tref\ttype\nother\t2\textracellular\n');
            fclose(fid);
            [isValid, report] = ndi.setup.conv.vhlab.validateStacyDirectory(d, 'Verbose', false);
            testCase.verifyFalse(isValid);
            testCase.verifyTrue(any(contains(report.message, 'cell_extra10_001_251_2020_07_16')));
        end

        function unmappedTypeIsAWarning(testCase)
            d = ndi.test.helper.stacyFixtureDirectory(testCase.TempFolder, 'Types', 'NotAType');
            [isValid, report] = ndi.setup.conv.vhlab.validateStacyDirectory(d, 'Verbose', false);
            testCase.verifyTrue(isValid);
            testCase.verifyTrue(any(report.level == "warning" & report.location == "testdirinfo.txt"));
        end

        function validateOnlyWritesSubjectFiles(testCase)
            d = ndi.test.helper.stacyFixtureDirectory(testCase.TempFolder, 'WriteSubjectFiles', false);
            [S, report] = ndi.setup.conv.vhlab.importStacyExperiment(d, 'ValidateOnly', true);
            testCase.verifyEmpty(S);
            testCase.verifyEmpty(report);
            testCase.verifyEqual(strtrim(fileread(fullfile(d, 'subject.txt'))), 'ferret_361.1521@vhlab.org');
            testCase.verifyEqual(strtrim(fileread(fullfile(d, 'dob.txt'))), '2020-06-14');
        end

        function mismatchedSubjectFileIsAnError(testCase)
            d = ndi.test.helper.stacyFixtureDirectory(testCase.TempFolder);
            testCase.verifyError(@() ndi.setup.conv.vhlab.importStacyExperiment(d, ...
                'ValidateOnly', true, 'SubjectIdentifier', "ferret_000.0000@vhlab.org"), ...
                'ndi:setup:conv:vhlab:importStacyExperiment:SubjectFileMismatch');
        end

        function approachMappingSplitsTypeLists(testCase)
            d = ndi.test.helper.stacyFixtureDirectory(testCase.TempFolder, 'Types', 'preDirSF, NotAType');
            S = ndi.session.dir('2020-07-16', d);
            T = ndi.setup.conv.vhlab.approachMappingTable(S);
            % preDirSF maps to two purposes and one "before" approach
            testCase.verifyEqual(height(T), 3);
            testCase.verifyTrue(all(strcmp(T.epochid, 't00001')));
            testCase.verifyTrue(any(strcmp(T.approachMapping, ...
                'EMPTY:approach: before artificial visual stimulation')));
        end

        function treatmentTableHasTreatmentTypes(testCase)
            d = ndi.test.helper.stacyFixtureDirectory(testCase.TempFolder);
            % a second training file a quarter of a day later: 6 hours of training
            currenttime = 737988.65; %#ok<NASGU>
            save(fullfile(d, 'grating_training_run2.mat'), 'currenttime');
            S = ndi.session.dir('2020-07-16', d);
            T = ndi.setup.conv.vhlab.treatmentTable(S);
            testCase.verifyEqual(height(T), 3);
            testCase.verifyEqual(cellstr(T.treatmentType), {'treatment'; 'measurement'; 'treatment'});
            testCase.verifyEqual(T.numericValue(1), 6, 'AbsTol', 1e-6);
            testCase.verifyEqual(string(T.stringValue(2)), "2020-06-14");
            testCase.verifyEqual(string(T.stringValue(3)), "2020-07-16");
        end

        function cellIntervalsMatchApproximately(testCase)
            % intervals of 2017-09-29: the epochs' recomputed intervals, and a
            % cell's stored ones that differ in the last digits and in the end
            % padding; t00005's padded end overlaps t00006's start
            epochs = [17188213.031750 17188823.460426; 17188950.750284 17190964.796034; ...
                17191209.512533 17192901.265934; 17214617.669371 17216328.161863; ...
                17216309.176442 17218321.783805; 17218328.768405 17218759.291787];
            cellIntervals = epochs + [0.0004 -3.1];
            idx = ndi.setup.conv.vhlab.matchCellIntervalsToEpochs(cellIntervals, epochs);
            testCase.verifyEqual(idx, (1:6)');
            % order does not matter
            idx = ndi.setup.conv.vhlab.matchCellIntervalsToEpochs(cellIntervals([3 1 2], :), epochs);
            testCase.verifyEqual(idx, [3; 1; 2]);
        end

        function cellIntervalWithoutEpochIsNaN(testCase)
            epochs = [0 100; 200 300];
            % the second interval lies between the epochs; the third barely touches one
            idx = ndi.setup.conv.vhlab.matchCellIntervalsToEpochs([0 99; 120 180; 290 400], epochs);
            testCase.verifyEqual(idx, [1; NaN; NaN]);
        end

        function eachEpochIsMatchedOnce(testCase)
            % two cell intervals in one epoch: the larger overlap keeps it
            idx = ndi.setup.conv.vhlab.matchCellIntervalsToEpochs([0 60; 0 100], [0 100]);
            testCase.verifyEqual(idx, [NaN; 1]);
        end
    end
end
