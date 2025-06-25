function [subjectTable] = subjectDocTable(session)
%SUBJECTDOCTABLE Creates a summary table of subjects and their associated metadata.
%
%   subjectTable = subjectDocTable(SESSION)
%
%   This function queries an NDI session to find all subject documents. For each
%   subject, it then finds all associated 'element', 'openminds_subject', and
%   'treatment' documents that depend on it.
%
%   The function aggregates the properties from these dependent documents (like
%   species, strain, mfdaq names, etc.) and formats them into a single summary
%   table. Each row in the output table represents a single subject, and the
%   columns contain the subject's IDs along with comma-separated lists of the
%   unique properties found in its associated documents.
%
%   Inputs:
%       SESSION - An active and connected ndi.session or ndi.dataset object.
%
%   Outputs:
%       subjectTable - A MATLAB table where each row is a subject and columns
%       are dynamically generated based on the data found. Common columns include
%       'documentID', 'localID', 'SpeciesName', 'SpeciesOntology', 'mfdaqName',
%       'mfdaqType', etc.
%
%   See also: ndi.session, ndi.query, table, struct2table

% Input argument validation
arguments
    session {mustBeA(session,{'ndi.session.dir','ndi.dataset.dir'})}
end

% Get all subject documents in the session
query = ndi.query('','isa','subject');
subjectDocs = session.database_search(query);

% Initialize table
subjectTable = table();

% This warning is suppressed because we are building the table "unevenly".
% One subject might have a 'Strain' and add a 'StrainName' column. The next
% subject might not have a strain, so MATLAB warns that it's filling that
% column with a default (empty) value. This is expected behavior here.
warning('off', 'MATLAB:table:RowsAddedExistingVars');

% Find all the dependent docs
if numel(subjectDocs) > 0

    % Build query containing all subject ids
    querySubjectID = ndi.query('','depends_on','subject_id',subjectDocs{1}.document_properties.base.id);
    for i = 2:numel(subjectDocs)
        querySubjectID = querySubjectID | ndi.query('','depends_on','subject_id',subjectDocs{i}.document_properties.base.id);
    end

    % Find dependent docs for all subjects
    dependentDocs = session.database_search(querySubjectID);
end

