function [score,valid,errmsg] = subject(S)
    %SUBJECT Summary of this function goes here
    %   Detailed explanation goes here
    score = 1;
    valid = 1;
    errmsg = '';
    subjects = S.database_search(ndi.query('','isa','subject'));
    openminds_subject = S.database_search(ndi.query('openminds.openminds_type','contains_string', 'Subject'));
    for (i = 1:numel(subjects))
        look_up = subjects{i}.document_properties.subject.local_identifier;
        doc = S.database_search(ndi.query('openminds.fields.lookupLabel', 'exact_string', look_up));
        id = subjects{i}.document_properties.base.id;
        if (numel(doc) == 0)
            errmsg = sprintf('%s\n%s', errmsg, ['Subject ' look_up '. id: ' id ' is not converted to OpenMinds document']);
            valid = 0;
            score = 0;
            continue;
        end
        if (numel(document_properties.openminds.fields.species) == 0)
            errmsg = sprintf('%s\n%s', errmsg, ['Subject ' look_up '. id: ' id ' is missing species']);
            valid = 0;
            score = 0;
        elseif (numel(document_properties.openminds.fields.species) > 1)
            errmsg = sprintf('%s\n%s', errmsg, ['Subject ' look_up '. id: ' id ' has more than one species']);
            valid = 0;
            score = 0;
        end
    end
end
