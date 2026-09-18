function [meta, metafile] = readspikeglxmeta(binfile)
% NDI.FUN.PROBE.IMPORT.KILOSORT.READSPIKEGLXMETA - read a SpikeGLX '.meta' sidecar
%
% [META, METAFILE] = NDI.FUN.PROBE.IMPORT.KILOSORT.READSPIKEGLXMETA(BINFILE)
%
% Locates and parses the SpikeGLX '.meta' file that accompanies a raw recording
% BINFILE (e.g. 'run_g0_t0.imec0.ap.bin' -> 'run_g0_t0.imec0.ap.meta'). SpikeGLX
% writes the metadata as newline-delimited 'key=value' text; META is returned as a
% struct with one field per key (field names sanitized to be valid MATLAB
% identifiers) whose values are numeric when the whole value parses as a scalar
% number and char otherwise. The channel count of the raw file is 'nSavedChans'.
%
% The '.meta' path is found by replacing BINFILE's final extension with '.meta'; if
% that file does not exist META is returned empty ([]) and METAFILE is ''. This is
% used by NDI.FUN.PROBE.IMPORT.KILOSORT.PROMPTRAWBINARY to obtain the read stride
% (channel count) of a user-selected raw recording, because the raw file's channel
% count (e.g. 385 for a Neuropixels AP band: 384 electrodes + 1 sync) differs from
% the channel count of an NDI export (the probe's electrodes only, e.g. 384).
%
% See also: NDI.FUN.PROBE.IMPORT.KILOSORT.PROMPTRAWBINARY

    arguments
        binfile (1,:) char
    end

    meta = [];

    [pn, fn, ext] = fileparts(binfile); %#ok<ASGLU>
    metafile = fullfile(pn, [fn '.meta']);
    if ~isfile(metafile),
        metafile = '';
        return;
    end;

    txt = fileread(metafile);
    lines = regexp(txt, '\r\n|\r|\n', 'split');

    meta = struct();
    for i=1:numel(lines),
        line = strtrim(lines{i});
        if isempty(line),
            continue;
        end;
        eq = find(line=='=', 1);
        if isempty(eq),
            continue;
        end;
        key = strtrim(line(1:eq-1));
        val = strtrim(line(eq+1:end));
        % SpikeGLX prefixes multi-valued keys with '~'; strip it for a valid field.
        key = regexprep(key, '^~', '');
        key = matlab.lang.makeValidName(key);
        num = str2double(val);
        if ~isnan(num) && isscalar(num),
            meta.(key) = num;
        else,
            meta.(key) = val;
        end;
    end;

end
