function d = find_calc_directories()
    % ndi.fun.find_calc_directories - find all NDIcalc-X-matlab directories
    %
    % D = ndi.fun.find_calc_directories()
    %
    % Scan the installed packages for NDIcalc-X-matlab packages.
    %
    % D is a cell array of full path directories.
    %
    %

    tool_path = fileparts(ndi.toolboxdir);

    d = dir([tool_path filesep 'NDIcalc*-matlab']);

    dirindexes = find([d.isdir]==1);

    d = d(dirindexes);

    d = {d.name};

    for i=1:numel(d),
        d{i} = [tool_path filesep d{i}];
    end;


