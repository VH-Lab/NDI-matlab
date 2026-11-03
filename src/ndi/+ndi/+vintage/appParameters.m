function params = appParameters(doc, block, fieldNames, options)
%APPPARAMETERS An app's saved parameter set, from a v1 document or a migrated `method`.
%
%   PARAMS = ndi.vintage.appParameters(DOC, BLOCK, FIELDNAMES, ...) returns the
%   parameter struct an NDI app saved under a name, whichever shape DOC has:
%
%     v1      DOC.document_properties.(BLOCK), returned as stored (e.g.
%             BLOCK 'spike_extraction_parameters' or 'sorting_parameters').
%     v2      a `method` document, as DID-matlab's migration writes a v1
%             settings document (+migrators_j/private/jMethodParameters.m):
%             the preset's name in `method.name` (Jess Haley 2026-10-30
%             [preset name stays on method], did-schema
%             did_v2_go_forward_class_audit.md) and each v1 setting as one
%             entry of `method.parameters`, its `variable` the v1 field name
%             with underscores as spaces (jParameterList).
%
%   For the v2 shape each entry becomes one field of PARAMS. An entry's
%   variable is its label; a label jParameterList wrote for a nested v1
%   field ('filter.do filter') is read by its last part ('do filter').
%   FIELDNAMES (a cellstr) are the v1 field names the app reads; a label is
%   matched to one of them without case, spaces, hyphens or underscores. A
%   label that matches none is kept under its own name (underscores for
%   spaces and hyphens), unless 'Aliases' names it.
%
%   Options:
%     'Aliases'  an N-by-2 cellstr {label, field; ...}: a label the migration
%                gave a setting in place of its v1 name (e.g. 'refractory
%                period' for refractory_time), stored as FIELD. The caller
%                rebuilds anything the migration computed.
%   An entry's value is read with ndi.v2.entryValue; a text value that is
%   JSON (jParameterList writes a value that is not a scalar or a string as
%   JSON) is decoded.
%
%   PARAMS is [] when DOC has neither shape.
%
%   See also ndi.vintage.appParameterDocs, ndi.app.spikeextractor,
%   ndi.app.spikesorter.

arguments
    doc
    block (1,:) char
    fieldNames cell = {}
    options.Aliases cell = cell(0, 2)
end

if isa(doc, 'did.document')
    p = doc.document_properties;
else
    p = doc;
end
params = [];
if ~isstruct(p)
    return;
end
if isfield(p, block)
    params = p.(block);
    return;
end
if ~(isfield(p, 'method') && isstruct(p.method) && ~isempty(p.method) ...
        && isfield(p.method, 'parameters'))
    return;
end
mp = p.method(1).parameters;
params = struct();
keys = cellfun(@spellingKey, fieldNames, 'UniformOutput', false);
aliasKeys = cellfun(@spellingKey, options.Aliases(:, 1), 'UniformOutput', false);
for k = 1:numel(mp)
    if iscell(mp), c = mp{k}; else, c = mp(k); end
    if ~isstruct(c) || ~isfield(c, 'variable')
        continue;
    end
    label = ndi.v2.termName(c.variable);
    if isempty(label)
        continue;
    end
    parts = strsplit(char(label), '.');
    label = strtrim(parts{end});
    m = find(strcmp(spellingKey(label), keys), 1);
    a = find(strcmp(spellingKey(label), aliasKeys), 1);
    if ~isempty(m)
        name = fieldNames{m};
    elseif ~isempty(a)
        name = options.Aliases{a, 2};
    else
        name = matlab.lang.makeValidName(regexprep(label, '[\s-]', '_'));
    end
    [v, ~, kind] = ndi.v2.entryValue(c);
    if strcmp(kind, 'text')
        v = decodeJson(v);
    end
    params.(name) = v;
end
end

function k = spellingKey(name)
% compared without case, spaces, hyphens or underscores, as
% ndi.vintage.syncruleParameters compares method parameter labels
k = lower(regexprep(char(name), '[\s_-]', ''));
end

function v = decodeJson(v)
% a value jParameterList wrote as JSON (an array or a struct); other text as is
t = strtrim(char(v));
if isempty(t) || ~any(t(1) == '[{')
    return;
end
try
    v = jsondecode(t);
catch
end
end
