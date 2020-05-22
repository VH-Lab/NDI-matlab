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
% ndipath                  | The path of the NDI distribution on this machine.
%                          |   (Initialized by ndi_Init.m)
% ndicommonpath            | The path to the package ndi_common
%                          |   (Initialized by ndi_Init.m)
% ndidocumentpath          | The path of the NDI document definitions
%                          |   (Initialized by ndi_Init.m)
% ndidocumentschemapath    | The path of the NDI document validation schema
%                          |   (Initialized by ndi_Init.m)
% ndiexampleexperpath      | The path to the NDI example sessions
% nditestpath              | A path to a safe place to run test code
% ndi_probetype2object     | A structure with fields 'type' and 'classname'
%                          |   that describes the default NDI_PROBE classname
%                          |   to use to create a probe for a given type.
% ndi_databasehierarchy    | A structure that describes the order in which to
%                          |   attempt to open databases in the session path
%

global ndipath
global ndicommonpath
global ndidocumentpath
global ndidocumentschemapath
global ndiexampleexperpath
global nditestpath

global ndi_probetype2object
global ndi_databasehierarchy

global ndi_debug;


