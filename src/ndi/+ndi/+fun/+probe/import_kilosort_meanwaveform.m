function meanWf = import_kilosort_meanwaveform(cid, spike_clusters, spike_templates, amplitudes, templates, winv)
% NDI.FUN.PROBE.IMPORT_KILOSORT_MEANWAVEFORM - amplitude-weighted mean waveform for a cluster
%
% MEANWF = NDI.FUN.PROBE.IMPORT_KILOSORT_MEANWAVEFORM(CID, SPIKE_CLUSTERS, ...
%       SPIKE_TEMPLATES, AMPLITUDES, TEMPLATES, WINV)
%
% Computes the mean waveform (NumSamples x NumChannels) for curated cluster CID.
%
% Because a curated cluster may span several kilosort templates (after merges), the
% waveform is computed as the AMPLITUDE-WEIGHTED AVERAGE of every template that
% contributes spikes to the cluster: each contributing template is weighted by the
% sum of the spike amplitudes assigned to it within this cluster. The result is then
% scaled by the cluster's mean spike amplitude so the waveform has a meaningful
% magnitude, and, if an inverse whitening matrix WINV is provided, un-whitened into
% (approximately) physical units.
%
% Inputs:
%   CID             - the cluster id to compute
%   SPIKE_CLUSTERS  - cluster id of every spike
%   SPIKE_TEMPLATES - template id (0-based) of every spike
%   AMPLITUDES      - amplitude of every spike
%   TEMPLATES       - nTemplates x nSamples x nChannels template shapes
%   WINV            - inverse whitening matrix (nChannels x nChannels) or []
%
% See also: NDI.FUN.PROBE.IMPORT_KILOSORT

    I = find(spike_clusters==cid);
    nSamples = size(templates,2);
    nChannels = size(templates,3);

    if isempty(I),
        meanWf = zeros(nSamples, nChannels);
        return;
    end;

    tmpl = spike_templates(I);   % 0-based template ids
    amp = amplitudes(I);

    ut = unique(tmpl);
    W = zeros(nSamples, nChannels);
    wsum = 0;
    for k=1:numel(ut),
        sel = (tmpl==ut(k));
        w = sum(amp(sel)); % total amplitude contributed by this template
        W = W + w * squeeze(templates(ut(k)+1, :, :));
        wsum = wsum + w;
    end;

    if wsum>0,
        meanWf = W / wsum;
    else,
        meanWf = W;
    end;

    % scale to physical-ish amplitude using the cluster's mean spike amplitude
    meanWf = meanWf * mean(amp);

    % un-whiten if the inverse whitening matrix is available and conformable
    if ~isempty(winv) && size(winv,1)==nChannels && size(winv,2)==nChannels,
        meanWf = meanWf * winv;
    end;

end
