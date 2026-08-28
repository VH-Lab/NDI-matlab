function [parameters, displayOrder] = extractStimulusParameters(analyzer)
%extractStimulusParameters Extracts stimulus parameters and display order from an analyzer structure.
%
%   SYNTAX:
%   [parameters, displayOrder] = extractStimulusParameters(analyzer)
%
%   DESCRIPTION:
%   Processes a MATLAB 'analyzer' structure storing experimental stimulus
%   information. Extracts parameters for each unique stimulus condition and
%   the trial-by-trial display sequence. Consolidates parameters from
%   analyzer.M (global), analyzer.P.param (primary), and
%   analyzer.loops.conds{i} (condition-specific). Throws errors for data
%   inconsistencies previously handled by warnings. Handles zero-trial
%   experiments gracefully by returning an empty displayOrder.
%
%   The 'trialno' of a repeat is its position within the stimulus
%   presentation sequence, so the length of the sequence is the largest
%   'trialno' recorded, not the number of repeats stored in the file. A run
%   that was aborted before all of its planned trials were presented records
%   fewer repeats than the sequence has positions; that is a valid file, and
%   the positions with no recorded trial are returned as NaN rather than
%   treated as an error. A repeat whose 'trialno' is empty likewise records a
%   trial that was never presented, and is skipped.
%
%   INPUTS:
%   analyzer (struct): MATLAB structure with experiment details. Must contain
%                      appropriately structured fields 'M', 'P', and 'loops'.
%       - M:        (Expected) Struct with common parameters.
%       - P:        (Expected) Struct with 'param' cell array.
%                   `P.param{k}` typically contains {'Name', 'Type', Value, ...}.
%                   The Value (3rd element) is extracted directly.
%       - loops:    (Expected) Struct with 'conds' cell array.
%                   `loops.conds{i}` defines condition 'i' with 'symbol',
%                   'val', 'repeats' fields. `loops.conds{i}.val{j}` is the
%                   direct value for `loops.conds{i}.symbol{j}`.
%                   `loops.conds{i}.repeats{j}` has 'trialno' field.
%
%   OUTPUTS:
%   parameters (cell array): 1xN cell array (N=conditions). parameters{i}
%                            is a struct with combined parameters for condition i.
%   displayOrder (numeric vector): 1xT vector, where T is the highest trial
%                                  number recorded. displayOrder(k)=i means
%                                  the stimulus presented at position k of
%                                  the sequence used condition i. Positions
%                                  with no recorded trial are NaN. Empty ([])
%                                  if no trials are found.
%
%   EXAMPLE (based on provided structure snippets):
%   [params, order] = extractStimulusParameters(analyzer);
%   % params{1} has fields from M, P, and loops.conds{1} (e.g., ori=0, t_period=15)
%   % order(52) == 1 (if analyzer.loops.conds{1}.repeats{4}.trialno == 52)

arguments
    analyzer (1,1) struct % Basic validation: input must be a scalar struct
end

% --- Detailed Input Structure Validation ---
validateAnalyzerStructure(analyzer); % Call custom validation function

% --- Initialization ---
numConditions = length(analyzer.loops.conds);
parameters = cell(1, numConditions);

% Determine the length of the stimulus presentation sequence. Each repeat
% records the position it occupied in that sequence, so the sequence length
% is the largest position recorded. It is not the number of repeats stored:
% a run that was aborted partway through records fewer repeats than the
% sequence has positions. The validator guarantees 'repeats' is a cell.
sequenceLength = 0;
for i = 1:numConditions
    condRepeats = analyzer.loops.conds{i}.repeats;
    for j = 1:length(condRepeats)
        trialNum = readTrialNumber(condRepeats{j}, i, j);
        if ~isempty(trialNum)
            sequenceLength = max(sequenceLength, trialNum);
        end
    end
end

if sequenceLength == 0
    % Valid zero-trial case; no warning needed
    displayOrder = [];
else
    displayOrder = nan(1, sequenceLength);
end

% --- Parameter Extraction and Display Order Mapping ---

mFields = fieldnames(analyzer.M);

% Process P parameters once
pParams = struct();
for k = 1:length(analyzer.P.param)
    paramCell = analyzer.P.param{k};
    if iscell(paramCell) && numel(paramCell) >= 3 && ischar(paramCell{1})
        paramName = paramCell{1};
        paramValue = paramCell{3}; % Assume direct value

        if isvarname(paramName)
            pParams.(paramName) = paramValue;
        else
            error('extractStimulusParameters:invalidPName',...
                  'Invalid parameter name "%s" found in analyzer.P.param at index %d. Cannot create valid struct field.', paramName, k);
        end
    else
        error('extractStimulusParameters:invalidPCell', ...
              'Invalid format for cell element at index %d in analyzer.P.param. Expected at least 3 elements with a char name.', k);
    end
