function [item] = ndicloud_ontology_lookup(field, value)
    % NDICLOUD_ONTOLOGY_LOOKUP - look up an entry in NDI Cloud Ontology
    %
    % [ITEM] = NDICLOUD_ONTOLOGY_LOOKUP('field',value)
    %
    % Look up entries in the NDI Cloud Ontology.
    %
    % Search for 'Name','Identifier', or 'Description'. This function
    % only finds exact matches.
    %
    % Example:
    %   item = ndi.database.fun.ndicloud_ontology_lookup(...
    %     'Name','Left eye view blocked');
    %

    filename = fullfile(ndi.common.PathConstants.CommonFolder,...
        'controlled_vocabulary','NDIC.txt');

    s = loadStructArray(filename);

    eval(['v={s.' field '};']);

    index = find(strcmp(v,value));

    item = s(index);
