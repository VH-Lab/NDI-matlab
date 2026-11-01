function b = ingestedBody(st, a, datumType, ax, sid, description, fillValue)
%INGESTEDBODY A sampled_body holding array A for statement ST, INGESTED.
%
%   B = ingestedBody(ST, A, DATUMTYPE, AX, SID, DESCRIPTION) writes A's raw
%   bytes (column-major, little-endian, as DATUMTYPE: 'bool', 'uint8',
%   'uint16', 'float64', ...) to a temporary file, gzips it, and returns the
%   body document, shaped by AX.dimensions (haleyAxes; the covariates are
%   the statement's and are not repeated on the body), whose file the database COPIES into the
%   session's .ndi/files when the session is written and then deletes
%   (files.file_info `ingest` 1, `delete_original` 1). Format
%   binary (EDAM:format_2333; the media type application/octet-stream on an
%   older schema), compression gzip, MD5 of the stored file. The compression
%   is handed to did2.build.sampledBody as the codec name; the builder writes
%   it as the loaded schema declares `compression` -- the char, or the {term,
%   parameters} block once did-schema declares it ([compression block and
%   empty levels], Jess Haley, 2026-10-26; did2.build.compression). With the
%   term registry armed, the block's codec term must then be registered.
%   FILLVALUE (optional, char) is what a position with no value holds.
%   Stage 10, decision #60.

arguments
    st (1,1) struct
    a
    datumType {mustBeText}
    ax (1,1) struct
    sid {mustBeText}
    description {mustBeText}
    fillValue {mustBeText} = ''
end
raw = [tempname '.bin'];
fid = fopen(raw, 'w', 'ieee-le');
switch datumType
    case 'bool',    fwrite(fid, uint8(a), 'uint8');
    case 'float64', fwrite(fid, double(a), 'double');
    case 'float32', fwrite(fid, single(a), 'single');
    otherwise,      fwrite(fid, cast(a, datumType), datumType);
end
fclose(fid);
gz = gzip(raw);
gz = gz{1};
delete(raw);
info = dir(gz);
byteOrder = '';
if ~any(strcmp(datumType, {'bool', 'uint8', 'int8'})), byteOrder = 'little'; end
datumOrder = '';
if numel(ax.dimensionCells) > 1, datumOrder = 'F'; end
b = did2.build.sampledBody(st.base.id, ax.dimensions, 'DatumOrder', datumOrder, ...
    'ByteOrder', byteOrder, 'FillValue', fillValue, ...
    'Format', fileFormat('EDAM:format_2333', 'Binary format'), ...
    'Compression', 'gzip', ...
    'ContentHash', ndi.fun.file.MD5(gz), 'HashAlgorithm', 'MD5', ...
    'Notes', description, 'Fields', struct('size_bytes', info.bytes), 'SessionId', sid);
b.files.file_info = struct('name', 'body_data_0', 'locations', struct( ...
    'delete_original', 1, 'uid', ndi.ido.unique_id(), 'location', gz, ...
    'parameters', '', 'location_type', 'file', 'ingest', 1));
end
