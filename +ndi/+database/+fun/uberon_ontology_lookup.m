function [item] = uberon_ontology_lookup(field, value)
% UBERON_ONTOLOGY_LOOKUP - look up an entry in NDI Cloud Ontology
%
% [ITEM] = UBERON_ONTOLOGY_LOOKUP('field',value)
%
% Look up entries in the UBERON ontology
%
% This is current a placeholder to help us look up terms we've requested
% but that are not there yet.
%
% Search for 'Name','Identifier', or 'Description'. This function
% only finds exact matches.
% 
% Example:
%   item = ndi.database.fun.uberon_ontology_lookup(...
%     'Name','lateral ventricular nerve');
%

filename = fullfile(ndi.common.PathConstants.CommonFolder,...
    'controlled_vocabulary','uberon_temp.txt');

s = loadStructArray(filename);

eval(['v={s.' char(field) '};']);

index = find(strcmp(v,value));

item = s(index);
