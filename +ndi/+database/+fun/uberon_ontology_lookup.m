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
    %     'Name','lateral ventricular nerve (sensu Cancer borealis)');
    %

    arguments 
        field (1,:) char {mustBeMember(field,{'Name','Identifier','Description'})}
        value (1,:) 
    end

    isRealUberon = false;

    if strcmp(field,'Name')
       [labels,docs] = ndi.database.fun.lookup_uberon_term(value,'exact',true);
       if numel(docs)==1
           isRealUberon = true;
           item.Description = docs.description{1};
           item.Identifier = str2double(regexp(docs.obo_id, 'UBERON:(\d+)', 'tokens', 'once'));
           item.Name = labels{1};
       end;
    elseif strcmp(field,'Identifier')
        if ischar(value) | isstring(value),
            valueStr = char(value);
        else,
            valueStr = ['UBERON:' int2str(value)];
        end;
        [labels,docs] = ndi.database.fun.lookup_uberon_term(valueStr,'queryFields','obo_id','exact',true);
        if numel(docs)==1
           isRealUberon = true;
           item.Description = docs.description{1};
           item.Identifier = str2double(regexp(docs.obo_id, 'UBERON:(\d+)', 'tokens', 'once'));
           item.Name = labels{1};
        end
    end

    if isRealUberon
        return;
    end

    filename = fullfile(ndi.common.PathConstants.CommonFolder,...
        'controlled_vocabulary','uberon_temp.txt');

    s = table2struct(readtable(filename,'delimiter','\t'));

    if strcmp(field,'Identifier')
        if startsWith(value,'uberon:')
            value = str2double(value(1+numel('uberon:'):end));
        end
        % we have a number
        item = s([s.Identifier]==value);
        return;
    end

    v = {s.(field)};

    item = s(strcmp(v,value));
