function constant = whatIsConstant(stimuli, options)
% WHATISCONSTANT - which stimulus parameters are held constant across a set of stimuli
%
%   CONSTANT = ndi.fun.stimulus.whatIsConstant(STIMULI)
%   CONSTANT = ndi.fun.stimulus.whatIsConstant(..., 'excludeBlank', TF)
%
%   Returns the parameters that take the same value in every stimulus of
%   STIMULI. A parameter is constant when it is present in every stimulus and
%   its value never changes.
%
%   STIMULI may be given in any of the forms accepted by
%   ndi.fun.stimulus.whatVaries (an ndi.document of type
%   'stimulus_presentation', a cell array of such documents and/or parameter
%   structs, or a struct array of stimuli or parameter structs).
%
%   By default, blank (control) stimuli - those whose parameters have an
%   'isblank' field that is true - are excluded from the comparison. Pass
%   'excludeBlank', false to include them.
%
%   CONSTANT is a struct array (possibly empty) with fields:
%       parameter - the name of the parameter (a char row vector)
%       value     - the single value the parameter takes in every stimulus.
%
%   This is a convenience wrapper: it returns the second output of
%   ndi.fun.stimulus.whatVaries.
%
%   Example:
%       s(1).parameters = struct('angle',0,'contrast',1);
%       s(2).parameters = struct('angle',90,'contrast',1);
%       c = ndi.fun.stimulus.whatIsConstant(s);
%       % c -> struct('parameter','contrast','value',1)
%
%   See also: ndi.fun.stimulus.whatVaries

    arguments
        stimuli
        options.excludeBlank (1,1) logical = true
    end

    [~, constant] = ndi.fun.stimulus.whatVaries(stimuli, ...
        'excludeBlank', options.excludeBlank);
end % whatIsConstant
