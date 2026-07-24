function info = binaryinfo(kdir, options)
% NDI.FUN.PROBE.IMPORT.KILOSORT.BINARYINFO - locate the raw binary and its parameters
%
% INFO = NDI.FUN.PROBE.IMPORT.KILOSORT.BINARYINFO(KDIR, ...)
%
% Finds the raw int16 binary recording associated with a Kilosort/Phy output
% directory KDIR and returns the parameters needed to read spike waveforms from it.
% This is used by NDI.FUN.PROBE.IMPORT.KILOSORT.PROBE when 'RecalculateMeanWaveforms'
% is true to read wide mean waveforms directly from the binary.
%
% The binary and its parameters are located from (in order):
%
%   1) an explicit 'binary_file' name/value option, if given;
%   2) the NDI export '.metadata' sidecar (written by NDI.FUN.PROBE.EXPORT.BINARY)
%      in KDIR or its parent directory - this gives num_channels and the encode
%      multiplier and names the binary (the sidecar is '<binary>.metadata');
%   3) the Phy 'params.py' file in KDIR - this gives n_channels_dat, dtype, offset,
%      sample_rate, and dat_path (used for externally sorted data such as SpikeGLX).
%
% INFO is a structure with fields:
%   found             - true if a usable binary and channel count were located
%   file              - path to the binary recording ('' if not found)
%   num_channels      - number of interleaved channels (NaN if unknown)
%   dtype             - sample data type ('int16' by default)
%   byteOrder         - byte order for reading ('ieee-le')
%   headerOffsetBytes - bytes to skip at the start of the file (Phy 'offset', 0)
%   multiplier        - encode multiplier int16 = multiplier*physical (1 if unknown)
%   sample_rate       - sampling rate if it could be determined, else NaN
%
% Name/value pairs:
% ---------------------------------------------------------------------------------
% | Parameter (default) | Description                                             |
% |---------------------|---------------------------------------------------------|
% | binary_file ('')    | Explicit path to the binary recording. Overrides the    |
% |                     |   automatic search when given (an error is raised if it |
% |                     |   does not exist).                                      |
% ---------------------------------------------------------------------------------
%
% See also: NDI.FUN.PROBE.IMPORT.KILOSORT.PROBE,
%   NDI.FUN.PROBE.IMPORT.KILOSORT.RECALCULATEMEANWAVEFORM, NDI.FUN.PROBE.EXPORT.BINARY

    arguments
        kdir (1,:) char
        options.binary_file (1,:) char = ''
    end

    info = struct('found', false, 'file', '', 'num_channels', NaN, ...
        'dtype', 'int16', 'byteOrder', 'ieee-le', 'headerOffsetBytes', 0, ...
        'multiplier', 1, 'sample_rate', NaN);

    searchdirs = {kdir};
    parentdir = fileparts(kdir);
    if ~isempty(parentdir) && ~strcmp(parentdir, kdir),
        searchdirs{end+1} = parentdir;
    end;

    binfile = '';

    % --- 1. explicit binary_file option ---
    if ~isempty(options.binary_file),
        if ~isfile(options.binary_file),
            error('ndi:fun:probe:import:kilosort:binaryinfo:noFile', ...
                'Specified binary_file was not found: %s.', options.binary_file);
        end;
        binfile = options.binary_file;
    end;

    % --- 2. NDI export '.metadata' sidecar (num_channels, multiplier, sample rate) ---
    metafile = '';
    for d=1:numel(searchdirs),
        ml = dir(fullfile(searchdirs{d}, '*.metadata'));
        for i=1:numel(ml),
            cand = fullfile(searchdirs{d}, ml(i).name);
            bincand = cand(1:end-numel('.metadata')); % strip '.metadata'
            if isfile(bincand),
                if isempty(binfile),
                    binfile = bincand;
                    metafile = cand;
                elseif strcmp(binfile, bincand),
                    metafile = cand;
                end;
            end;
        end;
        if ~isempty(metafile), break; end;
    end;

    if ~isempty(metafile),
        try
            meta = vlt.file.loadStructArray(metafile);
            % loadStructArray may return numeric fields either as numbers or as
            % their character representation; coerceNumeric handles both.
            if isfield(meta,'num_channels'),
                nc = coerceNumeric(meta(1).num_channels);
                if ~isempty(nc), info.num_channels = nc(1); end;
            end;
            if isfield(meta,'multiplier'),
                m = coerceNumeric(meta(1).multiplier);
                if ~isempty(m), info.multiplier = m(1); end;
            end;
            if isfield(meta,'epoch_sample_rates'),
                sr = coerceNumeric(meta(1).epoch_sample_rates);
                if ~isempty(sr), info.sample_rate = sr(1); end;
            end;
        catch
            % a malformed sidecar just means we fall back to other sources
        end;
    end;

    % --- 3. Phy params.py (dtype, offset, sample_rate, dat_path, n_channels_dat) ---
    ppath = fullfile(kdir, 'params.py');
    if isfile(ppath),
        p = readparamspy(ppath);
        if isnan(info.num_channels) && isfield(p,'n_channels_dat'),
            info.num_channels = p.n_channels_dat;
        end;
        if isfield(p,'dtype') && ~isempty(p.dtype),
            info.dtype = p.dtype;
        end;
        if isfield(p,'offset'),
            info.headerOffsetBytes = p.offset;
        end;
        if isnan(info.sample_rate) && isfield(p,'sample_rate'),
            info.sample_rate = p.sample_rate;
        end;
        if isempty(binfile) && isfield(p,'dat_path') && ~isempty(p.dat_path),
            if isAbsolutePath(p.dat_path),
                cand = p.dat_path;
            else,
                cand = fullfile(kdir, p.dat_path);
            end;
            if isfile(cand),
                binfile = cand;
            end;
        end;
    end;

    if isempty(binfile) || isnan(info.num_channels) || info.num_channels < 1,
        return; % could not locate a usable binary and channel count
    end;

    info.file = binfile;
    info.found = true;