end
pFields = fieldnames(pParams);

% Iterate through each condition
for i = 1:numConditions
    currentParams = struct();
    condData = analyzer.loops.conds{i};

    % 1. Add parameters from analyzer.M
    for mIdx = 1:length(mFields)
        fieldName = mFields{mIdx};
        currentParams.(fieldName) = analyzer.M.(fieldName);
    end

    % 2. Add parameters from analyzer.P.param
     for pIdx = 1:length(pFields)
        fieldName = pFields{pIdx};
        currentParams.(fieldName) = pParams.(fieldName);
    end

    % 3. Add condition-specific parameters from analyzer.loops.conds{i}
    if isfield(condData, 'symbol') && isfield(condData, 'val') && ...
       iscell(condData.symbol) && iscell(condData.val) && ...
       length(condData.symbol) == length(condData.val)

        numLoopParams = length(condData.symbol);
        for lParamIdx = 1:numLoopParams
            paramName = condData.symbol{lParamIdx};
            if ~ischar(paramName) || ~isvarname(paramName)
                 error('extractStimulusParameters:invalidLoopName',...
                       'Invalid loop parameter name "%s" found in condition %d, index %d. Cannot create valid struct field.', paramName, i, lParamIdx);
            end
            paramValue = condData.val{lParamIdx}; % Assume direct value
            currentParams.(paramName) = paramValue;
        end
    else
         error('extractStimulusParameters:missingLoopFields', ...
               'Condition %d structure is incomplete. Expected ''symbol'' and ''val'' cell arrays of matching length.', i);
    end

    % Store the combined parameters
    parameters{i} = currentParams;

    % 4. Map trials for displayOrder
    % Only loop through repeats if displayOrder was initialized
    if ~isempty(displayOrder)
        % Validator ensures 'repeats' exists and is a cell here
        numRepeats = length(condData.repeats);
        for j = 1:numRepeats
            trialNum = readTrialNumber(condData.repeats{j}, i, j);
            if isempty(trialNum)
                % Never presented; it occupies no position in displayOrder.
                continue
            end
            if isnan(displayOrder(trialNum))
                displayOrder(trialNum) = i;
            else
                error('extractStimulusParameters:duplicateTrial', ...
                      'Trial number %d is assigned to multiple conditions (existing: %d, new: %d). Ambiguous display order.', ...
                      trialNum, displayOrder(trialNum), i);
            end
        end % end loop over repeats
    end % end check ~isempty(displayOrder)
end % end loop over conditions

% Positions with no recorded trial are left as NaN. This is expected for a
% run that was aborted before every planned trial was presented, so it is
% reported rather than treated as an error; callers that need to pair trials
% with recorded stimulus times must decide how to handle the gaps.
if ~isempty(displayOrder) && any(isnan(displayOrder))
    unassignedIndices = find(isnan(displayOrder));
    warning('extractStimulusParameters:unassignedTrials', ...
            'No condition is recorded for %d of %d positions in the stimulus sequence (first: %d). These entries of displayOrder are NaN.', ...
            numel(unassignedIndices), numel(displayOrder), unassignedIndices(1));
end

end % end function


% --- Local Helper Function for Reading a Repeat's Trial Number ---
function trialNum = readTrialNumber(repeatData, conditionIndex, repeatIndex)
    % Validates one element of a condition's 'repeats' cell array and
    % returns its 'trialno', the position of that trial in the stimulus
    % presentation sequence.

    if ~isstruct(repeatData) || ~isscalar(repeatData) || ~isfield(repeatData, 'trialno')
        error('extractStimulusParameters:invalidRepeatStruct', ...
              'Invalid repeat structure or missing ''trialno'' field for condition %d, repeat %d.', ...
              conditionIndex, repeatIndex);
    end

    trialNum = repeatData.trialno;

    % An empty 'trialno' records no position in the sequence: the trial this
    % repeat stands for was never presented. That is expected of a run that
    % was aborted before its planned trials were exhausted, so it is returned
    % as empty and skipped by the caller rather than treated as an error.
    if isnumeric(trialNum) && isempty(trialNum)
        trialNum = [];
        return
    end

    if ~isnumeric(trialNum) || ~isscalar(trialNum) || ~isfinite(trialNum) || ...
       trialNum < 1 || floor(trialNum) ~= trialNum
        error('extractStimulusParameters:invalidTrialNum', ...
              'Invalid trial number (%s) found for condition %d, repeat %d. Expected a positive integer or an empty value.', ...
              describeValue(trialNum), conditionIndex, repeatIndex);
    end

    trialNum = double(trialNum);
end


