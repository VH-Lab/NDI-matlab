function params = whatVaries_parameterList(stimuli)
% WHATVARIES_PARAMETERLIST - normalize assorted stimulus inputs to a cell list of parameter structs
%
%   PARAMS = ndi.fun.stimulus.whatVaries_parameterList(STIMULI)
%
%   Returns PARAMS, a 1xN cell array of scalar parameter structs pooled from
%   STIMULI, so that the rest of ndi.fun.stimulus can treat every accepted
%   input shape uniformly (and pass PARAMS straight to
%   vlt.data.structwhatvaries).
%
%   STIMULI may be:
%     * an ndi.document (or object array of them) of type
%       'stimulus_presentation'. Parameters are read from
%       DOC.document_properties.stimulus_presentation.stimuli(i).parameters.
%     * a cell array whose entries are any mix of the above ndi.document
%       objects and/or scalar parameter structs. All resulting parameter
%       structs are pooled, in order.
%     * a struct (or struct array) shaped like a document's
%       document_properties, i.e. having a 'stimulus_presentation' field.
%     * a struct array of stimuli, each element having a 'parameters' field
%       (the shape of stimulus_presentation.stimuli).
%     * a struct array of parameter structs directly (the shape of each
%       stimulus_presentation.stimuli(i).parameters).
%
%   See also: ndi.fun.stimulus.whatVaries, ndi.fun.stimulus.whatIsConstant

    params = {};

    if isa(stimuli, 'ndi.document')
        for i = 1:numel(stimuli)
            params = [params, local_docParameters(stimuli(i))]; %#ok<AGROW>
        end
        return;
    end

    if iscell(stimuli)
        for i = 1:numel(stimuli)
            entry = stimuli{i};
            if isa(entry, 'ndi.document')
                params = [params, local_docParameters(entry)]; %#ok<AGROW>
            elseif isstruct(entry) && isscalar(entry)
                params{end+1} = entry; %#ok<AGROW>
            else
                error('ndi:fun:stimulus:whatVaries_parameterList:badCellEntry', ...
                    ['Each cell entry must be an ndi.document or a scalar ' ...
                     'parameter struct.']);
            end
        end
        return;
    end

    if isstruct(stimuli)
        if isfield(stimuli, 'stimulus_presentation')
            % a document_properties-shaped struct (or array of them)
            for i = 1:numel(stimuli)
                params = [params, local_stimuliParameters( ...
                    stimuli(i).stimulus_presentation.stimuli)]; %#ok<AGROW>
            end
        elseif isfield(stimuli, 'parameters')
            % a stimulus_presentation.stimuli-shaped struct array
            params = local_stimuliParameters(stimuli);
        else
            % a struct array of parameter structs
            for i = 1:numel(stimuli)
                params{end+1} = stimuli(i); %#ok<AGROW>
            end
        end
        return;
    end

    error('ndi:fun:stimulus:whatVaries_parameterList:badInput', ...
        ['STIMULI must be an ndi.document, a cell array, or a struct. ' ...
         'Got a %s.'], class(stimuli));
end % whatVaries_parameterList

function params = local_docParameters(doc)
% the parameter structs held in a single stimulus_presentation ndi.document
    dp = doc.document_properties;
    if ~isfield(dp, 'stimulus_presentation')
        error('ndi:fun:stimulus:whatVaries_parameterList:notPresentation', ...
            ['ndi.document (id %s) does not have a stimulus_presentation ' ...
             'field.'], doc.id());
    end
    params = local_stimuliParameters(dp.stimulus_presentation.stimuli);
end % local_docParameters

function params = local_stimuliParameters(stimuli)
% the .parameters of a stimulus_presentation.stimuli struct array
    params = cell(1, numel(stimuli));
    for i = 1:numel(stimuli)
        params{i} = stimuli(i).parameters;
    end
end % local_stimuliParameters
