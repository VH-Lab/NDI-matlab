function [values, info] = readBody(container, bodyDoc, datumType, keys)
%READBODY Decode a sampled_body's bytes into a MATLAB array.
%
%   [VALUES, INFO] = ndi.v2.readBody(CONTAINER, BODYDOC, DATUMTYPE) reads the
%   file of the sampled_body BODYDOC (through CONTAINER's database, so an
%   ingested file is read from the file store and one recorded by location
%   where it is), gunzips it when `compression` is gzip, and decodes it as
%   DATUMTYPE (the OWNER statement's data_type.datum_type: the one place the
%   type lives; a body never repeats it) in the body's `byte_order`, shaped
%   by its keys (`n` per key) in its `datum_order` (F column-major, C
%   row-major). INFO has the file path and the shape. KEYS (optional) are
%   the keys to shape by, normally the owner statement's data.keys; when
%   empty the body's own are used.
%
%   One file per body (one chunk); a chunked body is an error for now.
%
%   See also ndi.statement/value, ndi.value.

if nargin < 4, keys = []; end
p = ndi.v2.props(bodyDoc);
fi = [];
if isfield(p, 'files') && isfield(p.files, 'file_info'), fi = p.files.file_info; end
if isempty(fi)
    error('ndi:v2:noBodyFile', 'Body %s records no file.', char(p.base.id));
end
if numel(fi) > 1
    error('ndi:v2:chunkedBody', ['Body %s is chunked (%d files); reading chunked ' ...
        'bodies is not built yet.'], char(p.base.id), numel(fi));
end
name = char(fi(1).name);
[tf, file] = container.database_existbinarydoc(char(p.base.id), name);
if ~tf
    error('ndi:v2:bodyFileMissing', 'The file "%s" of body %s is not on this computer.', ...
        name, char(p.base.id));
end
info = struct('file', file, 'shape', []);

raw = file;
cleanup = [];
if strcmpi(char(ndi.v2.blockOf(p, 'data_body', 'compression', '')), 'gzip')
    tmp = [tempname '.gz'];
    copyfile(file, tmp);
    out = gunzip(tmp);
    raw = out{1};
    cleanup = onCleanup(@() deleteQuietly({tmp, raw}));
end

order = 'ieee-le';
if strcmpi(char(ndi.v2.blockOf(p, 'sampled_body', 'byte_order', '')), 'big'), order = 'ieee-be'; end
[precision, post] = precisionOf(datumType);
fid = fopen(raw, 'r', order);
if fid < 0
    error('ndi:v2:bodyOpen', 'Could not open %s.', raw);
end
values = fread(fid, Inf, precision);
fclose(fid);
values = post(values);

% shape: one size per key (KEYS when given: the owner statement's)
if isempty(keys), keys = ndi.v2.blockOf(p, 'data', 'keys', []); end
keys = ndi.v2.entries(keys);
sz = [];
for k = 1:numel(keys)
    if isfield(keys{k}, 'n') && ~isempty(keys{k}.n), sz(end+1) = double(keys{k}.n); end %#ok<AGROW>
end
if numel(sz) == numel(keys) && ~isempty(sz) && prod(sz) == numel(values)
    if numel(sz) == 1
        values = reshape(values, sz, 1);
    elseif strcmpi(char(ndi.v2.blockOf(p, 'sampled_body', 'datum_order', 'F')), 'C')
        values = permute(reshape(values, fliplr(sz)), numel(sz):-1:1);
    else
        values = reshape(values, sz);
    end
    info.shape = sz;
end
clear cleanup
end

function [precision, post] = precisionOf(t)
post = @(x) x;
switch char(t)
    case 'float64', precision = 'double=>double';
    case 'float32', precision = 'single=>single';
    case 'bool',    precision = 'uint8=>uint8'; post = @(x) logical(x);
    case 'utf8',    precision = 'uint8=>char';
    case {'uint8', 'uint16', 'uint32', 'uint64', 'int8', 'int16', 'int32', 'int64'}
        precision = [char(t) '=>' char(t)];
    otherwise
        error('ndi:v2:datumType', 'Reading datum_type "%s" is not built yet.', char(t));
end
end

function deleteQuietly(files)
for k = 1:numel(files)
    if isfile(files{k}), delete(files{k}); end
end
end