% --- Local Helper Function for Describing an Unusable Value ---
function description = describeValue(value)
    % Renders VALUE for an error message. Reports its size and class as well
    % as its contents, because the size is often the thing that is wrong and
    % the class alone does not reveal it.

    maxValuesShown = 10;

    dims = size(value);
    sizeText = sprintf('%d', dims(1));
    for k = 2:numel(dims)
        sizeText = sprintf('%sx%d', sizeText, dims(k));
    end

    if isnumeric(value) && isscalar(value)
        description = sprintf('%g', value);
    elseif isnumeric(value)
        values = value(:).';
        if numel(values) > maxValuesShown
            description = sprintf('%s %s, values %s ...', sizeText, class(value), ...
                                  mat2str(values(1:maxValuesShown)));
        else
            description = sprintf('%s %s, values %s', sizeText, class(value), ...
                                  mat2str(values));
        end
    else
        description = sprintf('%s %s', sizeText, class(value));
    end
end


% --- Local Helper Function for Input Structure Validation ---
function validateAnalyzerStructure(analyzer)
    % Checks the internal structure of the analyzer input struct.
    % Throws an error if required fields or types are missing.

    requiredTopFields = ["M", "P", "loops"];
    missingTopFields = setdiff(requiredTopFields, fieldnames(analyzer));
    if ~isempty(missingTopFields)
        eid = 'validateAnalyzerStructure:missingTopFields';
        msg = sprintf('Input ''analyzer'' structure is missing required field(s): %s', strjoin(missingTopFields, ', '));
        throwAsCaller(MException(eid, msg));
    end

    if ~isstruct(analyzer.M) || ~isscalar(analyzer.M)
         eid = 'validateAnalyzerStructure:invalidM';
         msg = 'Field ''analyzer.M'' must be a scalar structure.';
         throwAsCaller(MException(eid, msg));
    end

    if ~isstruct(analyzer.P) || ~isscalar(analyzer.P)
         eid = 'validateAnalyzerStructure:invalidP';
         msg = 'Field ''analyzer.P'' must be a scalar structure.';
         throwAsCaller(MException(eid, msg));
    end
    if ~isfield(analyzer.P, 'param')
         eid = 'validateAnalyzerStructure:missingPParam';
         msg = 'Field ''analyzer.P'' is missing the required field ''param''.';
         throwAsCaller(MException(eid, msg));
    end
     if ~iscell(analyzer.P.param)
         eid = 'validateAnalyzerStructure:invalidPParamType';
         msg = 'Field ''analyzer.P.param'' must be a cell array.';
         throwAsCaller(MException(eid, msg));
    end

    if ~isstruct(analyzer.loops) || ~isscalar(analyzer.loops)
         eid = 'validateAnalyzerStructure:invalidLoops';
         msg = 'Field ''analyzer.loops'' must be a scalar structure.';
         throwAsCaller(MException(eid, msg));
    end
     if ~isfield(analyzer.loops, 'conds')
         eid = 'validateAnalyzerStructure:missingLoopsConds';
         msg = 'Field ''analyzer.loops'' is missing the required field ''conds''.';
         throwAsCaller(MException(eid, msg));
    end
    if ~iscell(analyzer.loops.conds)
         eid = 'validateAnalyzerStructure:invalidLoopsCondsType';
         msg = 'Field ''analyzer.loops.conds'' must be a cell array.';
         throwAsCaller(MException(eid, msg));
    end

    numConditions = length(analyzer.loops.conds);
    if numConditions == 0
        % It's okay for conds to be empty, resulting in 0 totalTrials.
        % No warning or error needed here specifically for emptiness.
    end
    requiredCondFields = ["symbol", "val", "repeats"];
    for i = 1:numConditions % Loop only if numConditions > 0
        if ~isstruct(analyzer.loops.conds{i}) || ~isscalar(analyzer.loops.conds{i})
             eid = 'validateAnalyzerStructure:invalidCondsElement';
             msg = sprintf('Element %d of ''analyzer.loops.conds'' must be a scalar structure.', i);
             throwAsCaller(MException(eid, msg));
        end
        condFields = fieldnames(analyzer.loops.conds{i});
        missingCondFields = setdiff(requiredCondFields, condFields);
         if ~isempty(missingCondFields)
            eid = 'validateAnalyzerStructure:missingCondFields';
            msg = sprintf('Structure in ''analyzer.loops.conds{%d}'' is missing required field(s): %s', i, strjoin(missingCondFields, ', '));
            throwAsCaller(MException(eid, msg));
        end
        if ~iscell(analyzer.loops.conds{i}.symbol) || ~iscell(analyzer.loops.conds{i}.val) || ~iscell(analyzer.loops.conds{i}.repeats)
             eid = 'validateAnalyzerStructure:invalidCondFieldTypes';
             msg = sprintf('Fields ''symbol'', ''val'', and ''repeats'' in ''analyzer.loops.conds{%d}'' must all be cell arrays.', i);
             throwAsCaller(MException(eid, msg));
        end
    end
end