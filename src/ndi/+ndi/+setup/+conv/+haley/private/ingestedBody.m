function b = ingestedBody(st, a, datumType, keys, sid, description, fillValue)
%INGESTEDBODY A sampled_body holding array A for statement ST, INGESTED.
%
%   B = ingestedBody(ST, A, DATUMTYPE, KEYS, SID, DESCRIPTION) writes A's raw
%   bytes (column-major, little-endian, as DATUMTYPE: 'bool', 'uint8',
%   'uint16', 'float64', ...) to a temporary file, gzips it, and returns the
%   body document, keyed by KEYS, whose file the database COPIES into the
%   session's .ndi/files when the session is written and then deletes
%   (files.file_info `ingest` 1, `delete_original` 1). Format
%   application/octet-stream, compression gzip, MD5 of the stored file.
%   FILLVALUE (optional, char) is what a position with no value holds.
%   Stage 10, decision #60.

if nargin < 7
    fillValue = '';
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
if numel(keys) > 1, datumOrder = 'F'; end
b = did2.build.sampledBody(st.base.id, keys, 'DatumOrder', datumOrder, ...
    'ByteOrder', byteOrder, 'FillValue', fillValue, 'Complete', true, ...
    'Format', 'application/octet-stream', 'Compression', 'gzip', ...
    'ContentHash', ndi.fun.file.MD5(gz), 'HashAlgorithm', 'MD5', ...
    'Description', description, 'Fields', struct('size_bytes', info.bytes), 'SessionId', sid);
b.files.file_info = struct('name', 'body_data_0', 'locations', struct( ...
    'delete_original', 1, 'uid', ndi.ido.unique_id(), 'location', gz, ...
    'parameters', '', 'location_type', 'file', 'ingest', 1));
end
