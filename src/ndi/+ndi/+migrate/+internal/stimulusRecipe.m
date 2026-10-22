function recipe = stimulusRecipe(parameters, kind)
%STIMULUSRECIPE The stimulus RECIPE one NewStim parameter set describes, for
%   EVERY stimulus kind the second pass recognises, as the term and parameter
%   entries of a V_eta `method` document.
%
%   RECIPE = ndi.migrate.internal.stimulusRecipe(PARAMETERS, KIND) maps ONE
%   stimulus_presentation `stimuli(i).parameters` struct, whose NewStim class
%   the caller recognised as KIND (stimulusPresentationToItem newStimKind), to
%
%       recipe.term        the stimulus kind: a term {node, name}, or a name
%                          (a label) when the term registry carries none
%       recipe.parameters  struct array {variable, unit, form, value}:
%                          variable / unit a term struct or a name; form
%                          'quantity' (numeric scalar, in unit), 'matrix'
%                          (numeric array, in unit), 'count' (integer),
%                          'term' (a name) or 'text'
%
%   THE DECISION. Decided by Jess Haley, 2026-10-21 [non-grating stimuli as
%   methods] (did-schema V_eta_method_plan.md, last line): "a visual stimulus
%   that is not a grating (sparse noise / reverse correlation, other noise,
%   disparity, flashed bars, shape movies) migrates the same way as a
%   grating: one `method` document per distinct stimulus, its term naming the
%   stimulus kind and every v1 parameter an entry, a parameter with no
%   ontology term taking a label as its variable. No new class."
%
%   KINDS
%     'grating', 'blank'     ndi.migrate.internal.gratingRecipe, unchanged
%     'stochasticgridstim'   term 'dense noise'         (NewStim verifystochasticgridstim)
%     'blinkingstim'         term 'sparse noise' when `random` is 1, else
%                            'sequential grid flash'    (@blinkingstim verify)
%     'shapemoviestim'       term 'shape movie'         (verifyshapemoviestim)
%     'periodicstim_bars'    term 'uniform luminance field' (periodicstim
%                            imageType 0: "field (single luminance across
%                            field)"; the bar is the window: windowShape, rect)
%     'periodicstim_other'   term 'periodic visual stimulus' (imageType not 0/1/2)
%   Any other KIND is an error: the caller refuses it before asking.
%
%   TERMS. No stimulus-kind term is in the term registry
%   (did-schema V_eta_term_registry.json, 2026-10-21), so every KIND's term is
%   a LABEL ({name}, no node), as the method plan's own grating example is.
%   Registered terms ARE used where one matches (T19):
%     NCIT:C64220 Random Seed     the `randState` variable (data_body AMENDMENT 4)
%     NCIT:C75765 Arbitrary Unit  the unit of every colour (AMENDMENT 4), with
%                                 a separate 'bit depth' count of 8 (NewStim
%                                 colours are 0..255)
%     om:hertz, om:second-Time, om:pixel, EMPTY:0000260 (frame)  units
%
%   EVERY v1 PARAMETER IS AN ENTRY. A field this function names is mapped by
%   the per-class table below; any other field is still written, its variable
%   the v1 field name as a label, its form read from its value (numeric
%   scalar -> quantity, numeric array -> matrix, logical -> count, char ->
%   text). `dispprefs` (NewStim's {name, value, ...} display preferences) is
%   expanded into one entry per pair. Two fields are not entries: `isblank`
%   (0 here; a blank is its own kind) and an empty value (absent is not 0).
%
%   ARRAYS (AMENDMENT 4: one matrix is ONE value). jsondecode reads a flat
%   JSON array as a column, so a vector is written as a 1 x n row, except
%   `randState`, which MATLAB's legacy rand('state') holds as a 35 x 1 column.
%   A flat palette of 3 numbers is one colour, 1 x 3; an n x 3 palette keeps
%   its shape.
%
%   Pure: no database, no schema. stimulusMethod turns a recipe into the
%   document. Two recipes are the same stimulus exactly when isequal says so.
%
%   See also ndi.migrate.internal.gratingRecipe,
%   ndi.migrate.internal.stimulusMethod,
%   ndi.migrate.internal.stimulusPresentationToItem.

arguments
    parameters (1,1) struct
    kind (1,:) char
end

switch kind
    case {'grating', 'blank'}
        recipe = ndi.migrate.internal.gratingRecipe(parameters, kind);
        return;
    case 'stochasticgridstim'
        term = 'dense noise';
        rows = [gridRows(); {'values', 'colour palette', AU, 'palette'; ...
                              'dist', 'colour weights', '', 'row'; ...
                              'angle', 'grid rotation', 'degree', ''}];
    case 'blinkingstim'
        term = 'sequential grid flash';
        r = numberOf(parameters, 'random');
        if ~isempty(r) && r == 1
            term = 'sparse noise';
        end
        rows = [gridRows(); {'value', 'square colour', AU, 'row'; ...
                              'random', 'random order', '', 'count'; ...
                              'repeat', 'repetitions', '', 'count'; ...
                              'bgpause', 'background pause', bgpauseUnit(parameters), ''}];
    case 'shapemoviestim'
        term = 'shape movie';
        rows = {'rect', 'stimulus rectangle', PIXEL, 'row'; ...
                 'BG', 'background colour', AU, 'row'; ...
                 'scale', 'scale', '', ''; ...
                 'fps', 'frame rate', HERTZ, ''; ...
                 'N', 'frame count', '', 'count'; ...
                 'isi', 'inter-stimulus interval', SECOND, ''; ...
                 'angle', 'angle', 'degree', ''; ...
                 'disparity', 'disparity', '', ''};
    case 'periodicstim_bars'
        % Decided by Jess Haley, 2026-10-22 [flashed bar]: imageType 0 drawn
        % in a NARROW oriented rectangle (windowShape 2, short side <= 50 px)
        % is a "flashed bar"; light vs dark stays the flickerType parameter.
        % Anything else keeps "uniform luminance field" (the caller counts it).
        term = 'uniform luminance field';
        if isNarrowRectangle(parameters)
            term = FLASHED_BAR;   % EMPTY:0000366 (did-schema registry, dad8567)
        end
        rows = periodicRows();
    case 'hartleystim'
        % Decided by Jess Haley, 2026-10-22 [Hartley without enumeration]: a
        % hartleystim with no hartley_calc enumeration is one method, term
        % "Hartley stimulus", its raw v1 parameters as entries.
        term = 'Hartley stimulus';
        rows = cell(0, 4);
    case 'periodicstim_other'
        term = 'periodic visual stimulus';
        rows = periodicRows();
    otherwise
        error('ndi:migrate:stimulusRecipe:kind', ...
            'stimulusRecipe: no recipe for stimulus kind ''%s''.', kind);
end

entries = emptyEntries();
names = fieldnames(parameters);
hasColour = false;
for i = 1:numel(names)
    f = names{i};
    v = parameters.(f);
    if strcmp(f, 'isblank') || isempty(v)
        continue;
    end
    if strcmp(f, 'dispprefs')
        entries = addDispprefs(entries, v);
        continue;
    end
    row = find(strcmp(rows(:, 1), f), 1);
    if isempty(row)
        entries = addAuto(entries, f, v);
        continue;
    end
    [variable, unit, shape] = rows{row, 2:4};
    if strcmp(f, 'randState')
        variable = SEED;
    end
    if isstruct(unit) && isequal(unit, AU)
        hasColour = true;
    end
    if strcmp(f, 'pixSize') && isnumeric(v) && any(v(:) < 1)
        % NewStim: a pixSize below 1 is a fraction of `rect`, not pixels
        variable = 'grid square size (fraction of the rectangle)';
        unit = '';
    end
    entries = addTyped(entries, variable, unit, shape, v);
end
if hasColour
    entries(end+1) = entry('bit depth', '', 'count', 8);
end
recipe = struct('term', term, 'parameters', entries);
end

% ===================== tables =============================================

function tf = isNarrowRectangle(p)
%ISNARROWRECTANGLE windowShape 2 (NewStim "oriented rectangle") and a `rect`
%   [x1 y1 x2 y2] whose short side is at most 50 px.
tf = false;
ws = numberOf(p, 'windowShape');
if isempty(ws) || ws ~= 2
    return;
end
if ~isfield(p, 'rect') || ~isnumeric(p.rect) || numel(p.rect) ~= 4
    return;
end
r = double(p.rect(:)');
tf = min(abs(r(3) - r(1)), abs(r(4) - r(2))) <= 50;
end

function t = gridRows()
t = {'rect', 'stimulus rectangle', PIXEL, 'row'; ...
     'BG', 'background colour', AU, 'row'; ...
     'pixSize', 'grid square size', PIXEL, 'row'; ...
     'N', 'frame count', '', 'count'; ...
     'fps', 'frame rate', HERTZ, ''; ...
     'randState', 'Random Seed', '', 'column'};
end

function t = periodicRows()
% NewStim periodicstim (verifyperiodicstim.m); colours chromhigh / chromlow /
% background / backdrop are 0..255 RGB or a 0..1 fraction, so they keep their
% values and take no unit when scalar.
t = {'imageType', 'image type', '', 'count'; ...
     'animType', 'animation type', '', 'count'; ...
     'flickerType', 'flicker type', '', 'count'; ...
     'angle', 'orientation', 'degree', ''; ...
     'chromhigh', 'high colour', AU, 'row'; ...
     'chromlow', 'low colour', AU, 'row'; ...
     'sFrequency', 'spatial frequency', 'cycles per degree', ''; ...
     'sPhaseShift', 'spatial phase', RADIAN, ''; ...
     'distance', 'viewing distance', CENTIMETRE, ''; ...
     'tFrequency', 'temporal frequency', HERTZ, ''; ...
     'barWidth', 'bar width', '', ''; ...
     'rect', 'stimulus rectangle', PIXEL, 'row'; ...
     'nCycles', 'cycle count', '', 'count'; ...
     'contrast', 'contrast', '', ''; ...
     'background', 'background', '', ''; ...
     'backdrop', 'backdrop', '', ''; ...
     'barColor', 'bar colour', '', ''; ...
     'nSmoothPixels', 'smoothing width', PIXEL, ''; ...
     'fixedDur', 'fixed duration', FRAME, ''; ...   % display frames (NewStim loadstim: highVal(1:fixedDur))
     'windowShape', 'window shape', '', 'count'; ...
     'loops', 'loop count', '', 'count'; ...
     'lineoffset', 'line offset', PIXEL, ''; ...
     'linenumber', 'line number', '', 'count'; ...
     'stimnum', 'stimulus number', '', 'count'};
end

function u = bgpauseUnit(p)
% @blinkingstim: bgpause is in frames, or in seconds when fps < 0.
u = FRAME;
fps = numberOf(p, 'fps');
if ~isempty(fps) && fps < 0
    u = SECOND;
end
end

% ===================== registered terms ===================================

function t = FLASHED_BAR
t = struct('node', 'EMPTY:0000366', 'name', 'flashed bar');
end
function t = CENTIMETRE
t = struct('node', 'om:centimetre', 'name', 'centimetre');
end
function t = RADIAN
% NewStim periodicstim: "in radians where 2*pi is 1 cycle" (om:radian,
% did-schema term registry; recorded there as proposed)
t = struct('node', 'om:radian', 'name', 'radian');
end
function t = AU
t = struct('node', 'NCIT:C75765', 'name', 'Arbitrary Unit');
end
function t = SEED
t = struct('node', 'NCIT:C64220', 'name', 'Random Seed');
end
function t = HERTZ
t = struct('node', 'om:hertz', 'name', 'hertz');
end
function t = SECOND
t = struct('node', 'om:second-Time', 'name', 'second');
end
function t = PIXEL
t = struct('node', 'om:pixel', 'name', 'pixel');
end
function t = FRAME
t = struct('node', 'EMPTY:0000260', 'name', 'frame');
end

% ===================== entries ============================================

function e = emptyEntries()
e = struct('variable', {}, 'unit', {}, 'form', {}, 'value', {});
end

function e = entry(variable, unit, form, value)
e = struct('variable', variable, 'unit', unit, 'form', form, 'value', value);
end

function entries = addTyped(entries, variable, unit, shape, v)
if ischar(v) || (isstring(v) && isscalar(v))
    entries(end+1) = entry(variable, '', 'text', char(v));
    return;
end
if islogical(v)
    v = double(v);
end
if ~isnumeric(v)
    entries = addAuto(entries, variableName(variable), v);
    return;
end
v = double(v);
if strcmp(shape, 'count') && isscalar(v) && v == floor(v)
    entries(end+1) = entry(variable, '', 'count', v);
elseif isscalar(v)
    entries(end+1) = entry(variable, unit, 'quantity', v);
else
    entries(end+1) = entry(variable, unit, 'matrix', orient(v, shape));
end
end

function entries = addAuto(entries, name, v)
% A field the table does not name: its v1 name is its variable (a label).
if ischar(v) || (isstring(v) && isscalar(v))
    entries(end+1) = entry(name, '', 'text', char(v));
elseif islogical(v)
    entries(end+1) = entry(name, '', 'count', double(v(1)));
elseif isnumeric(v) && isscalar(v)
    entries(end+1) = entry(name, '', 'quantity', double(v));
elseif isnumeric(v)
    entries(end+1) = entry(name, '', 'matrix', orient(double(v), 'row'));
else
    entries(end+1) = entry(name, '', 'text', jsonencode(v));
end
end

function entries = addDispprefs(entries, v)
% NewStim display preferences: a {name, value, name, value, ...} list
% (jsondecode gives a cell, or a struct when written as one).
pairs = {};
if iscell(v)
    flat = v(:)';
    for k = 1:2:numel(flat) - 1
        pairs(end+1, :) = flat(k:k+1); %#ok<AGROW>
    end
elseif isstruct(v) && isscalar(v)
    fn = fieldnames(v);
    for k = 1:numel(fn)
        pairs(end+1, :) = {fn{k}, v.(fn{k})}; %#ok<AGROW>
    end
end
for k = 1:size(pairs, 1)
    name = char(pairs{k, 1});
    value = pairs{k, 2};
    if isempty(value) && ~ischar(value)
        continue;
    end
    switch name
        case 'BGpretime'
            entries = addTyped(entries, 'background duration before stimulus', ...
                SECOND, '', value);
        case 'BGposttime'
            entries = addTyped(entries, 'background duration after stimulus', ...
                SECOND, '', value);
        otherwise
            entries = addAuto(entries, ['display preference ' name], value);
    end
end
end

function m = orient(v, shape)
if ~isvector(v)
    m = v;                       % a real matrix keeps its shape
elseif strcmp(shape, 'column')
    m = v(:);
else
    m = v(:)';                   % a vector (and a one-colour palette): 1 x n
end
end

function n = variableName(variable)
if isstruct(variable)
    n = variable.name;
else
    n = variable;
end
end

function v = numberOf(s, name)
v = [];
if isfield(s, name) && isnumeric(s.(name)) && ~isempty(s.(name))
    v = double(s.(name)(1));
end
end
