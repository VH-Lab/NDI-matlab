function data = import_kilosort_readNPY(filename)
% NDI.FUN.PROBE.IMPORT_KILOSORT_READNPY - read a NumPy .npy file into a MATLAB array
%
% DATA = NDI.FUN.PROBE.IMPORT_KILOSORT_READNPY(FILENAME)
%
% Reads a NumPy .npy file (format version 1.0 or 2.0) and returns its contents as a
% MATLAB array. This is a small, dependency-free reader sufficient for the numeric
% arrays produced by Kilosort/Phy (spike_times.npy, spike_clusters.npy,
% spike_templates.npy, amplitudes.npy, templates.npy, whitening_mat_inv.npy).
%
% Supports little- and big-endian integer and floating-point dtypes, and both
% C-ordered and Fortran-ordered arrays of any dimensionality. The returned array has
% the same shape as the NumPy array (so a NumPy (nTemplates, nSamples, nChannels)
% array becomes a MATLAB nTemplates-by-nSamples-by-nChannels array).
%
% See also: NDI.FUN.PROBE.IMPORT_KILOSORT

    fid = fopen(filename,'r','l'); % default little-endian; re-opened below if needed
    if fid<0,
        error(['Could not open ' filename ' for reading.']);
    end;
    cleanup = onCleanup(@() fclose(fid));

    % --- magic string and version ---
    magic = fread(fid, 6, '*char')';
    if ~strcmp(magic, sprintf('\x93NUMPY')),
        error([filename ' is not a valid .npy file (bad magic string).']);
    end;
    major = fread(fid, 1, 'uint8=>double');
    fread(fid, 1, 'uint8=>double'); % minor version (unused)

    if major==1,
        header_len = fread(fid, 1, 'uint16=>double');
    else,
        header_len = fread(fid, 1, 'uint32=>double');
    end;

    header = fread(fid, header_len, '*char')';

    % --- parse the header dictionary ---
    descr = regexp(header, '''descr''\s*:\s*''([^'']+)''', 'tokens', 'once');
    if isempty(descr),
        error(['Could not parse descr from .npy header of ' filename '.']);
    end;
    descr = descr{1};

    fortran_tok = regexp(header, '''fortran_order''\s*:\s*(True|False)', 'tokens', 'once');
    fortran_order = ~isempty(fortran_tok) && strcmp(fortran_tok{1},'True');

    shape_tok = regexp(header, '''shape''\s*:\s*\(([^)]*)\)', 'tokens', 'once');
    if isempty(shape_tok),
        error(['Could not parse shape from .npy header of ' filename '.']);
    end;
    shape = str2num(['[' shape_tok{1} ']']); %#ok<ST2NM> parse the tuple contents
    if isempty(shape),
        shape = 1; % 0-d array -> scalar
    end;

    % --- map the NumPy dtype to a MATLAB precision and byte order ---
    byteorder = descr(1);
    typecode = descr(2:end);
    switch byteorder,
        case '<', machine = 'l';
        case '>', machine = 'b';
        otherwise, machine = 'l'; % '|' (not applicable) or absent -> single byte
    end;

    switch typecode,
        case 'i1', precision = 'int8';
        case 'u1', precision = 'uint8';
        case 'i2', precision = 'int16';
        case 'u2', precision = 'uint16';
        case 'i4', precision = 'int32';
        case 'u4', precision = 'uint32';
        case 'i8', precision = 'int64';
        case 'u8', precision = 'uint64';
        case 'f4', precision = 'single';
        case 'f8', precision = 'double';
        otherwise,
            error(['Unsupported .npy dtype ''' descr ''' in ' filename '.']);
    end;

    % --- re-open with the correct byte order and skip to the data ---
    data_offset = ftell(fid);
    clear cleanup; % closes fid
    fid = fopen(filename, 'r', machine);
    cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
    fseek(fid, data_offset, 'bof');

    n = prod(shape);
    data = fread(fid, n, [precision '=>' precision]);

    % --- restore the array shape ---
    if numel(shape)>1,
        if fortran_order,
            data = reshape(data, shape);
        else,
            data = reshape(data, shape(end:-1:1));
            data = permute(data, numel(shape):-1:1);
        end;
    end;

end
