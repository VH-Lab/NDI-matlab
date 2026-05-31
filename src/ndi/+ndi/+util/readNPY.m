function [data, shape, dtype] = readNPY(filename)
% ndi.util.readNPY - read a NumPy .npy file into a MATLAB array
%
% [DATA, SHAPE, DTYPE] = ndi.util.readNPY(FILENAME)
%
% Reads a NumPy .npy file (format version 1.0, 2.0, or 3.0) and returns its
% contents as a MATLAB array DATA. This is a small, dependency-free reader for
% numeric (and boolean) NumPy arrays.
%
% Supports little- and big-endian integer, floating-point, and boolean dtypes,
% and both C-ordered and Fortran-ordered arrays of any dimensionality. The
% returned array has the same shape as the NumPy array (so a NumPy
% (A, B, C) array becomes a MATLAB A-by-B-by-C array). A 1-D NumPy array of
% length N is returned as an N-by-1 column vector.
%
% Optional outputs:
%   SHAPE - the NumPy shape as a row vector (the dimensions in NumPy order).
%   DTYPE - the NumPy dtype descriptor string (e.g. '<i8', '<f4', '|b1').
%
% Object/structured dtypes (those whose descr begins with 'O' or describes a
% record type) are not supported and produce an error.
%
% This reader does not require the third-party npy-matlab toolbox.
%
% Example:
%   spike_times = ndi.util.readNPY('spike_times.npy');
%
% See also: FREAD

    fid = fopen(filename,'r','l'); % open little-endian initially; re-opened below if needed
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
    else, % version 2.0 and 3.0 use a 4-byte header length
        header_len = fread(fid, 1, 'uint32=>double');
    end;

    header = fread(fid, header_len, '*char')';

    % --- parse the header dictionary ---
    descr = regexp(header, '''descr''\s*:\s*''([^'']+)''', 'tokens', 'once');
    if isempty(descr),
        error(['Could not parse descr from .npy header of ' filename '.']);
    end;
    dtype = descr{1};

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
    byteorder = dtype(1);
    typecode = dtype(2:end);
    switch byteorder,
        case '<', machine = 'l';
        case '>', machine = 'b';
        otherwise, machine = 'l'; % '|' (not applicable) or absent -> single byte, endianness irrelevant
    end;

    is_bool = false;
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
        case 'b1', precision = 'uint8'; is_bool = true; % read bytes, convert to logical below
        otherwise,
            error(['Unsupported .npy dtype ''' dtype ''' in ' filename '. ' ...
                'Only numeric and boolean arrays are supported.']);
    end;

    % --- re-open with the correct byte order and skip past the header to the data ---
    data_offset = ftell(fid);
    clear cleanup; % closes fid
    fid = fopen(filename, 'r', machine);
    cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
    fseek(fid, data_offset, 'bof');

    n = prod(shape);
    data = fread(fid, n, [precision '=>' precision]);

    if is_bool,
        data = logical(data);
    end;

    % --- restore the array shape (NumPy is row-major / C-order by default) ---
    if numel(shape)>1,
        if fortran_order,
            data = reshape(data, shape);
        else,
            data = reshape(data, shape(end:-1:1));
            data = permute(data, numel(shape):-1:1);
        end;
    end;

end
