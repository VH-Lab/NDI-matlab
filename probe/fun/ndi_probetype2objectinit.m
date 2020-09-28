function ndi_globals.probetype2objectinit
% NDI_PROBETYPE2OBJECTINIT - Initializes the NDI_PROBETYPE2OBJECT global variable in NDI package
%
% NDI_PROBETYPE2OBJECTINIT
%
% Initializes the NDI_PROBETYPE2OBJECT structure. The structure has two fields,
% 'type' and 'classname'. Each entry describes the NDI_PROBE subclass to use to
% create an NDI_PROBE object for the given NDI_EPOCHPROBEMAP_DAQSYSTEM type.
% 
% Use TYPE NDI_PROBETYPE2OBJECTINIT to see the structure

ndi_globals

j = vlt.file.textfile2char([ndi_globals.path.commonpath filesep 'probe' filesep 'ndi_globals.probetype2object.json']);

ndi_globals.probetype2object = jsondecode(j);


