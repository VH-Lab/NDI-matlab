function info = promptrawbinary(baseinfo, options)
% NDI.FUN.PROBE.IMPORT.KILOSORT.PROMPTRAWBINARY - obtain a user-selected raw recording
%
% INFO = NDI.FUN.PROBE.IMPORT.KILOSORT.PROMPTRAWBINARY(BASEINFO, ...)
%
% Obtains the raw Neuropixels/SpikeGLX recording to use for recalculating spike
% waveforms when the binary could not be located automatically (no explicit
% 'binary_file' and no NDI '.metadata' sidecar). This is the fallback used by
% NDI.FUN.PROBE.IMPORT.KILOSORT.PROBE. It deliberately does NOT read Kilosort's
% Phy 'params.py' 'dat_path' to find the binary (that path frequently names a
% whitened, filtered temporary file that cannot be relied on); instead it prompts
% the user to pick the true raw recording.
%
% BASEINFO is the (not-found) struct returned by
% NDI.FUN.PROBE.IMPORT.KILOSORT.BINARYINFO. Its acquisition parameters that were
% already parsed from a '.metadata' sidecar or Phy 'params.py' - in particular
% 'num_channels' (n_channels_dat), 'dtype', 'headerOffsetBytes' and 'sample_rate' -
% are carried through, because the raw file the user selects has the same channel
% count and layout as the sort even though the sort's binary itself is missing.
%
% The raw file is obtained from (in order):
%   1) an explicit 'RawFile' option, if given (used for headless/automated runs);
%   2) otherwise, if 'PromptForRawFile' is true, a UIGETFILE dialog.
% The probe generation (which fixes the int16->volts multiplier, see
% NDI.FUN.PROBE.IMPORT.KILOSORT.NEUROPIXELSMULTIPLIER) is obtained from:
%   1) an explicit 'ProbeType' option ('NP1' or 'NP2'), if given;
%   2) otherwise, if 'PromptForRawFile' is true, a QUESTDLG dialog.
%
% INFO has the same fields as the BINARYINFO result, with 'found' true and 'file',
% 'num_channels' and 'multiplier' filled in for the selected recording, plus a
% 'probe_type' field ('NP1'/'NP2'). If the user cancels either dialog, INFO.found
% is false and the caller falls back to the (narrow) template waveforms.
%
% Name/value pairs:
% ---------------------------------------------------------------------------------
% | Parameter (default)   | Description                                           |
% |-----------------------|-------------------------------------------------------|
% | RawFile ('')          | Explicit path to the raw recording. Skips the file    |
% |                       |   dialog (errors if the file does not exist).         |
% | ProbeType ('')        | 'NP1' or 'NP2'. Skips the probe-generation dialog.    |
% | PromptForRawFile      | If true, use interactive dialogs when RawFile /       |
% |   (true)              |   ProbeType are not supplied. If false, both must be  |
% |                       |   supplied or an error is raised (headless mode).     |
% | num_channels (NaN)    | Override the channel count. When NaN, the count is    |
% |                       |   taken from BASEINFO (meta/params.py n_channels_dat).|
% ---------------------------------------------------------------------------------
%
% See also: NDI.FUN.PROBE.IMPORT.KILOSORT.PROBE, NDI.FUN.PROBE.IMPORT.KILOSORT.BINARYINFO,
%   NDI.FUN.PROBE.IMPORT.KILOSORT.NEUROPIXELSMULTIPLIER

    arguments
        baseinfo (1,1) struct
        options.RawFile (1,:) char = ''
        options.ProbeType (1,:) char = ''
        options.PromptForRawFile (1,1) logical = true
        options.num_channels (1,1) double = NaN
    end

    info = baseinfo;
    info.found = false;
    if ~isfield(info,'probe_type'), info.probe_type = ''; end;

    % --- 1. the raw file ---
    binfile = '';
    if ~isempty(options.RawFile),
        if ~isfile(options.RawFile),
            error('ndi:fun:probe:import:kilosort:promptrawbinary:noFile', ...
                'Specified RawFile was not found: %s.', options.RawFile);
        end;
        binfile = options.RawFile;
    elseif options.PromptForRawFile,
        [fn, pn] = uigetfile({'*.bin;*.dat', 'Raw recording (*.bin, *.dat)'; ...
            '*.*', 'All files (*.*)'}, ...
            'Select the raw Neuropixels/SpikeGLX recording for spike-shape recalculation');
        if isequal(fn, 0),
            return; % user cancelled
        end;
        binfile = fullfile(pn, fn);
    else,
        error('ndi:fun:probe:import:kilosort:promptrawbinary:noRawFile', ...
            ['No raw recording available: pass ''RawFile'' (PromptForRawFile is false, ' ...
            'so no dialog is shown).']);
    end;

    % --- 2. the probe generation -> encode multiplier ---
    pt = options.ProbeType;
    if isempty(pt),
        if options.PromptForRawFile,
            choice = questdlg(...
                ['Which Neuropixels probe generation produced ' char(binfile) '?'], ...
                'Probe generation', 'Neuropixels 1.0', 'Neuropixels 2.0', 'Neuropixels 1.0');
            switch choice,
                case 'Neuropixels 1.0', pt = 'NP1';
                case 'Neuropixels 2.0', pt = 'NP2';
                otherwise, return; % cancelled
            end;
        else,
            error('ndi:fun:probe:import:kilosort:promptrawbinary:noProbeType', ...
                ['No probe generation available: pass ''ProbeType'' (''NP1'' or ''NP2''; ' ...
                'PromptForRawFile is false, so no dialog is shown).']);
        end;
    end;
    [mult, ptinfo] = ndi.fun.probe.import.kilosort.neuropixelsmultiplier(pt);

    % --- 3. channel count (from meta/params.py n_channels_dat, or override) ---
    nc = baseinfo.num_channels;
    if ~isnan(options.num_channels),
        nc = options.num_channels;
    end;
    if isnan(nc) || nc < 1,
        error('ndi:fun:probe:import:kilosort:promptrawbinary:noChannelCount', ...
            ['Could not determine the number of channels for the selected recording. ' ...
            'No n_channels_dat was found in a .metadata sidecar or params.py near the ' ...
            'curated directory; pass ''num_channels'' explicitly.']);
    end;

    info.file = binfile;
    info.num_channels = nc;
    info.multiplier = mult;
    info.probe_type = ptinfo.name;
    info.found = true;

end
