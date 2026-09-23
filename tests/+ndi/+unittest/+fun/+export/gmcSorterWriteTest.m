classdef gmcSorterWriteTest < matlab.unittest.TestCase
    % GMCSORTERWRITETEST - Unit tests for ndi.fun.export.gmcSorterWrite
    %
    % Exercises the pure 'dat_t_s' writing core of the GMC_Sorter exporter with
    % synthetic voltage (no NDI session or DAQ dependency) and verifies that the
    % files match the contract GMC_Sorter's raw_data.py reads:
    %
    %   * [base]_samples.dat is int16, channel-interleaved so that reshaping the
    %     stream as (n_time_samples, n_saved_chans) row-major recovers the
    %     original channels-by-samples matrix (raw_data.py does exactly this
    %     reshape then transposes to (n_channels, n_samples)).
    %   * [base]_timestamps.dat is int64 microseconds, one per sample.
    %   * The file sizes yield the same n_saved_chans / n_time_samples /
    %     sample_rate that parse_dat_t_s_metadata computes.
    %   * The channel map (channel_positions.csv) is [x y] in channel order.
    %
    % It also covers the GMC_Sorter Version 4 sidecars: channel_info.csv (the
    % per-shank ch_order/ch_map source), the kcoords/connected additions to
    % channel_map.mat, and the generated run_gmc_extract.py driver.

    properties
        OutDir
    end

    methods (TestMethodSetup)
        function setupDir(testCase)
            testCase.OutDir = tempname; % gmcSorterWrite creates it
        end
    end

    methods (TestMethodTeardown)
        function cleanupDir(testCase)
            if exist(testCase.OutDir, 'dir')
                rmdir(testCase.OutDir, 's');
            end
        end
    end

    methods % helpers
        function [x, t, pos, fs] = basicData(~)
            fs = 25000;                       % Hz (40 us/sample: integer-us
                                              % timestamps quantize exactly)
            nCh = 4; nSamp = 2500;
            t = (0:nSamp-1)/fs;               % seconds, monotonic
            % Distinctive per-channel, per-sample values that survive int16 and
            % pin down the interleaving: value(ch,samp) = ch*1000 + mod(samp,7).
            [C, Sidx] = ndgrid(0:nCh-1, 0:nSamp-1);
            x = C*1000 + mod(Sidx,7);         % nCh x nSamp
            pos = [0 0; 0 25; 0 50; 0 75];    % linear, 25 um
        end
    end

    methods (Test)

        function testSamplesInterleavingAndDtype(testCase)
            [x, t, pos, fs] = testCase.basicData();
            ndi.fun.export.gmcSorterWrite(testCase.OutDir, x, t, pos, ...
                'baseName','RawData','sampleRate',fs,'verbose',0);

            samplesFile = fullfile(testCase.OutDir, 'RawData_samples.dat');
            % Read back as raw_data.py does: int16 stream -> reshape
            % (n_time_samples, n_saved_chans) row-major -> transpose.
            fid = fopen(samplesFile,'r','ieee-le');
            raw = fread(fid, Inf, 'int16=>double');
            fclose(fid);

            nCh = size(x,1); nSamp = size(x,2);
            testCase.verifyEqual(numel(raw), nCh*nSamp, 'samples file element count');
            % MATLAB fread gives a column vector in file order [ch0_s0, ch1_s0,
            % ..., chN_s0, ch0_s1, ...]; reshape (nCh, nSamp) recovers x.
            recovered = reshape(raw, nCh, nSamp);
            testCase.verifyEqual(recovered, x, 'channel-interleaved layout round-trips');
        end

        function testTimestampsMicroseconds(testCase)
            [x, t, pos, fs] = testCase.basicData();
            ndi.fun.export.gmcSorterWrite(testCase.OutDir, x, t, pos, ...
                'baseName','RawData','sampleRate',fs,'verbose',0);

            tsFile = fullfile(testCase.OutDir, 'RawData_timestamps.dat');
            fid = fopen(tsFile,'r','ieee-le');
            ts = fread(fid, Inf, 'int64=>double');
            fclose(fid);

            testCase.verifyEqual(numel(ts), numel(t), 'one timestamp per sample');
            testCase.verifyEqual(ts, round(t(:)*1e6), 'timestamps are integer microseconds');
            testCase.verifyTrue(all(diff(ts)>0), 'timestamps strictly increasing');
        end

        function testDerivedMetadataMatchesGmc(testCase)
            % Reproduce parse_dat_t_s_metadata's derivations from file sizes.
            [x, t, pos, fs] = testCase.basicData();
            ndi.fun.export.gmcSorterWrite(testCase.OutDir, x, t, pos, ...
                'baseName','RawData','sampleRate',fs,'verbose',0);

            sInfo = dir(fullfile(testCase.OutDir,'RawData_samples.dat'));
            tInfo = dir(fullfile(testCase.OutDir,'RawData_timestamps.dat'));

            n_time_samples = tInfo.bytes / 8;            % int64
            n_saved_chans  = sInfo.bytes / (n_time_samples * 2); % int16
            testCase.verifyEqual(n_time_samples, size(x,2), 'n_time_samples from file size');
            testCase.verifyEqual(n_saved_chans, size(x,1), 'n_saved_chans from file size');

            % sample_rate = 1e6 / median(diff(first 1000 timestamps_us))
            fid = fopen(fullfile(testCase.OutDir,'RawData_timestamps.dat'),'r','ieee-le');
            ts = fread(fid, min(1000,n_time_samples), 'int64=>double');
            fclose(fid);
            sample_rate = 1e6 / median(diff(ts));
            testCase.verifyEqual(sample_rate, fs, 'AbsTol', 1e-6);
        end

        function testChannelMapAndSidecars(testCase)
            [x, t, pos, fs] = testCase.basicData();
            ndi.fun.export.gmcSorterWrite(testCase.OutDir, x, t, pos, ...
                'baseName','RawData','sampleRate',fs,'verbose',0);

            % channel_positions.csv : [x y] per channel, channel order
            csv = readmatrix(fullfile(testCase.OutDir,'channel_positions.csv'));
            testCase.verifyEqual(csv, pos, 'AbsTol', 1e-6);

            % channel_map.mat : ch_map == pos
            m = load(fullfile(testCase.OutDir,'channel_map.mat'));
            testCase.verifyEqual(m.ch_map, pos, 'AbsTol', 1e-6);
            testCase.verifyEqual(m.xcoords(:), pos(:,1), 'AbsTol', 1e-6);
            testCase.verifyEqual(m.ycoords(:), pos(:,2), 'AbsTol', 1e-6);

            % driver + metadata exist
            testCase.verifyTrue(isfile(fullfile(testCase.OutDir,'run_gmc_extract.py')));
            testCase.verifyTrue(isfile(fullfile(testCase.OutDir,'RawData.metadata')));
        end

        function testChannelInfoDefaults(testCase)
            % channel_info.csv: 0-based channel, [x y], shank, connected.
            % With no shankIndex/connected given, everything is one connected shank.
            [x, t, pos, fs] = testCase.basicData();
            ndi.fun.export.gmcSorterWrite(testCase.OutDir, x, t, pos, ...
                'baseName','RawData','sampleRate',fs,'verbose',0);

            info = readmatrix(fullfile(testCase.OutDir,'channel_info.csv'), ...
                'NumHeaderLines', 1);
            nCh = size(pos,1);
            testCase.verifyEqual(size(info), [nCh 5], 'channel_info.csv shape');
            testCase.verifyEqual(info(:,1), (0:nCh-1).', '0-based channel index');
            testCase.verifyEqual(info(:,2:3), pos, 'AbsTol', 1e-6);
            testCase.verifyEqual(info(:,4), ones(nCh,1), 'default: one shank');
            testCase.verifyEqual(info(:,5), ones(nCh,1), 'default: all connected');
        end

        function testChannelInfoShanksAndConnected(testCase)
            % A 2-shank probe with one dead channel round-trips into the sidecars.
            [x, t, pos, fs] = testCase.basicData();
            shank = [1;1;2;2];
            conn  = [true;false;true;true];
            ndi.fun.export.gmcSorterWrite(testCase.OutDir, x, t, pos, ...
                'baseName','RawData','sampleRate',fs,'verbose',0, ...
                'shankIndex',shank,'connected',conn);

            info = readmatrix(fullfile(testCase.OutDir,'channel_info.csv'), ...
                'NumHeaderLines', 1);
            testCase.verifyEqual(info(:,4), shank, 'shank ids');
            testCase.verifyEqual(logical(info(:,5)), conn, 'connected flags');

            % channel_map.mat carries the same as kcoords / connected
            m = load(fullfile(testCase.OutDir,'channel_map.mat'));
            testCase.verifyEqual(m.kcoords(:), shank, 'kcoords');
            testCase.verifyEqual(logical(m.connected(:)), conn, 'connected');
        end

        function testShankIndexLengthMismatchErrors(testCase)
            [x, t, pos, fs] = testCase.basicData();
            testCase.verifyError(@() ndi.fun.export.gmcSorterWrite( ...
                testCase.OutDir, x, t, pos, 'sampleRate',fs,'verbose',0, ...
                'shankIndex',[1;1;2]), ...
                'ndi:fun:export:writeGmcSidecars:shankIndex');
        end

        function testDriverUsesVersion4Api(testCase)
            % The generated driver must drive GMC_Sorter Version 4:
            % one extract_spike_features(..., ch_order=...) pass per shank,
            % then properties.mat.
            [x, t, pos, fs] = testCase.basicData();
            ndi.fun.export.gmcSorterWrite(testCase.OutDir, x, t, pos, ...
                'baseName','RawData','sampleRate',fs,'verbose',0, ...
                'shankIndex',[1;1;2;2], ...
                'featureOptions',{'refr_space',150,'noise_space',NaN});

            drv = fileread(fullfile(testCase.OutDir,'run_gmc_extract.py'));
            testCase.verifyNotEmpty(strfind(drv,'from sp_feature_ext import extract_spike_features'), ...
                'imports the Version 4 extractor');
            testCase.verifyNotEmpty(strfind(drv,'ch_order=sh["ch_order"]'), ...
                'passes ch_order (the Version 4 addition)');
            testCase.verifyNotEmpty(strfind(drv,'channel_info.csv'), ...
                'reads the per-shank channel table');
            testCase.verifyNotEmpty(strfind(drv,'save_properties_mat(out_folder)'), ...
                'writes properties.mat as main.py does');
            % featureOptions become Python keyword arguments
            testCase.verifyNotEmpty(strfind(drv, ...
                'EXTRACT_KWARGS = dict(refr_space=150, noise_space=float("nan"))'), ...
                'featureOptions render as Python kwargs, NaN included');
            % no probe_mappings import unless gmcProbeName was asked for
            testCase.verifyEmpty(strfind(drv,'from probe_mappings import'), ...
                'probe_mappings imported only when gmcProbeName is set');
        end

        function testDriverProbeMappingsMode(testCase)
            [x, t, pos, fs] = testCase.basicData();
            ndi.fun.export.gmcSorterWrite(testCase.OutDir, x, t, pos, ...
                'baseName','RawData','sampleRate',fs,'verbose',0, ...
                'gmcProbeName','KN_UCLA_64M');

            drv = fileread(fullfile(testCase.OutDir,'run_gmc_extract.py'));
            testCase.verifyNotEmpty(strfind(drv,'from probe_mappings import get_probe_map'), ...
                'imports GMC_Sorter''s probe table');
            testCase.verifyNotEmpty(strfind(drv,'PROBE_NAME = "KN_UCLA_64M"'), ...
                'names the probe');
        end

        function testFeatureOptionsMustBePairs(testCase)
            [x, t, pos, fs] = testCase.basicData();
            testCase.verifyError(@() ndi.fun.export.gmcSorterWrite( ...
                testCase.OutDir, x, t, pos, 'sampleRate',fs,'verbose',0, ...
                'featureOptions',{'refr_space'}), ...
                'ndi:fun:export:writeGmcSidecars:featureOptions');
        end

        function testMultiplierAndSaturation(testCase)
            % multiplier scales; values beyond int16 range saturate.
            t = (0:9)/30000;
            pos = [0 0; 0 25];
            x = [ 100  -100  50000 -50000 0 1 2 3 4 5; ...
                    0     0      0      0 0 0 0 0 0 0];
            ndi.fun.export.gmcSorterWrite(testCase.OutDir, x, t, pos, ...
                'baseName','RawData','multiplier',2,'sampleRate',30000,'verbose',0);

            fid = fopen(fullfile(testCase.OutDir,'RawData_samples.dat'),'r','ieee-le');
            raw = fread(fid, Inf, 'int16=>double');
            fclose(fid);
            recovered = reshape(raw, 2, 10);
            expected = max(min(round(2*x),32767),-32768);
            testCase.verifyEqual(recovered, expected, 'multiplier + int16 saturation');
        end

        function testNonMonotonicTimestampsError(testCase)
            pos = [0 0; 0 25];
            x = int16(zeros(2,3));
            tbad = [0 1 0.5]/30000; % not increasing
            testCase.verifyError(@() ndi.fun.export.gmcSorterWrite( ...
                testCase.OutDir, x, tbad, pos, 'verbose',0), ...
                'ndi:fun:export:gmcSorterWrite:monotonic');
        end

        function testSizeMismatchErrors(testCase)
            pos = [0 0; 0 25];
            x = zeros(2,5);
            testCase.verifyError(@() ndi.fun.export.gmcSorterWrite( ...
                testCase.OutDir, x, (0:3)/30000, pos, 'verbose',0), ...
                'ndi:fun:export:gmcSorterWrite:size');
            testCase.verifyError(@() ndi.fun.export.gmcSorterWrite( ...
                testCase.OutDir, x, (0:4)/30000, [0 0;0 25;0 50], 'verbose',0), ...
                'ndi:fun:export:gmcSorterWrite:channels');
        end

    end
end
