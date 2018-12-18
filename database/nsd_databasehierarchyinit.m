function nsd_databasehierarchyinit
% NSD_DATABASEHIERARCHYINIT - Initializes the list of databases to try
%
% NSD_DATABASEHIERARCHYINIT
%
% Initializes the nsd_databasehierarchy global variable.  
% 
% Use TYPE NSD_PROBETYPE2OBJECTINIT to see the structure

nsd_globals

nsd_databasehierarchy = struct( ...
	'extension',	'nsd.dumbjsondb.json', ...
	'code',         'db=dumbjsondb(''open'',FILENAME);',  ...
	'newcode',      'db=dumbjsondb(''new'',''FILEPATHnsd.dumbjsondb.json') ...
);

