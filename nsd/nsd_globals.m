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
% nsd_probetype2object     | A structure with fields 'type' and 'classname'
%                          |   that describes the default NSD_PROBE classname
%                          |   to use to create a probe for a given type.
%

global nsdpath
global nsd_probetype2object

