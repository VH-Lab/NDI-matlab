function ndi_Init % NDI_INIT - Add paths and initialize variables for NS2
    % NDI_INIT
    %
    % Initializes the file path and global variables for class NDI
    %

    myndipath = fileparts(which('ndi_Init'));

    % remove any paths that have the string 'NDI-matlab' so we don't have stale paths confusing anyone

    pathsnow = path;
    pathsnow_cell = split(pathsnow,pathsep);
    matches = contains(pathsnow_cell, 'NDI-matlab');
    pathstoremove = char(strjoin(pathsnow_cell(matches),pathsep));
    rmpath(pathstoremove);

    % add everyelement except '.git' directories
    pathstoadd = genpath(myndipath);
    pathstoadd_cell = split(pathstoadd,pathsep);
    matches=(~contains(pathstoadd_cell,'.git'))&(~contains(pathstoadd_cell,'.ndi'));
    pathstoadd = char(strjoin(pathstoadd_cell(matches),pathsep));
    addpath(pathstoadd);

    % see if the user has all the needed toolboxes, and warn them if they do not
    ndi.fun.check_Matlab_toolboxes

    % run any warnings on various architectures
    ndi.fun.run_Linux_checks
