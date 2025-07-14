function check_Matlab_toolboxes

    V = ver;

    filename = fullfile(ndi.common.PathConstants.CommonFolder, ...
        'requirements', 'ndi-matlab-toolboxes.json');

    t = fileread(filename);

    r = jsondecode(t);

    for j=1:numel(r.toolboxes.required)
        index = find(strcmp(r.toolboxes.required(j),{V.Name}));
        if isempty(index)
            warning(['Required toolbox "' char(r.toolboxes.required(j)) '" is not found in your Matlab installation. Key components of NDI-matlab will likely not work.']);
        end
    end
