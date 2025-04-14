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
%   displayOrder (numeric vector): 1xT vector (T=trials). displayOrder(k)=i
%                                  means trial k used condition i. Empty ([])
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

% Determine total number of trials
totalTrials = 0;
for i = 1:numConditions
    if isfield(analyzer.loops.conds{i}, 'repeats') && iscell(analyzer.loops.conds{i}.repeats)
        totalTrials = totalTrials + length(analyzer.loops.conds{i}.repeats);
    else
        error('extractStimulusParameters:missingRepeats', ...
              'Condition %d is missing or has invalid ''repeats'' field required for trial counting.', i);
    end
end

% --- MODIFIED HERE: Removed warning for zero trials ---
if totalTrials == 0
    % No warning needed, just set displayOrder to empty for valid zero-trial case
    displayOrder = [];
else
    displayOrder = nan(1, totalTrials);
end
% --- END MODIFICATION ---

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
    % Only loop through repeats if displayOrder was initialized (i.e., totalTrials > 0)
    if ~isempty(displayOrder)
        % Validator ensures 'repeats' exists and is a cell here
        numRepeats = length(condData.repeats);
        for j = 1:numRepeats
            repeatData = condData.repeats{j};
            if isstruct(repeatData) && isscalar(repeatData) && isfield(repeatData, 'trialno')
                trialNum = repeatData.trialno;
                if isnumeric(trialNum) && isscalar(trialNum) && trialNum > 0 && trialNum <= totalTrials && floor(trialNum) == trialNum
                    if isnan(displayOrder(trialNum))
                         displayOrder(trialNum) = i;
                    else
                        error('extractStimulusParameters:duplicateTrial', ...
                              'Trial number %d is assigned to multiple conditions (existing: %d, new: %d). Ambiguous display order.', ...
                              trialNum, displayOrder(trialNum), i);
                    end
                else
                    error('extractStimulusParameters:invalidTrialNum', ...
                          'Invalid or out-of-range trial number (%g) found for condition %d, repeat %d. Expected integer between 1 and %d.', ...
                          trialNum, i, j, totalTrials);
                end
            else
                 error('extractStimulusParameters:invalidRepeatStruct', ...
                       'Invalid repeat structure or missing ''trialno'' field for condition %d, repeat %d.', i, j);
            end
        end % end loop over repeats
    end % end check ~isempty(displayOrder)
end % end loop over conditions

% Final check for unassigned trials (only if trials were expected)
if ~isempty(displayOrder) && any(isnan(displayOrder))
    unassigned_indices = find(isnan(displayOrder));
    error('extractStimulusParameters:unassignedTrials', ...
          'Display order calculation incomplete. Some trials were not assigned a condition index (e.g., trial %d of %d). Check ''trialno'' fields in all conditions.', ...
          unassigned_indices(1), totalTrials);
end

end % end function


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