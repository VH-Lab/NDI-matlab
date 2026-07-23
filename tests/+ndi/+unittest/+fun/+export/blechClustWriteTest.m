classdef blechClustWriteTest < matlab.unittest.TestCase
    % BLECHCLUSTWRITETEST - Unit tests for ndi.fun.export.blech_clust_write
    %
    % Exercises the pure HDF5-writing core of the blech_clust exporter with
    % synthetic ensemble spike times and stimulus identities/times (no NDI
    % session, syncgraph, or DAQ dependency), and verifies the resulting
    % blech_clust HDF5 layout: the per-tastant /spike_trains/dig_in_<N>/
    % spike_array binary raster (shape, aligned bin positions, group
    % attributes), the /sorted_units/unit<NNN>/times, and the /unit_descriptor
    % compound table.
    %
    % The alignment contract under test: for a trial with delivery time t0 and
    % windows preStim/postStim (ms), a spike at time t lands in 1-based column
    % floor((t - (t0 - preStim/1000))*1000) + 1. Spike times here are placed at
    % mid-bin offsets (X.5 ms past a bin edge) so the column is unambiguous
    % under floating-point rounding.

    properties
        OutFile
    end

    methods (TestMethodSetup)
        function setupFile(testCase)
            testCase.OutFile = [tempname '.h5'];
        end
    end

    methods (TestMethodTeardown)
        function cleanupFile(testCase)
            if exist(testCase.OutFile, 'file')
                delete(testCase.OutFile);
            end
        end
    end

    methods % helpers
        function [ust, uinfo, onset, tstimid, map] = basicData(~)
            % 2 units, 3 trials, 2 tastants (stimid 1 and 2). Spike times sit
            % 2.5 ms / 4.5 ms past a bin edge so bin columns are unambiguous:
            %   unit1: 1.0025 s (trial 1, onset 1.0) -> col 103
            %          3.0025 s (trial 3, onset 3.0) -> col 103
            %   unit2: 2.0045 s (trial 2, onset 2.0) -> col 105
            ust  = { [1.0025, 3.0025], [2.0045] };   % spike times (s)
            uinfo = struct('name', {'u1','u2'}, ...
                'single_unit', {1, 0}, ...
                'regular_spiking', {0, 1}, ...
                'fast_spiking', {0, 0});
            onset   = [1.0; 2.0; 3.0];
            tstimid = [1; 2; 1];
            map = containers.Map([1 2], {'sucrose','quinine'});
        end
    end

    methods (Test)

        function testSpikeArrayStructureAndValues(testCase)
            [ust, uinfo, onset, tstimid, map] = testCase.basicData();
            ndi.fun.export.blech_clust_write(testCase.OutFile, ust, uinfo, ...
                onset, tstimid, map, 'preStim', 100, 'postStim', 100, ...
                'epochID', 'test_epoch', 'verbose', 0);

            % dig_in_0 = stimid 1 (trials 1 and 3), dig_in_1 = stimid 2 (trial 2)
            %
            % The dataset is written on disk as [trial_dur_ms n_units n_trials]
            % so that blech_clust's h5py/numpy reader (row-major, reversed
            % index order) sees the required (n_trials, n_units, trial_dur_ms)
            % shape. MATLAB's h5read therefore reads it back in that on-disk
            % [ms x units x trials] order. (Issue #855.)
            a0 = h5read(testCase.OutFile, '/spike_trains/dig_in_0/spike_array');
            a1 = h5read(testCase.OutFile, '/spike_trains/dig_in_1/spike_array');

            testCase.verifyEqual(size(a0), [200 2 2], 'dig_in_0 shape ms x n_units x n_trials');
            testCase.verifyEqual(size(a1), [200 2 1], 'dig_in_1 shape');

            % unit 1 lands at column 103 in both trials of dig_in_0.
            testCase.verifyEqual(a0(103,1,1), uint8(1));
            testCase.verifyEqual(a0(103,1,2), uint8(1));
            testCase.verifyEqual(nnz(a0), 2, 'exactly two spikes land in dig_in_0');

            % unit 2 spike (trial 2, onset 2.0) -> col 105.
            testCase.verifyEqual(a1(105,2,1), uint8(1));
            testCase.verifyEqual(nnz(a1), 1, 'exactly one spike lands in dig_in_1');
        end

        function testGroupAttributes(testCase)
            [ust, uinfo, onset, tstimid, map] = testCase.basicData();
            ndi.fun.export.blech_clust_write(testCase.OutFile, ust, uinfo, ...
                onset, tstimid, map, 'preStim', 100, 'postStim', 100, 'verbose', 0);

            testCase.verifyEqual(h5readatt(testCase.OutFile, '/spike_trains/dig_in_0', 'stimid'), 1);
            testCase.verifyEqual(h5readatt(testCase.OutFile, '/spike_trains/dig_in_0', 'tastant'), 'sucrose');
            testCase.verifyEqual(h5readatt(testCase.OutFile, '/spike_trains/dig_in_0', 'n_trials'), 2);
            testCase.verifyEqual(h5readatt(testCase.OutFile, '/spike_trains/dig_in_1', 'stimid'), 2);
            testCase.verifyEqual(h5readatt(testCase.OutFile, '/spike_trains/dig_in_1', 'tastant'), 'quinine');
            testCase.verifyEqual(h5readatt(testCase.OutFile, '/spike_trains/dig_in_0', 'pre_stim_ms'), 100);
        end

        function testSortedUnitsAndDescriptor(testCase)
            [ust, uinfo, onset, tstimid, map] = testCase.basicData();
            ndi.fun.export.blech_clust_write(testCase.OutFile, ust, uinfo, ...
                onset, tstimid, map, 'sampleRate', 30000, 'verbose', 0);

            t0 = h5read(testCase.OutFile, '/sorted_units/unit000/times');
            t1 = h5read(testCase.OutFile, '/sorted_units/unit001/times');
            testCase.verifyEqual(double(t0(:)), [30075; 90075], ...
                'unit 0 spike times in 30 kHz samples');
            testCase.verifyEqual(double(t1(:)), 60135);

            ud = h5read(testCase.OutFile, '/unit_descriptor');
            testCase.verifyEqual(int32(ud.single_unit(:)),     int32([1;0]));
            testCase.verifyEqual(int32(ud.regular_spiking(:)), int32([0;1]));
            testCase.verifyEqual(int32(ud.fast_spiking(:)),    int32([0;0]));
        end

        function testTopLevelAttributes(testCase)
            [ust, uinfo, onset, tstimid, map] = testCase.basicData();
            ndi.fun.export.blech_clust_write(testCase.OutFile, ust, uinfo, ...
                onset, tstimid, map, 'sampleRate', 30000, 'epochID', 'test_epoch', 'verbose', 0);
            testCase.verifyEqual(h5readatt(testCase.OutFile, '/', 'sample_rate_hz'), 30000);
            testCase.verifyEqual(h5readatt(testCase.OutFile, '/', 'ndi_epochid'), 'test_epoch');
        end

        function testStimulusOrderControlsDigInMapping(testCase)
            % With stimulusOrder [2 1], dig_in_0 should be stimid 2.
            [ust, uinfo, onset, tstimid, map] = testCase.basicData();
            ndi.fun.export.blech_clust_write(testCase.OutFile, ust, uinfo, ...
                onset, tstimid, map, 'stimulusOrder', [2 1], 'verbose', 0);
            testCase.verifyEqual(h5readatt(testCase.OutFile, '/spike_trains/dig_in_0', 'stimid'), 2);
            testCase.verifyEqual(h5readatt(testCase.OutFile, '/spike_trains/dig_in_1', 'stimid'), 1);
        end

        function testIncludeStimidsFilters(testCase)
            % Only stimid 1 is exported -> a single dig_in group.
            [ust, uinfo, onset, tstimid, map] = testCase.basicData();
            ndi.fun.export.blech_clust_write(testCase.OutFile, ust, uinfo, ...
                onset, tstimid, map, 'includeStimids', 1, 'verbose', 0);
            info = h5info(testCase.OutFile, '/spike_trains');
            names = {info.Groups.Name};
            testCase.verifyTrue(ismember('/spike_trains/dig_in_0', names));
            testCase.verifyFalse(ismember('/spike_trains/dig_in_1', names), ...
                'stimid 2 should be excluded');
        end

        function testNoStimuliError(testCase)
            [ust, uinfo, onset, tstimid, map] = testCase.basicData();
            testCase.verifyError(@() ndi.fun.export.blech_clust_write( ...
                testCase.OutFile, ust, uinfo, onset, tstimid, map, ...
                'includeStimids', 99, 'verbose', 0), ...
                'ndi:fun:export:blech_clust_write:nostimuli');
        end

        function testEmptyTastantWarns(testCase)
            % A requested stimid with no trials warns and is skipped.
            [ust, uinfo, onset, tstimid, map] = testCase.basicData();
            testCase.verifyWarning(@() ndi.fun.export.blech_clust_write( ...
                testCase.OutFile, ust, uinfo, onset, tstimid, map, ...
                'stimulusOrder', [1 2 5], 'verbose', 0), ...
                'ndi:fun:export:blech_clust_write:emptytastant');
        end

    end
end
