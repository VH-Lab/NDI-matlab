function out = dtypeName(dtype, form)
% NDI.FUN.DOC.LIGHTSHEET.DTYPENAME - a voxel type as a Zarr dtype or a MATLAB class
%
%   OUT = ndi.fun.doc.lightsheet.dtypeName(DTYPE, 'zarr')    % e.g. '<u2'
%   OUT = ndi.fun.doc.lightsheet.dtypeName(DTYPE, 'matlab')  % e.g. 'uint16'
%
%   lightsheetZarrPyramid and lightsheetZarrLevel documents record the
%   dtype as the Zarr (NumPy) dtype string, '<u2', little-endian; the
%   code that reads and builds chunks works with the MATLAB class,
%   'uint16'. DTYPE may be either form, or a Zarr v3 name ('uint16',
%   'float32'), so documents written before the dtype was normalized
%   ('uint16') read the same. Byte order is not converted: chunks are
%   little-endian (the documents' byte_order).
%
%   Example:
%       ndi.fun.doc.lightsheet.dtypeName('uint16', 'zarr')   % '<u2'
%       ndi.fun.doc.lightsheet.dtypeName('<f4', 'matlab')    % 'single'

    arguments
        dtype
        form (1,:) char {mustBeMember(form, {'zarr', 'matlab'})}
    end
    d = lower(strtrim(char(dtype)));
    if ~isempty(d) && any(d(1) == '<>|=')
        d = d(2:end);
    end
    switch d
        case {'uint8', 'u1'},                 m = 'uint8';   z = '|u1';
        case {'int8', 'i1'},                  m = 'int8';    z = '|i1';
        case {'uint16', 'u2'},                m = 'uint16';  z = '<u2';
        case {'int16', 'i2'},                 m = 'int16';   z = '<i2';
        case {'uint32', 'u4'},                m = 'uint32';  z = '<u4';
        case {'int32', 'i4'},                 m = 'int32';   z = '<i4';
        case {'uint64', 'u8'},                m = 'uint64';  z = '<u8';
        case {'int64', 'i8'},                 m = 'int64';   z = '<i8';
        case {'single', 'float32', 'f4'},     m = 'single';  z = '<f4';
        case {'double', 'float64', 'f8'},     m = 'double';  z = '<f8';
        case {'logical', 'bool', 'b1', '?'},  m = 'logical'; z = '|b1';
        otherwise
            error('NDI:lightsheet:dtypeName:unknown', ...
                'Unknown voxel type ''%s''.', char(dtype));
    end
    if strcmp(form, 'zarr')
        out = z;
    else
        out = m;
    end
end
