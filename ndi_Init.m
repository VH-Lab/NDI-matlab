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

ndi.globals;

 % paths

ndi_globals.path = [];

ndi_globals.path.path = myndipath;
ndi_globals.path.commonpath = [ndi_globals.path.path filesep 'ndi_common'];
ndi_globals.path.documentpath = [ndi_globals.path.commonpath filesep 'database_documents'];
ndi_globals.path.documentschemapath = [ndi_globals.path.commonpath filesep 'schema_documents'];
ndi_globals.path.exampleexperpath = [ndi_globals.path.commonpath filesep 'example_sessions'];
ndi_globals.path.temppath = [tempdir filesep 'nditemp'];
ndi_globals.path.testpath = [tempdir filesep 'nditestcode'];
ndi_globals.path.filecachepath = [userpath filesep 'Documents' filesep 'NDI' filesep 'NDI-filecache'];
ndi_globals.path.logpath = [userpath filesep 'Documents' filesep 'NDI' filesep 'Logs'];
ndi_globals.path.preferences = [userpath filesep 'Preferences' filesep' 'NDI'];

if ~exist(ndi_globals.path.temppath,'dir'),
	mkdir(ndi_globals.path.temppath);
end;

if ~exist(ndi_globals.path.testpath,'dir'),
	mkdir(ndi_globals.path.testpath);
end;

if ~exist(ndi_globals.path.filecachepath,'dir'),
	mkdir(ndi_globals.path.filecachepath);
end;

if ~exist(ndi_globals.path.preferences,'dir'),
	mkdir(ndi_globals.path.preferences);
end;

 % initialization

ndi.probe.fun.probetype2objectinit;
ndi.database.fun.databasehierarchyinit;

ndi_globals.debug.veryverbose = 1;

 % test write access to preferences, testpath, filecache, temppath
paths = {ndi_globals.path.testpath, ndi_globals.path.temppath, ndi_globals.path.filecachepath, ndi_globals.path.preferences};
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

ndi_globals.log = vlt.app.log(...
	'system_logfile',[ndi_globals.path.logpath filesep 'system.log'],...
	'error_logfile', [ndi_globals.path.logpath filesep 'error.log'],...
	'debug_logfile', [ndi_globals.path.logpath filesep 'debug.log'],...
	'system_verbosity',5,...
	'error_verbosity',5, ...
	'debug_verbosity', 5, ...
	'log_name', 'ndi',...
	'log_error_behavior','warning');


