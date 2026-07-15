function [geom, filepath] = readLibrary(name)
% NDI.FUN.PROBE.GEOMETRY.READLIBRARY - read an electrode layout from the NDI library
%
% [GEOM, FILEPATH] = NDI.FUN.PROBE.GEOMETRY.READLIBRARY(NAME)
%
% Reads a named electrode layout from the NDI library at [ndi_common]/probe/geometry/
% and returns it as a struct GEOM whose fields are probe_geometry fields
% (site_locations_leftright, site_locations_depth, shank_id, probe_model, unit, ...).
% GEOM can be passed straight to NDI.FUN.PROBE.GEOMETRY.FROMSTRUCT to create the
% documents (NDI.FUN.PROBE.GEOMETRY.FROMLIBRARY does exactly that).
%
% NAME may be:
%   'group/model' - an exact layout (e.g. 'neuropixels/NP2_1shank'), or
%   'model'       - a model name searched across all groups (errors if ambiguous).
%
% FILEPATH is the .json file that was read.
%
% See also: NDI.FUN.PROBE.GEOMETRY.LISTLIBRARY, NDI.FUN.PROBE.GEOMETRY.FROMLIBRARY,
%   NDI.FUN.PROBE.GEOMETRY.FROMSTRUCT

    arguments
        name (1,:) char
    end

    root = fullfile(ndi.common.PathConstants.CommonFolder, 'probe', 'geometry');

    if contains(name,'/') || contains(name, filesep),
        name = strrep(name, '/', filesep);
        filepath = fullfile(root, [name '.json']);
        if ~isfile(filepath),
            error('Electrode layout ''%s'' not found (looked for %s).', name, filepath);
        end;
    else,
        % search every group for <name>.json
        matches = {};
        groups = dir(root);
        for i=1:numel(groups),
            if ~groups(i).isdir || startsWith(groups(i).name,'.'), continue; end;
            candidate = fullfile(root, groups(i).name, [name '.json']);
            if isfile(candidate),
                matches{end+1} = candidate; %#ok<AGROW>
            end;
        end;
        if isempty(matches),
            error('Electrode layout ''%s'' not found in any group under %s.', name, root);
        end;
        if numel(matches)>1,
            error('Electrode layout ''%s'' is ambiguous (found in %d groups). Use ''group/%s''.', ...
                name, numel(matches), name);
        end;
        filepath = matches{1};
    end;

    geom = jsondecode(fileread(filepath));

end
