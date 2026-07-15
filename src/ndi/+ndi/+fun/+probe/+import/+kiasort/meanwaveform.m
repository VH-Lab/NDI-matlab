function meanWf = meanwaveform(uid, unit_stats)
% NDI.FUN.PROBE.IMPORT.KIASORT.MEANWAVEFORM - mean waveform for a KIASORT unit
%
% MEANWF = NDI.FUN.PROBE.IMPORT.KIASORT.MEANWAVEFORM(UID, UNIT_STATS)
%
% Returns the mean waveform (NumSamples x NumChannels) for the cross-channel unit
% UID, extracted from the per-unit statistics UNIT_STATS produced by
% NDI.FUN.PROBE.IMPORT.KIASORT.UNITSTATS (i.e. crossChannelStats.unified_labels).
%
% KIASORT stores meanWaveforms as a (nUnits x nSamples x nChannels) array indexed
% in parallel with UNIT_STATS.label. This function finds the row matching UID and
% squeezes it to NumSamples x NumChannels. If UNIT_STATS is empty, does not contain
% mean waveforms, or has no row for UID, MEANWF is returned as [].
%
% See also: NDI.FUN.PROBE.IMPORT.KIASORT.PROBE, NDI.FUN.PROBE.IMPORT.KIASORT.UNITSTATS

    meanWf = [];

    if isempty(unit_stats) || ~isfield(unit_stats,'meanWaveforms') || isempty(unit_stats.meanWaveforms),
        return;
    end;

    row = find(double(unit_stats.label(:))==uid, 1);
    if isempty(row),
        return;
    end;

    w = unit_stats.meanWaveforms;
    if row > size(w,1),
        return;
    end;

    meanWf = squeeze(w(row, :, :)); % nSamples x nChannels

    % guard against a degenerate squeeze when there is a single channel
    if isvector(meanWf),
        meanWf = meanWf(:);
    end;

end
