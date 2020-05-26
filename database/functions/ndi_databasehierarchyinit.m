function ndi_databasehierarchyinit
% NDI_DATABASEHIERARCHYINIT - Initializes the list of databases to try
%
% NDI_DATABASEHIERARCHYINIT
%
% Initializes the ndi_databasehierarchy global variable.  
% 
% Use TYPE NDI_PROBETYPE2OBJECTINIT to see the structure

ndi_globals

ndi.databasehierarchy = struct( ...
	'extension',	'ndi.dumbjsondb.json', ...
	'code',         'db=ndi_matlabdumbjsondb(''FILEPATH'', ''SESSION_REFERENCE'', ''load'',''FILENAME'');',  ...
	'newcode',      'db=ndi_matlabdumbjsondb(''FILEPATH'', ''SESSION_REFERENCE'', ''new'',''FILEPATHndi.dumbjsondb.json'');' ...
);

