function recipe = gratingRecipe(parameters, kind)
%GRATINGRECIPE The stimulus RECIPE one NewStim parameter set describes, as the
%   term and parameter entries of a V_eta `method` document.
%
%   RECIPE = ndi.migrate.internal.gratingRecipe(PARAMETERS, KIND) maps ONE
%   stimulus_presentation `stimuli(i).parameters` struct to
%
%       recipe.term        the stimulus kind, a name (a label: the term
%                          registry does not carry these words yet)
%       recipe.parameters  struct array {variable, unit, form, value}:
%                          form 'quantity' (value numeric, in unit) or
%                          'term' (value a name)
%
%   KIND is the NewStim class the caller recognised (stimulusPresentationToItem
%   newStimKind): 'grating' or 'blank'. Every other kind is
%   ndi.migrate.internal.stimulusRecipe's, which calls this for these two.
%
%   THE SHAPE IS did-schema #88's (V_eta_method_plan.md, signed 2026-10-21):
%   "Stimuli given as a recipe are `method` documents ... term 'drifting
%   sinusoidal grating', parameters orientation / spatial frequency /
%   temporal frequency / contrast / waveform ... A blank is its own `method`
%   document." `visual_grating` (the class this replaced) is deleted, and so
%   is gratingValueFromParameters, which mapped onto it.
%
%   WHAT IS READ, AND ONLY WHAT IS PRESENT IS WRITTEN. An absent NewStim field
%   is left out of the list rather than written as 0 (the old value filled
%   absent fields with 0, which reads as a measurement):
%       angle       -> orientation          unit degree
%       sFrequency  -> spatial frequency    unit cycles per degree
%       tFrequency  -> temporal frequency   unit hertz
%       contrast    -> contrast             (no unit)
%       imageType   -> waveform             2 sinusoid, 1 square wave
%   imageType 2 = sine, 1 = square is the reading the grating guard already
%   uses; NDI's own Briggs reader writes `imageType = 2; % assume sinewave`
%   (+ndi/+setup/+daq/+metadatareader/BriggsStims.m:115). The waveform also
%   names the term ('drifting sinusoidal grating' / 'drifting square-wave
%   grating'); a periodicstim with no imageType is a 'drifting grating'.
%
%   A BLANK IS A BLANK WHATEVER ITS CLASS (Jess Haley, 2026-10-21): term
%   'blank screen', no parameters -- the plan's own example.
%
%   Pure: no database, no schema. stimulusMethod turns a recipe into the
%   document. Two recipes are the same stimulus exactly when isequal says so,
%   which is the dedup the caller does.
%
%   See also ndi.migrate.internal.stimulusMethod,
%   ndi.migrate.internal.stimulusPresentationToItem.

arguments
    parameters (1,1) struct
    kind (1,:) char = 'grating'
end

entries = struct('variable', {}, 'unit', {}, 'form', {}, 'value', {});
if strcmp(kind, 'blank')
    recipe = struct('term', 'blank screen', 'parameters', entries);
    return;
end

entries = addNumber(entries, parameters, {'angle', 'orientation'}, ...
    'orientation', 'degree');
entries = addNumber(entries, parameters, {'sFrequency', 'spatial_frequency', 'sf'}, ...
    'spatial frequency', 'cycles per degree');
entries = addNumber(entries, parameters, {'tFrequency', 'temporal_frequency', 'tf'}, ...
    'temporal frequency', 'hertz');
entries = addNumber(entries, parameters, {'contrast'}, 'contrast', '');

term = 'drifting grating';
[t, have] = getNum(parameters, {'imageType'});
if have && t == 2
    term = 'drifting sinusoidal grating';
    entries(end+1) = struct('variable', 'waveform', 'unit', '', ...
        'form', 'term', 'value', 'sinusoid');
elseif have && t == 1
    term = 'drifting square-wave grating';
    entries(end+1) = struct('variable', 'waveform', 'unit', '', ...
        'form', 'term', 'value', 'square wave');
end
recipe = struct('term', term, 'parameters', entries);
end

% ===================== helpers ============================================

function entries = addNumber(entries, s, names, variable, unit)
[v, have] = getNum(s, names);
if have
    entries(end+1) = struct('variable', variable, 'unit', unit, ...
        'form', 'quantity', 'value', v);
end
end

function [v, present] = getNum(s, names)
v = 0;
present = false;
for i = 1:numel(names)
    if isfield(s, names{i}) && isnumeric(s.(names{i})) && ~isempty(s.(names{i}))
        v = double(s.(names{i})(1));
        present = true;
        return;
    end
end
end
