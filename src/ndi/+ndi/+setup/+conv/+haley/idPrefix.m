function p = idPrefix(folder)
%IDPREFIX The local_identifier prefix for a Haley source folder.
%
%   P = ndi.setup.conv.haley.idPrefix(FOLDER) returns the prefix every
%   local_identifier from FOLDER starts with (decision log #37): the folder
%   name without `foraging`, lower-cased -- foragingConcentration ->
%   concentration, foragingMini -> mini, ecoli -> ecoli.
%
%   The FOLDER, not the study, is the prefix: plate and worm numbers restart
%   in each folder, and foragingConcentration holds two studies numbered
%   together, so the folder is what makes a number unique in the dataset.

arguments
    folder (1,:) char
end
p = regexprep(folder, '^foraging', '');
p = lower(p);
if isempty(p)
    error('ndi:setup:conv:haley:badFolder', 'No identifier prefix for folder "%s".', folder);
end
end
