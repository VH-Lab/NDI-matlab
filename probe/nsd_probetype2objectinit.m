function nsd_probetype2objectinit
% NSD_PROBETYPE2OBJECTINIT - Initializes the NSD_PROBETYPE2OBJECT global variable in NSD package
%
% NSD_PROBETYPE2OBJECTINIT
%
% Initializes the NSD_PROBETYPE2OBJECT structure. The structure has two fields,
% 'type' and 'classname'. Each entry describes the NSD_PROBE subclass to use to
% create an NSD_PROBE object for the given NSD_EPOCHCONTENTS_IODEVICE type.
% 
% Use TYPE NSD_PROBETYPE2OBJECTINIT to see the structure

nsd_globals

j = textfile2char([nsdcommonpath filesep 'probe' filesep 'nsd_probetype2object.json']);

nsd_probetype2object = jsondecode(j);


