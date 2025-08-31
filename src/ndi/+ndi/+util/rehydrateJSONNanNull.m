function rehydratedJsonText = rehydrateJSONNanNull(jsonText, options)
% REHYDRATEJSONNANNULL - Replace string representations of NaN, Inf, and -Inf in JSON text.
%
%   rehydratedJsonText = ndi.util.rehydrateJSONNanNull(jsonText)
%
%   Replaces special string values within a JSON character vector (jsonText)
%   with their numerical equivalents that can be parsed by JSON decoders
%   that support NaN, Infinity, and -Infinity (like MATLAB's jsondecode).
%
%   By default, it performs the following replacements:
%     - '"S_NAN"'  ->  NaN
%     - '"S_INF"'  ->  Infinity
%     - '"S_NINF"' -> -Infinity
%
%   This function is designed to find all instances of these strings,
%   regardless of whether they are followed by a comma, newline, or other
%   character. For performance on large character strings, all replacements
%   are done in a single pass.
%
%   This function also accepts name/value pairs to override the default
%   search strings:
%
%   Name (string)      | Description
%   -----------------------------------------------------------------------
%   'nan_string'       | The string to be replaced with NaN.
%                      |   (Default: '"S_NAN"')
%   'inf_string'       | The string to be replaced with Infinity.
%                      |   (Default: '"S_INF"')
%   'ninf_string'      | The string to be replaced with -Infinity.
%                      |   (Default: '"S_NINF"')
%
%   Example:
%     json_in = '{"value1":"S_NAN","value2":"S_INF","value3":"S_NINF"}';
%     json_out = ndi.util.rehydrateJSONNanNull(json_in);
%     % json_out will be '{"value1":NaN,"value2":Infinity,"value3":-Infinity}'
%     % now, jsondecode can properly interpret these values
%     matlab_struct = jsondecode(json_out);
%
%   Example with custom search string:
%     json_in = '{"val":"MY_CUSTOM_NAN", "val2": "S_INF"}';
%     json_out = ndi.util.rehydrateJSONNanNull(json_in, nan_string='"MY_CUSTOM_NAN"');
%     % json_out will be '{"val":NaN, "val2":Infinity}'
%
%   See also: jsondecode, jsonencode

    arguments
        jsonText (1,:) char
        options.nan_string (1,:) char = '"S_NAN"'
        options.inf_string (1,:) char = '"S_INF"'
        options.ninf_string (1,:) char = '"S_NINF"'
    end

    % Perform all replacements in a single pass for efficiency, which is
    % critical for potentially huge JSON strings.
    old_strings = {options.nan_string, options.inf_string, options.ninf_string};
    new_strings = {'NaN', 'Infinity', '-Infinity'};
    
    rehydratedJsonText = replace(jsonText, old_strings, new_strings);

end
