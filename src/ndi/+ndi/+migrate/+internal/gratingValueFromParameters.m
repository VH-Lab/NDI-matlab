function value = gratingValueFromParameters(parameters)
%GRATINGVALUEFROMPARAMETERS Map one NDI stimulus parameter struct to a V_eta
%   `visual_grating` value struct.
%
%   A stimulus_presentation's `stimuli(i).parameters` uses the NDI/vhlab field
%   names (angle, sFrequency, tFrequency, contrast, size, isblank). This maps ONE
%   such parameter set to the V_eta visual_grating value shape
%   (angle, spatial_frequency, temporal_frequency, contrast, size, position{x,y},
%   duration, is_blank). It reads the NDI names with snake-case fallbacks; a field
%   that is absent defaults to 0 / false, matching the composite's blank value.
%
%   This is the parameter-mapping core of the (in progress) stimulus_presentation
%   -> visual_grating_manipulation second pass; kept standalone so it is unit
%   -testable independent of the animal resolution and the sampled_body timeline.
%
%   See also: ndi.migrate.internal.bodyResolver (subjectsForPresentation),
%   did-schema visual_grating.
arguments
    parameters (1,1) struct
end

value = struct( ...
    'angle',              getNum(parameters, {'angle', 'orientation'}), ...
    'spatial_frequency',  getNum(parameters, {'sFrequency', 'spatial_frequency', 'sf'}), ...
    'temporal_frequency', getNum(parameters, {'tFrequency', 'temporal_frequency', 'tf'}), ...
    'contrast',           getNum(parameters, {'contrast'}), ...
    'size',               getNum(parameters, {'size'}), ...
    'position',           positionValue(parameters), ...
    'duration',           getNum(parameters, {'duration'}), ...
    'is_blank',           getBool(parameters, {'isblank', 'is_blank', 'blank'}));
end

% ===================== helpers ============================================

function p = positionValue(parameters)
%POSITIONVALUE {x, y} degrees. NDI 'position'/'rect' may be a [x y ...] vector
%   or an {x, y} struct; default {0, 0}.
p = struct('x', 0, 'y', 0);
raw = getRaw(parameters, {'position', 'rect'});
if isnumeric(raw) && numel(raw) >= 2
    p.x = double(raw(1));
    p.y = double(raw(2));
elseif isstruct(raw) && isscalar(raw)
    p.x = getNum(raw, {'x'});
    p.y = getNum(raw, {'y'});
end
end

function v = getNum(s, names)
v = 0;
for i = 1:numel(names)
    if isfield(s, names{i}) && isnumeric(s.(names{i})) && ~isempty(s.(names{i}))
        v = double(s.(names{i})(1));
        return;
    end
end
end

function v = getBool(s, names)
v = false;
for i = 1:numel(names)
    if isfield(s, names{i}) && ~isempty(s.(names{i}))
        raw = s.(names{i});
        if islogical(raw); v = logical(raw(1)); return;
        elseif isnumeric(raw); v = raw(1) ~= 0; return; end
    end
end
end

function raw = getRaw(s, names)
raw = [];
for i = 1:numel(names)
    if isfield(s, names{i}); raw = s.(names{i}); return; end
end
end
