function pvd = nsd_projectvardef(name, type, description, data)
% NSD_PROJECTVARDEF - shorthand function for building an 'nsd_document_projectvar' document
%
% PVD = NSD_PROJECTVARDEF(NAME, TYPE, DESCRIPTION, DATA)
%
% Makes a cell array definition of the fields for an 'nsd_document_projectvar' document.
%
% Creates a set of name/value pairs in a 1x4 cell list:
% Name:                   | Value
% ------------------------------------------------------
% 'nsd_document.name'     | NAME
% 'nsd_document.type'     | TYPE
% 'projectvar.description'| DESCRIPTION
% 'projectvar.data'       | DATA 
%

pvd = { ...
	'nsd_document.name', name, ...
	'nsd_document.type', type, ...
	'projectvar.description', description, ...
	'projectvar.data', data ...
	};

