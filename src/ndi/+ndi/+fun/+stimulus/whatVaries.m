function [varies, constant] = whatVaries(stimuli, options)
% WHATVARIES - which stimulus parameters vary across a set of stimuli, and which are constant
%
%   [VARIES, CONSTANT] = ndi.fun.stimulus.whatVaries(STIMULI)
%   [VARIES, CONSTANT] = ndi.fun.stimulus.whatVaries(..., 'excludeBlank', TF)
%
%   Examines a collection of stimuli and reports which of their parameters
%   vary across the collection and which are held constant.
%
%   STIMULI may be provided in any of the following forms (see
%   ndi.fun.stimulus.whatVaries_parameterList for the details):
%     * an ndi.document (or object array) of type 'stimulus_presentation';
%     * a cell array mixing such ndi.document objects and/or parameter
%       structs (all resulting stimuli are pooled together);
%     * a struct shaped like a document's document_properties (i.e. having a
%       'stimulus_presentation' field);
%     * a struct array of stimuli, each with a 'parameters' field (the shape
%       of stimulus_presentation.stimuli);
%     * a struct array of parameter structs directly.
%
%   By default, blank (control) stimuli are excluded from the comparison: a
%   stimulus is treated as blank when its parameters have an 'isblank' field
%   whose value is true (1). Pass 'excludeBlank', false to include them.
%
%   A parameter is CONSTANT when it is present in every (considered) stimulus
%   and takes the same value in each; every other parameter (including one
%   present in some stimuli but not all) is VARYING. Value equality is tested
%   with ISEQUALN, so a parameter that is NaN in every stimulus is CONSTANT.
%   This is a deliberate deviation from vlt.data.structwhatvaries, which
%   compares with vlt.data.eqlen (a bare '=='), where NaN ~= NaN makes an
%   all-NaN parameter report as VARYING over a single distinct value. See
%   local_varyingFields.
%
%   VARIES is a struct array (possibly empty) with fields:
%       parameter - the name of the parameter (a char row vector)
%       values    - the distinct values the parameter takes across the
%                   stimuli. When every value is a numeric or logical scalar
%                   this is a sorted numeric/logical row vector (well suited
%                   to mat2str); otherwise it is a cell array of the distinct
%                   values in order of first appearance.
%
%   CONSTANT is a struct array (possibly empty) with fields:
%       parameter - the name of the parameter (a char row vector)
%       value     - the single value the parameter takes in every stimulus.
%
%   Parameters are reported in the order in which they are first encountered.
%
%   Example:
%       s(1).parameters = struct('angle',0,'contrast',1,'sFrequency',0.5);
%       s(2).parameters = struct('angle',90,'contrast',1,'sFrequency',0.5);
%       s(3).parameters = struct('angle',180,'contrast',1,'sFrequency',0.5);
%       [v,c] = ndi.fun.stimulus.whatVaries(s);
%       % v.parameter -> 'angle', v.values -> [0 90 180]
%       % c(1) -> struct('parameter','contrast','value',1), etc.
%
%   See also: ndi.fun.stimulus.whatIsConstant,
%             ndi.fun.stimulus.whatVaries_parameterList,
%             vlt.data.structwhatvaries, mat2str

    arguments
        stimuli
        options.excludeBlank (1,1) logical = true
    end

    params = ndi.fun.stimulus.whatVaries_parameterList(stimuli);

    if options.excludeBlank
        keep = true(1, numel(params));
        for i = 1:numel(params)
            keep(i) = ~local_isBlank(params{i});
        end
        params = params(keep);
    end

    varies   = struct('parameter', {}, 'values', {});
    constant = struct('parameter', {}, 'value',  {});

    if isempty(params)
        return;
    end

    % the union of parameter names, in order of first appearance
    fields = {};
    for i = 1:numel(params)
        fields = union(fields, fieldnames(params{i}), 'stable');
    end

    % which fields vary. This mirrors the semantics of vlt.data.structwhatvaries
    % (a field varies if it is absent from some stimulus, or its value differs
    % from the first stimulus's), but is implemented locally: structwhatvaries
    % concatenates a char field name onto its accumulator (cat(1,descr,bothfn{j}))
    % and throws when the set of stimuli reduces to a single common field, which
    % can happen with real stimulus data.
    varyingNames = local_varyingFields(params);

    n = numel(params);

    for f = 1:numel(fields)
        thisField = fields{f};

        if ismember(thisField, varyingNames)
            % gather the values from the stimuli that have this parameter
            vals = {};
            for i = 1:n
                if isfield(params{i}, thisField)
                    vals{end+1} = params{i}.(thisField); %#ok<AGROW>
                end
            end
            uv = local_uniqueValues(vals);
            varies(end+1) = struct('parameter', thisField, ...
                'values', {uv}); %#ok<AGROW>
        else
            % constant: present in every stimulus with the same value. The
            % value is wrapped in a cell so that a cell-array-valued parameter
            % does not make struct() build a struct array.
            constant(end+1) = struct('parameter', thisField, ...
                'value', {params{1}.(thisField)}); %#ok<AGROW>
        end
    end
end % whatVaries

function names = local_varyingFields(params)
% the parameter names that vary across the cell list of parameter structs
% PARAMS. Follows vlt.data.structwhatvaries: each struct is compared to the
% first, and a field is "varying" if it is present in only one of the two, or
% present in both but with unequal values. Two deliberate departures:
%
%   names are accumulated as CELLS, so a lone common field does not trigger
%   the char/cell concatenation error structwhatvaries throws.
%
%   equality is ISEQUALN, not vlt.data.eqlen. eqlen bottoms out in a bare
%   '==', so eqlen(NaN,NaN) is false and a parameter that is NaN in every
%   stimulus was reported VARYING -- over exactly one distinct value, because
%   local_uniqueValues below already uses isequaln and collapses the NaNs.
%   That self-contradiction is the bug this fixes; isequaln also agrees with
%   eqlen on every non-NaN case here and, unlike '==', is defined for the
%   struct- and cell-valued parameters real stimulus data carries.
    names = {};
    if isempty(params)
        return;
    end
    ref = params{1};
    refFields = fieldnames(ref);
    for i = 2:numel(params)
        theseFields = fieldnames(params{i});
        names = [names; setdiff(theseFields, refFields); ...
            setdiff(refFields, theseFields)]; %#ok<AGROW>
        common = intersect(refFields, theseFields);
        for j = 1:numel(common)
            if ~isequaln(ref.(common{j}), params{i}.(common{j}))
                names = [names; common(j)]; %#ok<AGROW>
            end
        end
    end
    names = unique(names);
end % local_varyingFields

function tf = local_isBlank(p)
% a stimulus is blank when its parameters have an 'isblank' field that is
% true (e.g. the numeric 1 written by the stimulus decoder for control stimuli)
    tf = false;
    if isfield(p, 'isblank')
        v = p.isblank;
        tf = ~isempty(v) && all(logical(v(:)));
    end
end % local_isBlank

function uv = local_uniqueValues(vals)
% the distinct values in VALS (a cell array). A sorted numeric/logical row
% vector when every value is a numeric/logical scalar, otherwise a cell
% array of the distinct values in order of first appearance.
    allScalar = ~isempty(vals);
    for i = 1:numel(vals)
        if ~((isnumeric(vals{i}) || islogical(vals{i})) && isscalar(vals{i}))
            allScalar = false;
            break;
        end
    end

    if allScalar
        arr = [vals{:}];
        uv = unique(arr);           % sorted ascending
        nanMask = isnan(uv);
        if sum(nanMask) > 1         % unique() keeps NaNs distinct; collapse them
            uv = [uv(~nanMask), NaN];
        end
        return;
    end

    uv = {};
    for i = 1:numel(vals)
        seen = false;
        for j = 1:numel(uv)
            if isequaln(uv{j}, vals{i})
                seen = true;
                break;
            end
        end
        if ~seen
            uv{end+1} = vals{i}; %#ok<AGROW>
        end
    end
end % local_uniqueValues