% Loop through each subject document
for i = 1:numel(subjectDocs)

    % Get dependent docs corresponding to this subject
    dependentDocsInd = cellfun(@(d) strcmp(subjectDocs{i}.document_properties.base.id,...
        dependency_value(d,'subject_id')),dependentDocs);
    dependentDocsSubject = dependentDocs(dependentDocsInd);
    
    % Get subject's local and document id
    subjectTable.documentID(i) = {subjectDocs{i}.document_properties.base.id};
    subjectTable.localID(i) = {subjectDocs{i}.document_properties.subject.local_identifier};

    % Initialize temporary structs to aggregate data for the current subject
    element = struct();     % For 'element' document types
    openMINDs = struct();   % For 'openminds_subject' document type
    treatment = struct();   % For 'treatment' document type

    for j = 1:numel(dependentDocsSubject)
        docProp = dependentDocsSubject{j}.document_properties;
        
        % Switch based on the document's class
        switch docProp.document_class.class_name
            
            case 'openminds_subject'

                % Extract the specific openMINDs type (e.g., 'Species')
                dataType = regexp(docProp.openminds.openminds_type, '[^/]*$', 'match', 'once');
                
                % Find the onotology field name
                fieldNames = fields(docProp.openminds.fields);
                ontologyField = fieldNames{contains(fieldNames,'ontology','IgnoreCase',true)};

                % If this is the first time we've seen this element type, initialize its field
                if ~isfield(openMINDs, dataType)
                    openMINDs.(dataType).name = {};
                    openMINDs.(dataType).ontology = {};
                end

                % Append the data to our temporary struct
                openMINDs.(dataType).name{end+1} = docProp.openminds.fields.name;
                openMINDs.(dataType).ontology{end+1} = docProp.openminds.fields.(ontologyField);     

            case 'element'
                
                % Extract the specific element type (e.g., 'mfdaq') from the full class name
                dataType = regexp(docProp.element.ndi_element_class, '[^.]*$', 'match', 'once');

                % If this is the first time we've seen this element type, initialize its field
                if ~isfield(element, dataType)
                    element.(dataType).name = {};
                    element.(dataType).type = {};
                end
                
                % Append the element's name and type to our temporary struct
                element.(dataType).name{end+1} = docProp.element.name;
                element.(dataType).type{end+1} = docProp.element.type;

            case 'treatment'
                
                % Get datatype and values
                dataType = replace(docProp.treatment.name,' ','');
                numericValue = docProp.treatment.numeric_value;
                stringValue = docProp.treatment.string_value;

                % If this is the first time we've seen this element type, initialize its field
                if ~isfield(treatment, dataType)
                    treatment.(dataType).name = {};
                    treatment.(dataType).ontology = {};
                    treatment.(dataType).value = {};
                    treatment.(dataType).numericValue = {};
                    treatment.(dataType).stringValue = {};
                end

                % Check if string value is an ontology node
                if contains(stringValue,':')
                    try
                        [stringOntology,stringName] = ndi.ontology.lookup(stringValue);
                    catch
                        stringOntology = [];
                        stringName = [];
                    end
                end

                % Get values
                if ~isempty(numericValue) & isempty(stringValue)
                    treatment.(dataType).value{end+1} = numericValue;
                end
                if ~isempty(stringOntology)
                    treatment.(dataType).name{end+1} = stringName;
                    treatment.(dataType).ontology{end+1} = stringOntology;
                elseif ~isempty(stringValue) & isempty(numericValue)
                    treatment.(dataType).value{end+1} = stringValue;
                elseif ~isempty(stringValue) & ~isempty(numericValue)
                    treatment.(dataType).numericValue{end+1} = numericValue;
                    treatment.(dataType).stringValue{end+1} = stringValue;
                end
        end
    end

    % Process the aggregated openMINDs data
    openMINDsTypes = fieldnames(openMINDs);
    for k = 1:numel(openMINDsTypes)
        currentType = openMINDsTypes{k};

        % Get unique, non-empty values
        names = openMINDs.(currentType).name(~cellfun('isempty', openMINDs.(currentType).name));
        ontologys = openMINDs.(currentType).ontology(~cellfun('isempty', openMINDs.(currentType).ontology));

        % Create comma-separated strings and assign to the table.
        subjectTable(i,[currentType,'Name']) = {strjoin(unique(names,'stable'), ', ')};
        subjectTable(i,[currentType,'Ontology']) = {strjoin(unique(ontologys,'stable'), ', ')};
    end

    % Process the aggregated element data
    elementTypes = fieldnames(element);
    for k = 1:numel(elementTypes)
        currentType = elementTypes{k};

        % Get unique, non-empty values
        names = element.(currentType).name(~cellfun('isempty', element.(currentType).name));
        types = element.(currentType).type(~cellfun('isempty', element.(currentType).type));

        % Create comma-separated strings and assign to the table.
        subjectTable(i,[currentType,'Name']) = {strjoin(unique(names,'stable'), ', ')};
        subjectTable(i,[currentType,'Type']) = {strjoin(unique(types,'stable'), ', ')};
    end

    % Process the aggregated treatment data
    treatmentTypes = fieldnames(treatment);
    for k = 1:numel(treatmentTypes)
        currentType = treatmentTypes{k};

        % Get unique, non-empty values
        names = treatment.(currentType).name(~cellfun('isempty', treatment.(currentType).name));
        ontologys = treatment.(currentType).ontology(~cellfun('isempty', treatment.(currentType).ontology));
        values = treatment.(currentType).value(~cellfun('isempty', treatment.(currentType).value));
        numericValues = treatment.(currentType).numericValue(~cellfun('isempty', treatment.(currentType).numericValue));
        stringValues = treatment.(currentType).stringValue(~cellfun('isempty', treatment.(currentType).stringValue));
        
        % Create comma-separated strings and assign to the table.
        subjectTable(i,[currentType,'Name']) = {strjoin(unique(names,'stable'), ', ')};
        subjectTable(i,[currentType,'Ontology']) = {strjoin(unique(ontologys,'stable'), ', ')};
        subjectTable(i,currentType) = {strjoin(unique(values,'stable'), ', ')};
        subjectTable(i,[currentType,'Number']) = {strjoin(unique(numericValues,'stable'), ', ')};
        subjectTable(i,[currentType,'String']) = {strjoin(unique(stringValues,'stable'), ', ')};
    end
end

% Remove empty columns
indEmpty = cellfun(@(t) isempty(t),subjectTable.Variables);
subjectTable(:,all(indEmpty)) = [];

end