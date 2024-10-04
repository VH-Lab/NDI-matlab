% NDI_GLOBALS - define global variables for NDI
%
% ndi.globals
%  
% Script that defines some global variables for the NDI package
%
% The following variables are defined:
% 
% Name:                            | Description
% -------------------------------------------------------------------------
% ndi.common.PathConstants.RootFolder            | The path of the NDI distribution on this machine.
%                                  |   (Initialized by ndi_Init.m)
% ndi.common.PathConstants.CommonFolder      | The path to the package ndi_common
%                                  |   (Initialized by ndi_Init.m)
% ndi.common.PathConstants.DocumentFolder    | The path of the NDI document definitions
%                                  |   (Initialized by ndi_Init.m)
% ndi_globals.path. ...            | The path of the NDI document validation schema
%    documentschemapath            |   (Initialized by ndi_Init.m)
% ndi.common.PathConstants.ExampleDataFolder| The path to the NDI example sessions
% ndi_globals.path.preferences     | A path to a directory of preferences files
% ndi_globals.path.filecachepath   | A path where files may be cached (not deleted every time)
% ndi.common.PathConstants.TempFolder        | The path to a directory that may be used for
%                                  |   temporary files (Initialized by ndi_Init.m)
% ndi_globals.path.testpath        | A path to a safe place to run test code
% ndi_globals.path.calcdoc         | A cell array of paths to NDI calculator document definitions
% ndi_globals.path.calcdocschema   | A cell array of paths to NDI calculator document schemas
% ndi_globals.probetype2object     | A structure with fields 'type' and 'classname'
%                                  |   that describes the default ndi.probe classname
%                                  |   to use to create a probe for a given type.
% ndi_globals.databasehierarchy    | A structure that describes the order in which to
%                                  |   attempt to open databases in the session path
%                                  |
% ndi_globals.debug                | A structure with preferences for debugging
% ndi_globals.log                  | An object that manages writing system, error, debugging logs (vlt.app.log)
%

global ndi_globals

if ~exist('initializing_NDI','var'),
	ndi.globals.assert(ndi_globals);
end;

