function nsd_Init % NSD_INIT - Add paths and initialize variables for NSD
% NSD_INIT 
% 
% Initializes the file path and global variables for class NSD
%

mynsdpath = fileparts(which('nsd_Init'));

  % add everything except '.git' directories
pathstoadd = genpath(mynsdpath);
pathstoadd_cell = split(pathstoadd,pathsep);
matches=~contains(pathstoadd_cell,'.git');
pathstoadd = char(strjoin(pathstoadd_cell(matches),pathsep));
addpath(pathstoadd);

nsd_globals;

 % paths

nsdpath = mynsdpath;
nsdcommonpath = [nsdpath filesep 'nsd_common'];
nsddocumentpath = [nsdcommonpath filesep 'database_documents'];
nsddocumentschemapath = [nsdcommonpath filesep 'database_documents'];
nsdexampleexperpath = [nsdcommonpath filesep 'example_experiments'];
nsdtestpath = [tempdir filesep 'nsdtestcode'];

 % initialization

nsd_probetype2objectinit;
nsd_databasehierarchyinit;

