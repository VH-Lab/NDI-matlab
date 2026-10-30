function params = recipeParameterList(entries)
%RECIPEPARAMETERLIST Recipe parameter entries as a did2.build parameter list.
%
%   PARAMS = ndi.migrate.internal.recipeParameterList(ENTRIES) turns the
%   struct array ENTRIES ({variable, unit, form, value[, source_value,
%   source_unit]}, from ndi.migrate.internal.stimulusRecipe / gratingRecipe)
%   into the `parameters` of a did-schema #88 method block, each entry made
%   with did2.build.parameter. [] when ENTRIES is empty.
%
%   Used for a standalone method document (ndi.migrate.internal.stimulusMethod)
%   and for a manipulation's own inline method parameters
%   (ndi.migrate.internal.stimulusPresentationToItem, [Hartley settings on
%   the inline method]). The caller turns the term registry off while it
%   builds (most variables are labels).

out = {};
for k = 1:numel(entries)
    p = entries(k);
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
    % a converted quantity keeps what the source wrote (did2.build.parameter
    % 'SourceValue' as text, 'SourceUnit' the source's unit term)
    if isfield(p, 'source_value') && ~isempty(p.source_value)
        args = [args, {'SourceValue', p.source_value}]; %#ok<AGROW>
    end
    if isfield(p, 'source_unit') && ~isempty(p.source_unit)
        args = [args, {'SourceUnit', p.source_unit}]; %#ok<AGROW>
    end
    out{end+1} = did2.build.parameter(p.variable, args{:}); %#ok<AGROW>
end
params = [];
if ~isempty(out)
    params = did2.build.list(out{:});
end
end
