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
ndi.path.documentschemapath = [ndi.path.commonpath filesep 'schema_documents'];
ndi.path.exampleexperpath = [ndi.path.commonpath filesep 'example_sessions'];
ndi.path.temppath = [tempdir filesep 'nditemp'];
ndi.path.testpath = [tempdir filesep 'nditestcode'];
ndi.path.filecachepath = [userpath filesep 'Documents' filesep 'NDI' filesep 'NDI-filecache'];
ndi.path.preferences = [userpath filesep 'Preferences' filesep' 'NDI'];

if ~exist(ndi.path.temppath,'dir'),
	mkdir(ndi.path.temppath);
end;

if ~exist(ndi.path.testpath,'dir'),
	mkdir(ndi.path.testpath);
end;

if ~exist(ndi.path.filecachepath,'dir'),
	mkdir(ndi.path.filecachepath);
end;

if ~exist(ndi.path.preferences,'dir'),
	mkdir(ndi.path.preferences);
end;

 % initialization

ndi_probetype2objectinit;
ndi_databasehierarchyinit;

ndi.debug.veryverbose = 1;

 % test write access to preferences, testpath, filecache, temppath
paths = {ndi.path.testpath, ndi.path.temppath, ndi.path.filecachepath, ndi.path.preferences};
pathnames = {'NDI test path', 'NDI temporary path', 'NDI filecache path', 'NDI preferences path'};

for i=1:numel(paths),
	fname = [paths{i} filesep 'testfile_' ndi_id.ndi_unique_id() '.txt'];
	fid = fopen(fname,'wt');
	if fid<0,
		error(['We do not have write access to the ' pathnames{i} ' at '  paths{i} '.']);
	end;
	fclose(fid);
	delete(fname);
end;

% initialize ndi_validate
ndi_validate.add_java_path();
try
    ndi.validators.format_validators = ndi_validate.load_format_validator();
catch e
    warning("Format validators aren't initialized properly: Here are the error messages" + newline + e.message);
    ndi.validators.format_validators = -1;
end


