function filepath = writeLibrary(name, geom, options)
% NDI.FUN.PROBE.GEOMETRY.WRITELIBRARY - save an electrode layout into the NDI library
%
% FILEPATH = NDI.FUN.PROBE.GEOMETRY.WRITELIBRARY(NAME, GEOM, ...)
%
% Writes the electrode-layout struct GEOM (probe_geometry fields, e.g. from
% NDI.FUN.PROBE.GEOMETRY.FROMPROBEINTERFACE) as a .json file into the NDI library at
% [ndi_common]/probe/geometry/NAME.json, creating the group subfolder if needed.
%
% NAME is 'group/model' (e.g. 'neuropixels/NP2_1shank'). This is a maintainer
% operation: it writes into the installed ndi_common tree so the layout ships with
% NDI and is discoverable via NDI.FUN.PROBE.GEOMETRY.LISTLIBRARY.
%
% Name/value pairs:
%   overwrite (false) - overwrite an existing layout file of the same name.
%   verbose (1)       - 0/1 report the written path.
%
% See also: NDI.FUN.PROBE.GEOMETRY.FROMPROBEINTERFACE, NDI.FUN.PROBE.GEOMETRY.READLIBRARY,
%   NDI.FUN.PROBE.GEOMETRY.LISTLIBRARY

    arguments
        name (1,:) char
        geom (1,1) struct
        options.overwrite (1,1) logical = false
        options.verbose (1,1) double = 1
    end

    if ~contains(name,'/') && ~contains(name, filesep),
        error('NAME must be ''group/model'' (e.g. ''neuropixels/NP2_1shank'').');
    end;

    root = fullfile(ndi.common.PathConstants.CommonFolder, 'probe', 'geometry');
    rel = strrep(name, '/', filesep);
    filepath = fullfile(root, [rel '.json']);

    if isfile(filepath) && ~options.overwrite,
        error('Electrode layout ''%s'' already exists (%s). Pass ''overwrite'',true to replace it.', name, filepath);
    end;

    d = fileparts(filepath);
    if ~isfolder(d), mkdir(d); end;

    try
        txt = jsonencode(geom, 'PrettyPrint', true);
    catch
        txt = jsonencode(geom); % older MATLAB without PrettyPrint
    end;
    fid = fopen(filepath,'w');
    if fid<0, error('Could not open %s for writing.', filepath); end;
    fwrite(fid, txt, 'char');
    fclose(fid);

    if options.verbose,
        disp(['Wrote electrode layout ''' name ''' to ' filepath '.']);
    end;

end
