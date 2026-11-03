function docs = appParameterDocs(search, name, v1Class, readParams, isValid)
%APPPARAMETERDOCS Find an app's named parameter documents, v1 or migrated `method`.
%
%   DOCS = ndi.vintage.appParameterDocs(SEARCH, NAME, V1CLASS, READPARAMS,
%   ISVALID) finds the parameter set an app saved as NAME, in
%   either shape (issue #1053):
%
%     v1   a V1CLASS document whose `base.name` is NAME (what the app writes);
%     v2   a `method` document whose `method.name` is NAME: DID-matlab's
%          migration folds the v1 settings document into a `method`, keeping
%          its id and putting the preset name in `method.name` (Jess Haley
%          2026-10-30 [preset name stays on method], did-schema
%          did_v2_go_forward_class_audit.md); it writes no `base.name`.
%
%   A `method` carries no class to tell an extraction preset from a sorting
%   preset of the same name, so a `method` is kept only when its parameters,
%   read by READPARAMS (a function handle taking the document and returning
%   the app's v1 parameter struct, e.g. the app's own reader built on
%   ndi.vintage.appParameters, so that settings the migration renamed are
%   restored), pass ISVALID (a function handle taking that struct and
%   returning true, e.g. the app's own isvalid_appdoc_struct). A method whose
%   parameters cannot be read is not kept.
%
%   SEARCH is a function handle taking an ndi.query and returning documents
%   (e.g. @(q) S.database_search(q)). DOCS is a cell array: the v1 documents
%   first, then the methods.
%
%   See also ndi.vintage.appParameters, ndi.app.spikeextractor/find_appdoc,
%   ndi.app.spikesorter/find_appdoc.

arguments
    search function_handle
    name (1,:) char
    v1Class (1,:) char
    readParams function_handle
    isValid function_handle
end

docs = search(ndi.query('base.name', 'exact_string', name, '') & ...
    ndi.query('', 'isa', v1Class, ''));
docs = reshape(docs, 1, []);

mdocs = search(ndi.v2.isaQuery('method') & ...
    ndi.query('method.name', 'exact_string', name, ''));
have = cellfun(@(d) d.id(), docs, 'UniformOutput', false);
for k = 1:numel(mdocs)
    d = mdocs{k};
    if ismember(d.id(), have)
        continue;
    end
    try
        params = readParams(d);
        ok = isstruct(params) && ~isempty(params) && isValid(params);
    catch
        ok = false;
    end
    if ok
        docs{end+1} = d; %#ok<AGROW>
        have{end+1} = d.id(); %#ok<AGROW>
    end
end
end
