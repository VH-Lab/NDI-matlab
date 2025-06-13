function [subjectTable] = subjectDocTable(session)

% Get all subject documents in the session
query = ndi.query('','isa','subject');
subjectDocs = session.database_search(query);

% Initialize table
subjectTable = table();
warning('off', 'MATLAB:table:RowsAddedExistingVars');

for i = 1:numel(localID)
    % Get subject's local and document id
    subjectTable.documentID(i) = {subjectDocs{i}.document_properties.base.id};
    subjectTable.localID(i) = {subjectDocs{i}.document_properties.subject.local_identifier};

    % Get all documents associated with that subject
    querySubjectID = ndi.query('','depends_on','subject_id',documentID(i));
    dependentDocs = session.database_search(querySubjectID);

    % Intialize variables
    element = struct();
    openMINDs = struct();

    for j = 1:numel(dependentDocs)
        docProp = dependentDocs{j}.document_properties;
        
        switch docProp.document_class.class_name
            case 'element'
                dataType = regexp(docProp.element.ndi_element_class, '[^.]*$', 'match', 'once');

                if ~isfield(element, dataType)
                    element.(dataType).name = {};
                    element.(dataType).type = {};
                end
                
                element.(dataType).name{end+1} = docProp.element.name;
                element.(dataType).type{end+1} = docProp.element.type;
                
            case 'openminds_subject'
                dataType = regexp(docProp.openminds.openminds_type, '[^/]*$', 'match', 'once');
                fieldNames = fields(docProp.openminds.fields);
                ontologyField = fieldNames{contains(fieldNames,'ontology','IgnoreCase',true)};

                if ~isfield(openMINDs, dataType)
                    openMINDs.(dataType).name = {};
                    openMINDs.(dataType).ontology = {};
                end

                openMINDs.(dataType).name{end+1} = docProp.openminds.fields.name;
                openMINDs.(dataType).ontology{end+1} = docProp.openminds.fields.(ontologyField);
               
        end
    end

    openMINDsTypes = fieldnames(openMINDs);
    for k = 1:numel(openMINDsTypes)
        currentType = openMINDsTypes{k};

        % Filter out empty cells before joining to avoid stray commas
        names = openMINDs.(currentType).name(~cellfun('isempty', openMINDs.(currentType).name));
        ontologys = openMINDs.(currentType).ontology(~cellfun('isempty', openMINDs.(currentType).ontology));

        subjectTable(i,[currentType,'Name']) = {strjoin(unique(names), ', ')};
        subjectTable(i,[currentType,'Ontology']) = {strjoin(unique(ontologys), ', ')};
    end

    elementTypes = fieldnames(element);
    for k = 1:numel(elementTypes)
        currentType = elementTypes{k};

        % Filter out empty cells before joining to avoid stray commas
        names = element.(currentType).name(~cellfun('isempty', element.(currentType).name));
        types = element.(currentType).type(~cellfun('isempty', element.(currentType).type));

        subjectTable(i,[currentType,'Name']) = {strjoin(unique(names), ', ')};
        subjectTable(i,[currentType,'Type']) = {strjoin(unique(types), ', ')};
    end
end

end