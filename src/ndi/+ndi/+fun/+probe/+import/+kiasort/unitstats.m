function stats = unitstats(kdir, suffix)
% NDI.FUN.PROBE.IMPORT.KIASORT.UNITSTATS - load per-unit KIASORT statistics
%
% STATS = NDI.FUN.PROBE.IMPORT.KIASORT.UNITSTATS(KDIR, SUFFIX)
%
% Loads the per-unit statistics KIASORT produces during its sample-sorting stage
% from the output folder KDIR. These carry the mean waveform of each cross-channel
% unit (and its channel), which KIASORT does not store in the per-spike RES_Sorted
% HDF5 files. Returns [] if no statistics file is found.
%
% Preference order (mirrors KIASORT's own load_sorted_results/kiaSort_load_results):
%   1) If SUFFIX is '_curated', KDIR/RES_Sorted/curated_sample.mat (curatedSamples)
%   2) KDIR/Sorted_Samples/sorted_samples.mat (crossChannelStats.unified_labels)
%
% STATS is a struct normalized to the fields used by the importer:
%   label          - Ux1 unit id
%   channelID      - Ux1 detection channel per unit (or [])
%   meanWaveforms  - U x nSamples x nChannels array of mean waveforms (or [])
%
% See also: NDI.FUN.PROBE.IMPORT.KIASORT.RESULTS, NDI.FUN.PROBE.IMPORT.KIASORT.MEANWAVEFORM

    if nargin<2, suffix = ''; end;

    stats = [];

    % 1) curated samples, if we are reading a curated sort
    if strcmp(suffix,'_curated'),
        curatedMat = fullfile(kdir, 'RES_Sorted', 'curated_sample.mat');
        if isfile(curatedMat),
            s = load(curatedMat);
            if isfield(s,'curatedSamples'),
                c = s.curatedSamples;
                stats = struct();
                stats.label = c.unifiedLabels(:);
                if isfield(c,'channelNum'), stats.channelID = c.channelNum(:); else, stats.channelID = []; end;
                if isfield(c,'waveform'), stats.meanWaveforms = c.waveform; else, stats.meanWaveforms = []; end;
                return;
            end;
        end;
    end;

    % 2) the sample-sorting stage output
    sortedSamp = fullfile(kdir, 'Sorted_Samples', 'sorted_samples.mat');
    if isfile(sortedSamp),
        s = load(sortedSamp);
        if isfield(s,'crossChannelStats') && isfield(s.crossChannelStats,'unified_labels'),
            u = s.crossChannelStats.unified_labels;
            stats = struct();
            stats.label = u.label(:);
            if isfield(u,'channelID'), stats.channelID = u.channelID(:); else, stats.channelID = []; end;
            if isfield(u,'meanWaveforms'), stats.meanWaveforms = u.meanWaveforms; else, stats.meanWaveforms = []; end;
            return;
        end;
    end;

end
