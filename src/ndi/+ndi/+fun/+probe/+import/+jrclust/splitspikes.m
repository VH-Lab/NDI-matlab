function localSamples = splitspikes(bounds, spikeSamples)
% NDI.FUN.PROBE.IMPORT.JRCLUST.SPLITSPIKES - divide JRCLUST spikes among epochs
%
% LOCALSAMPLES = NDI.FUN.PROBE.IMPORT.JRCLUST.SPLITSPIKES(BOUNDS, SPIKESAMPLES)
%
% Divides the 1-based sample indices SPIKESAMPLES of one unit, which number the
% samples of JRCLUST's concatenated stream, among the epochs that stream was built
% from, and converts each to a 1-based sample index within its own epoch.
%
% BOUNDS is the [nEpochs+1 x 1] vector of cumulative sample counts returned by
% NDI.FUN.PROBE.IMPORT.JRCLUST.EPOCHBOUNDS: epoch e holds the global samples in
% (BOUNDS(e), BOUNDS(e+1)].
%
% Returns LOCALSAMPLES, a {nEpochs x 1} cell array; entry e holds a column of the
% 1-based local sample indices of the spikes that fall in epoch e (empty where the
% unit did not fire), in the order they appear in SPIKESAMPLES.
%
% Spikes outside (0, BOUNDS(end)] are not assigned to any epoch. Callers check that
% range up front (see NDI.FUN.PROBE.IMPORT.JRCLUST.PROBE, which raises
% ndi:fun:probe:import:jrclust:probe:sampleOutOfRange) so a sort that does not match
% the probe is reported rather than silently losing spikes.
%
% Example:
%    % two epochs of 100 samples; the last spike is the first sample of epoch 2
%    ls = ndi.fun.probe.import.jrclust.splitspikes([0;100;200],[5;100;101]);
%    % ls{1} is [5;100], ls{2} is 1
%
% See also: NDI.FUN.PROBE.IMPORT.JRCLUST.EPOCHBOUNDS,
%   NDI.FUN.PROBE.IMPORT.JRCLUST.PROBE

    arguments
        bounds (:,1) double
        spikeSamples (:,1) double
    end

    nEpochs = numel(bounds) - 1;
    localSamples = cell(nEpochs,1);

    for e=1:nEpochs,
        inEpoch = find(spikeSamples > bounds(e) & spikeSamples <= bounds(e+1));
        localSamples{e} = spikeSamples(inEpoch) - bounds(e); % 1-based within the epoch
    end;

end % splitspikes()
