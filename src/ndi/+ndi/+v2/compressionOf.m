function [codec, settings] = compressionOf(value)
%COMPRESSIONOF A body's `compression`, in either shape: the codec and its settings.
%
%   [CODEC, SETTINGS] = ndi.v2.compressionOf(VALUE). VALUE is a body's
%   `data_body.compression` as stored (read it with ndi.v2.blockOf):
%
%     char      (did-schema before [compression block and empty levels]): the
%               codec's name ('gzip', 'lzw', 'blosc-zstd', 'blosc'); SETTINGS
%               is struct()
%     {term, parameters} block  ([compression block and empty levels] (1),
%               Decided by Jess Haley, 2026-10-26, did-schema
%               V_eta_go_forward_class_audit.md; did-schema issue #137): CODEC
%               is the codec as its source spells it ('Blosc' with an `inner
%               compressor` zstd is v1's 'blosc-zstd'), SETTINGS one key ->
%               value per parameter, in order, under the source's keys (cname,
%               clevel, shuffle, blocksize: a v1 lightsheetZarrLevel's
%               codec_params)
%     a bare {node, name} term   as a block with no parameters
%     '' / []   '' and struct(): stored uncompressed
%
%   Readers call this rather than comparing the field to a string, so they
%   read both shapes while the siblings move first (did-schema CLAUDE.md
%   section 3, rule 2): NDI and DID-matlab read the block before did-schema
%   declares it.
%
%   THE READING IS DID-matlab's did2.build.compressionCodec (the inverse of
%   did2.build.compression, the writer every V2 body builder uses), which
%   also resolves a registered codec term through the term registry. When the
%   DID-matlab on the path predates it, a local reading of the same table is
%   used: a term matched by its own name only (gzip, LZW, Blosc), settings by
%   the same variable names. Keep the table below in step with DID-matlab
%   src/did/+did2/+build/private/compressionTable.m.
%
%   See also ndi.v2.readBody, ndi.vintage.lightsheetLevel.

arguments
    value = []
end

if ~isempty(which('did2.build.compressionCodec'))
    [codec, settings] = did2.build.compressionCodec(value);
    return;
end
[codec, settings] = localReading(value);
end

% ===================== the local reading (DID-matlab without it) ===========

function [codec, settings] = localReading(value)
codec = '';
settings = struct();
if isempty(value)
    return;
end
if isstring(value) && isscalar(value), value = char(value); end
if ischar(value)
    codec = strtrim(value);
    return;
end
if iscell(value) && isscalar(value), value = value{1}; end
if ~isstruct(value) || ~isscalar(value)
    error('ndi:v2:compressionOf:badValue', ...
        'A body''s compression is a codec name (char) or a {term, parameters} block.');
end
params = [];
if isfield(value, 'term')
    term = value.term;
    if isfield(value, 'parameters'), params = value.parameters; end
else
    term = value;   % a bare term
end
name = '';
if isstruct(term) && isfield(term, 'name') && ~isempty(term.name), name = strtrim(char(term.name)); end
node = '';
if isstruct(term) && isfield(term, 'node') && ~isempty(term.node), node = strtrim(char(term.node)); end

% {key, variable name}: DID-matlab +build/private/compressionTable.m, settings
keyTable = {'cname', 'inner compressor'; 'clevel', 'compression level'; ...
    'shuffle', 'shuffle'; 'blocksize', 'block size'};
if isstruct(params), params = num2cell(reshape(params, 1, [])); end
if ~iscell(params), params = {}; end
for k = 1:numel(params)
    e = params{k};
    if ~isstruct(e) || ~isfield(e, 'variable'), continue; end
    label = e.variable;
    if isstruct(label), label = label.name; end
    label = strtrim(char(label));
    key = label;
    hit = find(strcmp(squash(keyTable(:, 2)), squashOne(label)), 1);
    if ~isempty(hit), key = keyTable{hit, 1}; end
    settings.(matlab.lang.makeValidName(key)) = entryValue(e);
end

% {spelling, term name, inner compressor}: the same file, codecs
codecTable = {'gzip', 'gzip', ''; 'lzw', 'LZW', ''; 'blosc-zstd', 'Blosc', 'zstd'};
rows = find(strcmp(squash(codecTable(:, 2)), squashOne(name)) | ...
    strcmp(squash(codecTable(:, 1)), squashOne(name)));
if isempty(rows)
    codec = name;
    if isempty(codec), codec = node; end
    return;
end
if all(cellfun(@isempty, codecTable(rows, 3)))
    codec = codecTable{rows(1), 1};
    return;
end
cname = '';
if isfield(settings, 'cname'), cname = lower(strtrim(char(settings.cname))); end
hit = find(strcmpi(codecTable(rows, 3), cname), 1);
if ~isempty(cname) && ~isempty(hit)
    codec = codecTable{rows(hit), 1};
elseif ~isempty(cname)
    codec = [lower(codecTable{rows(1), 2}) '-' cname];
else
    codec = name;
end
end

function v = entryValue(e)
v = [];
if isfield(e, 'text') && ~isempty(e.text)
    v = char(e.text);
elseif isfield(e, 'logical') && ~isempty(e.logical)
    v = logical(e.logical);
elseif isfield(e, 'count') && ~isempty(e.count)
    v = double(e.count);
elseif isfield(e, 'quantity') && isstruct(e.quantity) && isfield(e.quantity, 'value') ...
        && ~isempty(e.quantity.value)
    v = double(e.quantity.value);
elseif isfield(e, 'term') && isstruct(e.term) && isfield(e.term, 'name')
    v = char(e.term.name);
elseif isfield(e, 'text')
    v = '';
end
end

function c = squash(c)
% names compared ignoring case, spaces, underscores and hyphens, as
% did2.schema.termNameKey does
c = cellfun(@(s) lower(regexprep(char(s), '[\s_\-]', '')), c, 'UniformOutput', false);
end

function s = squashOne(s)
s = lower(regexprep(char(s), '[\s_\-]', ''));
end
