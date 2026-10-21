function doc = stimulusMethod(recipe, sessionId, creationTimestamp)
%STIMULUSMETHOD One stimulus, given as a recipe, as a standalone `method`
%   document (did-schema #88, V_eta_method_plan.md, signed 2026-10-21).
%
%   DOC = ndi.migrate.internal.stimulusMethod(RECIPE, SESSIONID, TIMESTAMP)
%   builds the `method` document {term, parameters} for RECIPE (from
%   ndi.migrate.internal.stimulusRecipe / gratingRecipe, or a Hartley basis
%   entry built the same way) with did2.build.method, so the shape is read from the schema in
%   use and never written here. An `item`'s `item_id` names one of these per
%   distinct stimulus.
%
%   A recipe entry's form is 'quantity', 'matrix', 'count', 'term' or 'text';
%   its variable, unit and term are a {node, name} struct where a registered
%   term matches, else a name. Most are LABELS ({name}, no node): the plan
%   says so ("until the term registry carries them -- follow-up (a)"), so
%   the T19 TermRegistry check is off while the document is built, exactly as
%   DID-matlab's batch passes do. Validation is left to the caller's
%   v1_to_v2 fold, as for every other second-pass document.

arguments
    recipe (1,1) struct
    sessionId (1,:) char
    creationTimestamp (1,:) char
end

restore = ndi.migrate.internal.termRegistryOff(); %#ok<NASGU>

entries = {};
for k = 1:numel(recipe.parameters)
    p = recipe.parameters(k);
    switch p.form
        case 'term'
            args = {'Term', p.value};
        case 'count'
            args = {'Count', p.value};
        case 'text'
            args = {'Text', p.value};
        case 'matrix'
            % data_body AMENDMENT 4 (did-schema #88): one numeric array is ONE value
            args = {'Matrix', p.value};
        otherwise
            args = {'Value', p.value};
    end
    if any(strcmp(p.form, {'quantity', 'matrix'})) && ~isempty(p.unit)
        args = [args, {'Unit', p.unit}]; %#ok<AGROW>
    end
    entries{end+1} = did2.build.parameter(p.variable, args{:}); %#ok<AGROW>
end
params = [];
if ~isempty(entries)
    params = did2.build.list(entries{:});
end
doc = did2.build.method(recipe.term, params, 'SessionId', sessionId, ...
    'CreationTimestamp', creationTimestamp, 'Validate', false);
end
