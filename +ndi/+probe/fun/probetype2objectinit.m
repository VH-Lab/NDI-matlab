function ndi_globals.probetype2objectinit
% ndi.probe.fun.PROBETYPE2OBJECTINIT - Initializes the NDI_PROBETYPE2OBJECT global variable in NDI package
%
% ndi.probe.fun.probetype2objectinit
%
% Initializes the NDI_PROBETYPE2OBJECT structure. The structure has two fields,
% 'type' and 'classname'. Each entry describes the ndi.probe subclass to use to
% create an ndi.probe object for the given ndi.epoch.epochprobemap_daqsystem type.
% 
% Use TYPE ndi.probe.fun.probetype2objectinit to see the structure

ndi.globals

j = vlt.file.textfile2char([ndi_globals.path.commonpath filesep 'probe' filesep 'ndi_globals.probetype2object.json']);

ndi_globals.probetype2object = jsondecode(j);


