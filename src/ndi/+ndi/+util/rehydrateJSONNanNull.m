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
%     - '"__NDI__NaN__"'  ->  NaN
%     - '"__NDI__Infinity__"'  ->  Infinity
%     - '"__NDI__-Infinity__"' -> -Infinity
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
%                      |   (Default: '"__NDI__NaN__"')
%   'inf_string'       | The string to be replaced with Infinity.
%                      |   (Default: '"__NDI__Infinity__"')
%   'ninf_string'      | The string to be replaced with -Infinity.
%                      |   (Default: '"__NDI__-Infinity__"')
%
%   Example:
%     json_in = '{"value1":""__NDI__NaN__"","value2":"__NDI__Infinity__","value3":"__NDI__-Infinity__"}';
%     json_out = ndi.util.rehydrateJSONNanNull(json_in);
%     % json_out will be '{"value1":NaN,"value2":Infinity,"value3":-Infinity}'
%     % now, jsondecode can properly interpret these values
%     matlab_struct = jsondecode(json_out);
%
%   Example with custom search string:
%     json_in = '{"val":"MY_CUSTOM_NAN", "val2": "__NDI__Infinity__"}';
%     json_out = ndi.util.rehydrateJSONNanNull(json_in, nan_string='"MY_CUSTOM_NAN"');
%     % json_out will be '{"val":NaN, "val2":Infinity}'
%
%   See also: jsondecode, jsonencode

    arguments
        jsonText (1,:) char
        options.nan_string (1,:) char = '"__NDI__NaN__"'
        options.inf_string (1,:) char = '"__NDI__Infinity__"'
        options.ninf_string (1,:) char = '"__NDI__-Infinity__"'
    end

    % Perform all replacements in a single pass for efficiency, which is
    % critical for potentially huge JSON strings.
    old_strings = {options.nan_string, options.inf_string, options.ninf_string};
    new_strings = {'NaN', 'Infinity', '-Infinity'};
    
    rehydratedJsonText = replace(jsonText, old_strings, new_strings);

end