end % binaryinfo

function v = coerceNumeric(x)
% return X as a numeric array whether it arrives as numeric, char, or string
    if isnumeric(x),
        v = double(x);
    elseif ischar(x) || isstring(x),
        v = str2num(char(x)); %#ok<ST2NM> % handles '3', '1000 2000', '[1 2]'
        if isempty(v),
            v = NaN;
        end;
    else,
        v = NaN;
    end;
end % coerceNumeric

function p = readparamspy(ppath)
% minimal parser for a Phy params.py file (key = value, one per line)
    p = struct();
    txt = fileread(ppath);
    lines = regexp(txt, '\r\n|\r|\n', 'split');
    for i=1:numel(lines),
        line = strtrim(lines{i});
        if isempty(line) || line(1)=='#',
            continue;
        end;
        eqp = find(line=='=', 1);
        if isempty(eqp),
            continue;
        end;
        key = strtrim(line(1:eqp-1));
        val = strtrim(line(eqp+1:end));
        % strip a trailing comment
        hp = find(val=='#', 1);
        if ~isempty(hp),
            val = strtrim(val(1:hp-1));
        end;
        switch key,
            case 'dat_path',
                p.dat_path = stripPyString(val);
            case 'n_channels_dat',
                p.n_channels_dat = str2double(val);
            case 'dtype',
                p.dtype = stripPyString(val);
            case 'offset',
                p.offset = str2double(val);
            case 'sample_rate',
                p.sample_rate = str2double(val);
        end;
    end;
end % readparamspy

function s = stripPyString(val)
% remove surrounding quotes and a leading r/b string prefix from a python literal
    s = strtrim(val);
    if ~isempty(s) && (s(1)=='r' || s(1)=='b' || s(1)=='u') && numel(s)>1 && (s(2)=='''' || s(2)=='"'),
        s = s(2:end); % drop the r/b/u prefix
    end;
    if numel(s)>=2 && (s(1)=='''' || s(1)=='"') && s(end)==s(1),
        s = s(2:end-1);
    end;
end % stripPyString

function tf = isAbsolutePath(pth)
% cross-platform absolute path test (POSIX '/...' or Windows 'C:\...' / UNC)
    tf = false;
    if isempty(pth), return; end;
    if pth(1)=='/' || pth(1)=='\',
        tf = true;
    elseif numel(pth)>=2 && isletter(pth(1)) && pth(2)==':',
        tf = true;
    end;
end % isAbsolutePath
