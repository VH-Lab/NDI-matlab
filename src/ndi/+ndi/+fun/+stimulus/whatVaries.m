function [varies, constant] = whatVaries(stimuli)
% WHATVARIES - which stimulus parameters vary across a set of stimuli, and which are constant
%
%   [VARIES, CONSTANT] = ndi.fun.stimulus.whatVaries(STIMULI)
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
%   The determination of which parameters vary is made by
%   vlt.data.structwhatvaries: a parameter is CONSTANT when it is present in
%   every stimulus and takes the same value in each; every other parameter
%   (including one present in some stimuli but not all) is VARYING.
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

    params = ndi.fun.stimulus.whatVaries_parameterList(stimuli);

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

    % which fields vary (uses the shared vlt helper, as elsewhere in NDI)
    varyingNames = vlt.data.structwhatvaries(params);

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
            % constant: present in every stimulus with the same value
            constant(end+1) = struct('parameter', thisField, ...
                'value', params{1}.(thisField)); %#ok<AGROW>
        end
    end
end % whatVaries

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
