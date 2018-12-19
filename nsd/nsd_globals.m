% NSD_GLOBALS - define global variables for NSD
%
% NSD_GLOBALS
%  
% Script that defines some global variables for the NSD package
%
% The following variables are defined:
% 
% Name:                    | Description
% -------------------------------------------------------------------------
% nsdpath                  | The path of the NSD distribution on this machine.
%                          |   (Initialized by nsd_Init.m)
% nsdcommonpath            | The path to the package nsd_common
%                          |   (Initialized by nsd_Init.m)
% nsddocumentpath          | The path of the NSD document definitions
%                          |   (Initialized by nsd_Init.m)
% nsddocumentschemapath    | The path of the NSD document validation schema
%                          |   (Initialized by nsd_Init.m)
% nsdexampleexperpath      | The path to the NSD example experiments
% nsd_probetype2object     | A structure with fields 'type' and 'classname'
%                          |   that describes the default NSD_PROBE classname
%                          |   to use to create a probe for a given type.
% nsd_databasehierarchy    | A structure that describes the order in which to
%                          |   attempt to open databases in the experiment path
%

global nsdpath
global nsdcommonpath
global nsddocumentpath
global nsddocumentschemapath
global nsdexampleexperpath

global nsd_probetype2object
global nsd_databasehierarchy

