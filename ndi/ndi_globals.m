% NDI_GLOBALS - define global variables for NDI
%
% NDI_GLOBALS
%  
% Script that defines some global variables for the NDI package
%
% The following variables are defined:
% 
% Name:                    | Description
% -------------------------------------------------------------------------
% ndi.path.path            | The path of the NDI distribution on this machine.
%                          |   (Initialized by ndi_Init.m)
% ndi.path.commonpath      | The path to the package ndi_common
%                          |   (Initialized by ndi_Init.m)
% ndi.path.documentpath    | The path of the NDI document definitions
%                          |   (Initialized by ndi_Init.m)
% ndi.path. ...            | The path of the NDI document validation schema
%    documentschemapath    |   (Initialized by ndi_Init.m)
% ndi.path.exampleexperpath| The path to the NDI example sessions
% ndi.path.filecachepath   | A path where files may be cached (not deleted every time)
% ndi.path.temppath        | The path to a directory that may be used for
%                          |   temporary files (Initialized by ndi_Init.m)
% ndi.path.testpath        | A path to a safe place to run test code
% ndi.probetype2object     | A structure with fields 'type' and 'classname'
%                          |   that describes the default NDI_PROBE classname
%                          |   to use to create a probe for a given type.
% ndi.databasehierarchy    | A structure that describes the order in which to
%                          |   attempt to open databases in the session path
%

global ndi

