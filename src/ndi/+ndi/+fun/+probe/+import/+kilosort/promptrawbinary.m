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
% already parsed from a Phy 'params.py' - in particular 'dtype', 'headerOffsetBytes'
% and 'sample_rate' - are carried through, because the raw file the user selects has
% the same sample layout as the sort even though the sort's binary itself is missing.
%
% The raw file is obtained from (in order):
%   1) an explicit 'RawFile' option, if given (used for headless/automated runs);
%   2) otherwise, if 'PromptForRawFile' is true, a UIGETFILE dialog.
% The probe generation (which fixes the int16->volts multiplier, see
% NDI.FUN.PROBE.IMPORT.KILOSORT.NEUROPIXELSMULTIPLIER) is obtained from:
%   1) an explicit 'ProbeType' option ('NP1' or 'NP2'), if given;
%   2) otherwise, if 'PromptForRawFile' is true, a QUESTDLG dialog.
%
% CHANNEL COUNT (read stride): this is resolved from the SELECTED raw file, NOT from
% BASEINFO.num_channels. n_channels_dat in params.py (or num_channels in a '.metadata'
% sidecar) describes the file Kilosort actually sorted - which is the one that is
% MISSING here - and it generally differs from the raw file the user selects: a
% Neuropixels AP raw recording has 385 channels (384 electrodes + 1 sync), whereas an
% NDI export has only the probe's electrodes (e.g. 384). Reading a 385-channel file
% with a stride of 384 walks off alignment sample by sample and averages unrelated
% data into flat noise. The stride is therefore taken (in order) from:
%   1) an explicit 'num_channels' (RawNumChannels) override;
%   2) the SpikeGLX '.meta' sidecar next to the raw file ('nSavedChans');
%   3) a user prompt (if 'PromptForRawFile'), else an error.
% The resolved stride is then validated against the file: the usable byte count must
% be an exact multiple of num_channels*bytes-per-sample, and (when 'expectedSamples'
% is given) the implied number of samples/channel must match the probe's epochs. A
% mismatch is a hard error rather than silent noise.
%
% INFO has the same fields as the BINARYINFO result, with 'found' true and 'file',
% 'num_channels' and 'multiplier' filled in for the selected recording, plus a
% 'probe_type' field ('NP1'/'NP2'). If the user cancels any dialog, INFO.found is
% false and the caller falls back to the (narrow) template waveforms.
%
% Name/value pairs:
% ---------------------------------------------------------------------------------
% | Parameter (default)   | Description                                           |
% |-----------------------|-------------------------------------------------------|
% | RawFile ('')          | Explicit path to the raw recording. Skips the file    |
% |                       |   dialog (errors if the file does not exist).         |
% | ProbeType ('')        | 'NP1' or 'NP2'. Skips the probe-generation dialog.    |
% | PromptForRawFile      | If true, use interactive dialogs when RawFile /       |
% |   (true)              |   ProbeType / channel count are not supplied. If      |
% |                       |   false, they must be supplied or an error is raised. |
% | num_channels (NaN)    | Override the read stride (channel count) of the raw   |
% |                       |   file. When NaN, it is read from the SpikeGLX .meta  |
% |                       |   sidecar, else the user is prompted.                 |
% | expectedSamples (NaN) | The probe's total samples/channel across its epochs.  |
% |                       |   When given, the raw file's implied sample count is  |
% |                       |   checked against it to catch a wrong channel count.  |
% ---------------------------------------------------------------------------------
%
% See also: NDI.FUN.PROBE.IMPORT.KILOSORT.PROBE, NDI.FUN.PROBE.IMPORT.KILOSORT.BINARYINFO,
%   NDI.FUN.PROBE.IMPORT.KILOSORT.NEUROPIXELSMULTIPLIER, NDI.FUN.PROBE.IMPORT.KILOSORT.READSPIKEGLXMETA

    arguments
        baseinfo (1,1) struct
        options.RawFile (1,:) char = ''
        options.ProbeType (1,:) char = ''
        options.PromptForRawFile (1,1) logical = true
        options.num_channels (1,1) double = NaN
        options.expectedSamples (1,1) double = NaN
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

    % --- 3. channel count = read stride of the SELECTED raw file ---
    % bytes-per-sample of the raw stream (for stride math and the size guard)
    switch lower(baseinfo.dtype),
        case {'int16','uint16','short','ushort'},        bytesPer = 2;
        case {'int32','int','single','float','float32'},  bytesPer = 4;
        case {'double','float64'},                        bytesPer = 8;
        otherwise,                                        bytesPer = 2;
    end;
    d = dir(binfile);
    usableBytes = d.bytes - baseinfo.headerOffsetBytes;

    % a channel count implied by the file size and the probe's sample count, used
    % only to pre-fill the prompt with a sensible default (whole number or blank)
    suggestNC = NaN;
    if ~isnan(options.expectedSamples) && options.expectedSamples>=1,
        cand = usableBytes / (bytesPer*options.expectedSamples);
        if cand>=1 && abs(cand-round(cand))<1e-6,
            suggestNC = round(cand);
        end;
    end;

    nc = NaN;
    ncsource = '';
    if ~isnan(options.num_channels),
        nc = options.num_channels;              % (1) explicit override
        ncsource = 'RawNumChannels override';
    else,
        sglx = ndi.fun.probe.import.kilosort.readspikeglxmeta(binfile); % (2) .meta
        if ~isempty(sglx) && isfield(sglx,'nSavedChans') && ...
                isnumeric(sglx.nSavedChans) && sglx.nSavedChans>=1,
            nc = sglx.nSavedChans;
            ncsource = 'SpikeGLX .meta (nSavedChans)';
        end;
    end;

    if isnan(nc),                               % (3) ask, or fail in headless mode
        if options.PromptForRawFile,
            defstr = '';
            if ~isnan(suggestNC), defstr = num2str(suggestNC); end;
            answer = inputdlg({['Number of channels in ' char(binfile) '. A Neuropixels ' ...
                'AP raw file is usually 385 (384 electrodes + 1 sync); an NDI export has ' ...
                'only the electrodes (e.g. 384):']}, ...
                'Raw file channel count', 1, {defstr});
            if isempty(answer),
                return; % user cancelled
            end;
            nc = str2double(answer{1});
            ncsource = 'user prompt';
        else,
            error('ndi:fun:probe:import:kilosort:promptrawbinary:noChannelCount', ...
                ['Could not determine the number of channels for the selected raw ' ...
                'recording %s: no ''num_channels'' override and no SpikeGLX ''.meta'' ' ...
                'sidecar was found next to it. Pass ''num_channels'' explicitly ' ...
                '(PromptForRawFile is false, so no dialog is shown).'], binfile);
        end;
    end;

    if isnan(nc) || nc<1 || nc~=round(nc),
        error('ndi:fun:probe:import:kilosort:promptrawbinary:badChannelCount', ...
            'The number of channels for %s must be a positive integer (got %g).', ...
            binfile, nc);
    end;

    % --- 4. validate the stride against the file so a wrong channel count cannot
    % silently produce noise: the usable byte count must be an exact multiple of
    % num_channels*bytesPer, and (if the probe's sample count is known) the implied
    % samples/channel must match it. ---
    if mod(usableBytes, bytesPer*nc) ~= 0,
        error('ndi:fun:probe:import:kilosort:promptrawbinary:strideMismatch', ...
            ['The raw file %s holds %d usable bytes, which is not an exact multiple of ' ...
            '%d channels x %d bytes/sample. The channel count (%d, from %s) is almost ' ...
            'certainly wrong. A Neuropixels AP raw file usually has 385 channels ' ...
            '(384 electrodes + 1 sync); an NDI export has only the electrodes (e.g. 384). ' ...
            'Re-check the channel count (RawNumChannels / the SpikeGLX .meta).'], ...
            binfile, usableBytes, nc, bytesPer, nc, ncsource);
    end;
    impliedSamples = usableBytes / (bytesPer*nc);
    if ~isnan(options.expectedSamples) && options.expectedSamples>=1,
        rel = abs(impliedSamples - options.expectedSamples) / options.expectedSamples;
        if rel > 1e-3,
            error('ndi:fun:probe:import:kilosort:promptrawbinary:durationMismatch', ...
                ['The raw file %s implies %g samples/channel at %d channels (from %s), but ' ...
                'this probe''s epochs span %g samples - a %.2f%% mismatch. The channel ' ...
                'count is likely wrong (a Neuropixels AP raw file usually has 385 channels, ' ...
                'an NDI export 384), or the selected file is not the recording that was ' ...
                'sorted. Re-check the channel count and that this is the sorted recording.'], ...
                binfile, impliedSamples, nc, ncsource, options.expectedSamples, 100*rel);
        end;
    end;

    info.file = binfile;
    info.num_channels = nc;
    info.multiplier = mult;
    info.probe_type = ptinfo.name;
    info.found = true;

end
