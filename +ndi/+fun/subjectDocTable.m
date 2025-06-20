function [subjectTable] = subjectDocTable(session)
%SUBJECTDOCTABLE Creates a summary table of subjects and their associated metadata.
%
%   subjectTable = subjectDocTable(SESSION)
%
%   This function queries an NDI session to find all subject documents. For each
%   subject, it then finds all associated 'element' and 'openminds_subject'
%   documents that depend on it.
%
%   The function aggregates the properties from these dependent documents (like
%   species, strain, mfdaq names, etc.) and formats them into a single summary
%   table. Each row in the output table represents a single subject, and the
%   columns contain the subject's IDs along with comma-separated lists of the
%   unique properties found in its associated documents.
%
%   Inputs:
%       SESSION - An active and connected ndi.session object.
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

% Find all stimulus bath documents
queryStimulusBath = ndi.query('','isa','stimulus_bath');
stimulusBathDocs = session.database_search(queryStimulusBath);

% Find all stimulus approach documents
queryStimulusApproach = ndi.query('','isa','openminds_stimulus');
stimulusApproachDocs = session.database_search(queryStimulusApproach);

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
    stimulus = struct();    % For 'stimulus_bath' and 'openminds_stimulus' document types

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

                if strcmpi(docProp.element.type,'stimulator')

                    % Get stimulus bath docs corresponding to stimulator
                    stimulusBathDocsInd = cellfun(@(d) strcmp(docProp.base.id,...
                        dependency_value(d,'stimulus_element_id')),stimulusBathDocs);
                    stimulusBathDocsSubject = stimulusBathDocs(stimulusBathDocsInd);

                    if any(stimulusBathDocsInd)

                        % If this is the first time we've seen a mixture, initialize its field
                        if ~isfield(stimulus, 'mixture')
                            stimulus.mixture.name = {};
                            stimulus.mixture.ontology = {};
                        end

                        % Compile mixture table
                        for k = 1:numel(stimulusBathDocsSubject)
                            mixture = stimulusBathDocsSubject{k}.document_properties.stimulus_bath.mixture_table;
                            mixture = ndi.database.fun.readtablechar(mixture,'.txt','Delimiter',',');
                            stimulus.mixture.name(end+(1:height(mixture))) = mixture.name;
                            stimulus.mixture.ontology(end+(1:height(mixture))) = mixture.ontologyName;
                        end
                    end

                    % Get stimulus approach docs corresponding to stimulator
                    stimulusApproachDocsInd = cellfun(@(d) strcmp(docProp.base.id,...
                        dependency_value(d,'stimulus_element_id')),stimulusApproachDocs);
                    stimulusApproachDocsSubject = stimulusApproachDocs(stimulusApproachDocsInd);

                    if any(stimulusApproachDocsInd)

                        % If this is the first time we've seen an approach, initialize its field
                        if ~isfield(stimulus, 'approach')
                            stimulus.approach.name = {};
                            stimulus.approach.ontology = {};
                        end

                        % Append approaches to the stimulus structure
                        for k = 1:numel(stimulusApproachDocsSubject)
                            stimulus.approach.name{end+1} = ...
                                stimulusApproachDocsSubject{k}.document_properties.openminds.fields.name;
                            stimulus.approach.ontology{end+1} = ...
                                stimulusApproachDocsSubject{k}.document_properties.openminds.fields.preferredOntologyIdentifier;
                        end
                    end
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
        subjectTable(i,[currentType,'Name']) = {strjoin(unique(names), ', ')};
        subjectTable(i,[currentType,'Ontology']) = {strjoin(unique(ontologys), ', ')};
    end

    % Process the aggregated element data
    elementTypes = fieldnames(element);
    for k = 1:numel(elementTypes)
        currentType = elementTypes{k};

        % Get unique, non-empty values
        names = element.(currentType).name(~cellfun('isempty', element.(currentType).name));
        types = element.(currentType).type(~cellfun('isempty', element.(currentType).type));

        % Create comma-separated strings and assign to the table.
        subjectTable(i,[currentType,'Name']) = {strjoin(unique(names), ', ')};
        subjectTable(i,[currentType,'Type']) = {strjoin(unique(types), ', ')};
    end

    % Process the aggregated stimulus approach data
    stimulusTypes = fieldnames(stimulus);
    for k = 1:numel(stimulusTypes)
        currentType = stimulusTypes{k};
        
        % Get unique, non-empty values
        names = stimulus.(currentType).name(~cellfun('isempty', stimulus.(currentType).name));
        ontologys = stimulus.(currentType).ontology(~cellfun('isempty', stimulus.(currentType).ontology));

        % Create comma-separated strings and assign to the table.
        subjectTable(i,[currentType,'Name']) = {strjoin(unique(names), ', ')};
        subjectTable(i,[currentType,'Ontology']) = {strjoin(unique(ontologys), ', ')};
    end
end
end