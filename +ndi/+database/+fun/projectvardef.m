function pvd = ndi_projectvardef(name, type, description, data)
% NDI_PROJECTVARDEF - shorthand function for building an 'projectvar' document
%
% PVD = ndi.database.fun.projectvardef(NAME, TYPE, DESCRIPTION, DATA)
%
% Makes a cell array definition of the fields for an 'projectvar' document.
%
% Creates a set of name/value pairs in a 1x4 cell list:
% Name:                   | Value
% ------------------------------------------------------
% 'ndi_document.name'     | NAME
% 'ndi_document.type'     | TYPE
% 'projectvar.description'| DESCRIPTION
% 'projectvar.data'       | DATA 
%

pvd = { ...
	'ndi_document.name', name, ...
	'ndi_document.type', type, ...
	'projectvar.description', description, ...
	'projectvar.data', data ...
	};

