function [tf_value, tf_name] = stimulustemporalfrequency(stimulus_parameters)
%NDI.FUN.STIMULUSTEMPORALFREQUENCY Extract temporal frequency from stimulus parameters using predefined rules.
%
%   [TF_VALUE, TF_NAME] = NDI.FUN.STIMULUSTEMPORALFREQUENCY(STIMULUS_PARAMETERS)
%
%   Determines the temporal frequency (TF) of a stimulus based on its
%   parameters provided in the STIMULUS_PARAMETERS structure.
%
%   The function checks the field names of the input STIMULUS_PARAMETERS structure
%   against a predefined list of known temporal frequency parameter names. This
%   list and the rules for calculating TF are loaded from a configuration file:
%   [ndi.common.PathConstants.CommonFolder]/stimulus/ndi_stimulusparameters2temporalfrequency.json
%
%   The JSON configuration allows for various ways TF might be encoded:
%   - Direct value: A parameter directly represents TF in Hz.
%   - Scaled/Offset value: A parameter value needs multiplication and/or addition.
%   - Period value: A parameter represents the temporal period (e.g., in seconds),
%     requiring inversion (1/value) to get frequency.
%   - Multi-parameter dependency: The calculation might involve multiplying by
%     the value of another parameter within STIMULUS_PARAMETERS.
%
%   If a matching parameter name is found in STIMULUS_PARAMETERS, the function
%   calculates the TF according to the rules defined in the JSON file for that
%   parameter. It returns the calculated TF in TF_VALUE (typically in Hz) and
%   the name of the parameter used for the calculation in TF_NAME.
%
%   If multiple known TF parameters exist in STIMULUS_PARAMETERS, the function
%   uses the *first* one it finds based on the order in the JSON file and
%   returns immediately after successful calculation.
%
%   If no known temporal frequency parameter field name is found within
%   STIMULUS_PARAMETERS after checking all rules, TF_VALUE is returned as empty
%   (`[]`) and TF_NAME is returned as an empty char array (`''`).
%
%   **Error Handling:**
%   This function will throw an error and stop execution if:
%   - The JSON configuration file is not found or cannot be read/parsed.
%   - An entry in the JSON file is missing required fields.
%   - A matched parameter in `STIMULUS_PARAMETERS` has a non-numeric or non-scalar value.
%   - A calculation results in division by zero (e.g., zero period).
%   - A required secondary multiplier parameter is missing or has an invalid value.
%   - Any other calculation error occurs for a matched parameter rule.
%   Error identifiers start with 'NDI:STIMULUSTEMPORALFREQUENCY:'.
%
%   **JSON Configuration File Structure:**
%   The `ndi_stimulusparameters2temporalfrequency.json` file contains an array
%   of objects, where each object defines a rule for a potential TF parameter:
%   - `parameter_name` (string): The exact field name to look for in the
%       `STIMULUS_PARAMETERS` input structure (e.g., "tFrequency", "t_period").
%   - `temporalFrequencyMultiplier` (number): A value to multiply the parameter's
%       value by. Use 1 for no multiplication.
%   - `temporalFrequencyAdder` (number): A value to add to the parameter's value
%       *after* multiplication. Use 0 for no addition.
%       (Calculation: `NewValue = temporalFrequencyAdder + temporalFrequencyMultiplier * OriginalValue`)
%   - `isPeriod` (boolean): If `true`, the `NewValue` calculated above is treated
%       as a period, and the final TF is `1 / NewValue`. If `false`, `NewValue`
%       is treated as the frequency.
%   - `parameterMultiplier` (string): If not empty, this should be the name of
%       *another* field within the `STIMULUS_PARAMETERS` structure. The TF value
%       (calculated using the steps above) will be multiplied by the value of
%       this additional parameter. If empty (`""`), no secondary multiplication occurs.
%
%   Inputs:
%     STIMULUS_PARAMETERS (1,1) struct: A scalar structure where each field
%         represents a parameter of the stimulus. Field names are strings,
%         and values are the corresponding parameter values (typically numeric).
%         Example: struct('tFreq', 10, 'contrast', 0.5)
%
%   Outputs:
%     TF_VALUE (numeric or []): The calculated temporal frequency, typically in Hz.
%         Returns empty `[]` only if no matching TF parameter rule is found in the
%         JSON for any field present in STIMULUS_PARAMETERS.
%     TF_NAME (char row vector or ''): The field name in STIMULUS_PARAMETERS
%         from which TF_VALUE was derived. Returns empty `''` only if no match found.
%
%   Requires:
%     - NDI (Neuroscience Data Interface) toolbox, including `ndi.common.PathConstants`.
%     - MATLAB R2016b or newer (for `jsondecode`). R2019a or newer recommended for `fileread`.
%     - The JSON configuration file `ndi_stimulusparameters2temporalfrequency.json`
%       must exist in the expected location and be correctly formatted.
%
%   Examples:
%       % Assume ndi_stimulusparameters2temporalfrequency.json maps 'tFreq' directly:
%       % { "parameter_name": "tFreq", "temporalFrequencyMultiplier": 1, ...
%       %   "temporalFrequencyAdder": 0, "isPeriod": false, "parameterMultiplier": "" }
%       params1 = struct('tFreq', 8, 'spatialFreq', 0.1);
%       [tf1, name1] = ndi.fun.stimulustemporalfrequency(params1);
%       % Expected: tf1 = 8, name1 = 'tFreq'
%
%       % Assume JSON maps 'temporal_period_property' with "isPeriod": true:
%       % { "parameter_name": "temporal_period_property", "isPeriod": true, ... }
%       params2 = struct('contrast', 1, 'temporal_period_property', 0.125);
%       [tf2, name2] = ndi.fun.stimulustemporalfrequency(params2);
%       % Expected: tf2 = 1 / 0.125 = 8, name2 = 'temporal_period_property'
%
%       % Assume JSON maps 't_period' with "isPeriod": true and
%       % "parameterMultiplier": "refreshRate":
%       % { "parameter_name": "t_period", "isPeriod": true, ...
%       %   "parameterMultiplier": "refreshRate", ...}
%       params3 = struct('t_period', 15, 'refreshRate', 60); % t_period in frames
%       [tf3, name3] = ndi.fun.stimulustemporalfrequency(params3);
%       % Expected: tf3 = (1 / 15) * 60 = 4 Hz, name3 = 't_period'
%
%       % Case where no known TF parameter is present
%       params4 = struct('orientation', 90, 'diameter', 5);
%       [tf4, name4] = ndi.fun.stimulustemporalfrequency(params4);
%       % Expected: tf4 = [], name4 = ''
%
%       % Example that would now cause an error (previously warning):
%       % params5 = struct('tFreq', [1 2]); % Non-scalar value
%       % try
%       %    ndi.fun.stimulustemporalfrequency(params5);
%       % catch ME
%       %    disp(ME.message); % Will display error about non-scalar value
%       % end
%
%   See also: NDI.SETUP.STIMULUSPARAMETERMAPS, FILEREAD, JSONDECODE, ERROR

    % Argument validation block
    arguments
        stimulus_parameters (1,1) struct % Input must be a scalar structure
    end

    % --- Start of the main function code ---
    tf_value = [];
    tf_name = '';

    % Construct file path safely
    jsonFilePath = fullfile(ndi.common.PathConstants.CommonFolder, 'stimulus', 'ndi_stimulusparameters2temporalfrequency.json');

    % Check if JSON file exists before trying to read
    if ~exist(jsonFilePath, 'file')
        error('NDI:STIMULUSTEMPORALFREQUENCY:JSONNotFound', ...
              'JSON configuration file not found at: %s', jsonFilePath);
        % No return needed after error
    end

    try
        % Use MATLAB's built-in fileread function
        j = fileread(jsonFilePath);
        ndi_stimTFinfo = jsondecode(j);
    catch ME
        error('NDI:STIMULUSTEMPORALFREQUENCY:JSONError', ...
              'Error reading or decoding JSON file: %s\n%s', jsonFilePath, ME.message);
        % No return needed after error
    end


    for i=1:numel(ndi_stimTFinfo)
        % Check if the current rule object has the necessary fields
        requiredFields = {'parameter_name', 'temporalFrequencyMultiplier', 'temporalFrequencyAdder', 'isPeriod', 'parameterMultiplier'};
        if ~all(isfield(ndi_stimTFinfo(i), requiredFields))
             error('NDI:STIMULUSTEMPORALFREQUENCY:JSONFormatError', ...
                   'JSON entry %d is missing required fields.', i);
             % No continue needed after error
        end

        current_param_name = ndi_stimTFinfo(i).parameter_name;

        % Check if the parameter exists in the input structure
        if isfield(stimulus_parameters, current_param_name)
            % Process the match
            try % Catch calculation errors for this specific rule
                original_value = stimulus_parameters.(current_param_name);

                % Ensure value is numeric before calculations
                if ~isnumeric(original_value) || ~isscalar(original_value)
                   error('NDI:STIMULUSTEMPORALFREQUENCY:NonNumericValue', ...
                         'Parameter "%s" must have a numeric scalar value.', current_param_name);
                   % No continue needed after error
                end

                tf_value = ndi_stimTFinfo(i).temporalFrequencyAdder + ndi_stimTFinfo(i).temporalFrequencyMultiplier * original_value;

                if ndi_stimTFinfo(i).isPeriod
                    % Add check for zero to avoid division by zero error
                    if tf_value == 0
                        error('NDI:STIMULUSTEMPORALFREQUENCY:ZeroPeriod',...
                              'Temporal period value for parameter "%s" results in zero after transformation; cannot divide by zero.', current_param_name);
                        % No return/reset needed after error
                    end
                    tf_value = 1/tf_value;
                end

                if ~isempty(ndi_stimTFinfo(i).parameterMultiplier)
                    multiplier_param_name = ndi_stimTFinfo(i).parameterMultiplier;
                    % Check if the multiplier parameter exists
                    if isfield(stimulus_parameters, multiplier_param_name)
                        tf_mult_parm_value = stimulus_parameters.(multiplier_param_name);

                        % Ensure multiplier value is numeric and scalar
                        if ~isnumeric(tf_mult_parm_value) || ~isscalar(tf_mult_parm_value)
                             error('NDI:STIMULUSTEMPORALFREQUENCY:NonNumericMultiplier',...
                                   'Parameter multiplier "%s" must have a numeric scalar value.', multiplier_param_name);
                        else
                             tf_value = tf_value * tf_mult_parm_value;
                        end
                    else
                        error('NDI:STIMULUSTEMPORALFREQUENCY:MultiplierParamNotFound',...
                              'Required parameter multiplier field "%s" not found in stimulus_parameters.', multiplier_param_name);
                    end
                end

                tf_name = current_param_name;
                return; % Return as soon as the first match is successfully processed

            catch ME_Calc % Catch errors specific to calculations for THIS rule
                 % Throw a new error providing context about which rule failed
                 error('NDI:STIMULUSTEMPORALFREQUENCY:CalculationError',...
                       'Error during TF calculation for parameter rule "%s": %s', current_param_name, ME_Calc.message);
                 % This error will stop the function execution.
            end
        end % end isfield check
    end % end for loop over JSON entries
    % --- End of the main function code ---

    % If the loop completes without returning, no match was found.
    % Outputs tf_value=[] and tf_name='' (initialized values) implicitly.

end % function