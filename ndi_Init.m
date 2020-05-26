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

ndi_globals;

 % paths

ndi.path = [];

ndi.path.path = myndipath;
ndi.path.commonpath = [ndi.path.path filesep 'ndi_common'];
ndi.path.documentpath = [ndi.path.commonpath filesep 'database_documents'];
ndi.path.documentschemapath = [ndi.path.commonpath filesep 'database_documents'];
ndi.path.exampleexperpath = [ndi.path.commonpath filesep 'example_sessions'];
ndi.path.temppath = [tempdir filesep 'nditemp'];
ndi.path.testpath = [tempdir filesep 'nditestcode'];
ndi.path.filecachepath = [userpath filesep 'Documents' filesep 'NDI-filecache'];

if ~exist(ndi.path.temppath,'dir'),
	mkdir(ndi.path.temppath);
end;

if ~exist(ndi.path.testpath,'dir'),
	mkdir(ndi.path.nditestpath);
end;

if ~exist(ndi.path.filecachepath,'dir'),
	mkdir(ndi.path.filecachepath);
end;

 % initialization

ndi_probetype2objectinit;
ndi_databasehierarchyinit;

ndi.debug.veryverbose = 1;


