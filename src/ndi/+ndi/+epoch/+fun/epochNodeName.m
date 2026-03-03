function names = epochNodeName(epochnodes, options)
% EPOCHNODENAME - returns the epochname for one or more epochnodes
%
% NAMES = ndi.epoch.fun.epochNodeName(EPOCHNODES, ...)
%
% Returns a cell array of character arrays of the epochname values for each epochnode
% structure array entry provided in the input.
%
% The epochname is [objectname '; ' epochStr]
% where epochStr depends on whether epoch_id has the form
% epoch_4126958b19a21a41_c0d5efe3d3fa43c5 where epoch_ is followed by 16 alphanumeric
% characters, an underscore, and 16 more alphanumeric characters. If it has this form,
% then epochStr is the last 4 digits. Otherwise, epochStr is epoch_id.
%
% If objectname begins with 'probe: ', it is shortened to 'p:'.
% If objectname begins with 'element: ', it is shortened to 'e:'.
%
% This function takes an optional name/value pair argument:
%   'singlularResponseIsNotCell' (default: false)
%   If true, and if the user provides a single epochnode input, then it returns a
%   character array instead of a cell array.
%

arguments
    epochnodes struct
    options.singlularResponseIsNotCell logical = false
end

if isempty(epochnodes)
    names = {};
    return;
end

names = cell(1, numel(epochnodes));

for i = 1:numel(epochnodes)
    node = epochnodes(i);

    epoch_id = node.epoch_id;

    if isfield(node, 'objectname')
        objectname = node.objectname;
    else
        objectname = 'unknown';
    end

    if startsWith(objectname, 'probe: ')
        objectname = ['p:' objectname(8:end)];
    elseif startsWith(objectname, 'element: ')
        objectname = ['e:' objectname(10:end)];
    end

    % Match epoch_id pattern: epoch_ followed by 16 alphanumeric, _, 16 alphanumeric
    match = regexp(epoch_id, '^epoch_[a-zA-Z0-9]{16}_[a-zA-Z0-9]{16}$', 'once');

    if ~isempty(match)
        epochStr = epoch_id(end-3:end);
    else
        epochStr = epoch_id;
    end

    names{i} = [objectname '; ' epochStr];
end

if options.singlularResponseIsNotCell && numel(epochnodes) == 1
    names = names{1};
end

end
