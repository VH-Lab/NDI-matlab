function databasehierarchyinit
% NDI_DATABASEHIERARCHYINIT - Initializes the list of databases to try
%
% ndi.database.fun.databasehierarchyinit
%
% Initializes the ndi_globals.databasehierarchy global variable.  
% 
% Use TYPE ndi.probe.fun.probetype2objectinit to see the structure

ndi.globals

ndi_globals.databasehierarchy = struct( ...
	'extension',	'ndi.dumbjsondb.json', ...
	'code',         'db=ndi.database.matlabdumbjsondb(''FILEPATH'', ''SESSION_REFERENCE'', ''load'',''FILENAME'');',  ...
	'newcode',      'db=ndi.database.matlabdumbjsondb(''FILEPATH'', ''SESSION_REFERENCE'', ''new'',''FILEPATHndi.dumbjsondb.json'');' ...
);

