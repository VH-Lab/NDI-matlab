function [templates, spike_templates, amplitudes, winv] = import_kilosort_waveformdata(kdir)
% NDI.FUN.PROBE.IMPORT_KILOSORT_WAVEFORMDATA - load kilosort template waveform data
%
% [TEMPLATES, SPIKE_TEMPLATES, AMPLITUDES, WINV] = ...
%       NDI.FUN.PROBE.IMPORT_KILOSORT_WAVEFORMDATA(KDIR)
%
% Loads the kilosort files needed to reconstruct per-cluster mean waveforms from
% the kilosort output directory KDIR:
%
%   TEMPLATES       - nTemplates x nSamples x nChannels template shapes (templates.npy)
%   SPIKE_TEMPLATES - template id (0-based) of each spike (spike_templates.npy)
%   AMPLITUDES      - per-spike template scaling amplitude (amplitudes.npy)
%   WINV            - the inverse whitening matrix (whitening_mat_inv.npy) if present,
%                     otherwise []. When present it is used to un-whiten the templates
%                     so the waveforms are in (approximately) physical units.
%
% See also: NDI.FUN.PROBE.IMPORT_KILOSORT, NDI.FUN.PROBE.IMPORT_KILOSORT_MEANWAVEFORM

    npyread = @(f) ndi.fun.probe.import_kilosort_readNPY(f);

    tfile = fullfile(kdir,'templates.npy');
    stfile = fullfile(kdir,'spike_templates.npy');
    afile = fullfile(kdir,'amplitudes.npy');

    if ~isfile(tfile) || ~isfile(stfile) || ~isfile(afile),
        error(['waveform_source ''templates'' requires templates.npy, spike_templates.npy, ' ...
            'and amplitudes.npy in ' kdir '. Use ''waveform_source'',''none'' to skip waveforms.']);
    end;

    templates = double(npyread(tfile));
    spike_templates = double(npyread(stfile));
    amplitudes = double(npyread(afile));

    winv = [];
    wfile = fullfile(kdir,'whitening_mat_inv.npy');
    if isfile(wfile),
        winv = double(npyread(wfile));
    end;

end
