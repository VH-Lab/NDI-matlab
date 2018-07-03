function nsd_Init % NSD_INIT - Add paths and initialize variables for NSD
% NSD_INIT 
% 
% Initializes the file path and global variables for class NSD
%

mynsdpath = fileparts(which('nsd_Init'));

addpath(genpath(mynsdpath));

nsd_globals;

nsdpath = mynsdpath;
nsd_probetype2objectinit;
