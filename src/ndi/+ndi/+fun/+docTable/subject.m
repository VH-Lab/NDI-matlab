function [subjectTable] = subject(session)
%SUBJECT Creates a summary table of subjects and their associated metadata.
%
%   subjectTable = subject(SESSION)
%
%   This function queries an NDI session to find all subject documents. For each
%   subject, it then finds and integrates information from associated 'openminds'
%   documents related to 'Strain', 'Species', and 'BiologicalSex', as well as
%   'treatment' documents. This is done by performing a minimal number of broad
%   queries and passing the results to helper functions for targeted processing.
%
%   The function aggregates properties from these dependent documents, such as
%   species name, strain, biological sex, and treatment details. It then
%   formats this aggregated information into a single summary table. Each row
%   in the output table represents a unique subject, and the columns contain
%   the subject's identifiers along with details from its linked documents.
%   Metadata from associated documents is joined using 'SubjectDocumentIdentifier'.
%
%   This function is robust to missing metadata; if a session lacks strain,
%   species, or biological sex documents, the function will still run and
%   simply omit the corresponding columns from the final table.
%
%   Inputs:
%       SESSION - An active and connected ndi.session or ndi.dataset object.
%
%   Outputs:
%       subjectTable - A MATLAB table where each row corresponds to a subject.
%                      Common columns include 'SubjectDocumentIdentifier',
%                      'SubjectLocalIdentifier', 'StrainName', 'SpeciesName',
%                      'BiologicalSexOntology', and various fields from 'treatment'
%                      documents, depending on the available data.
%
%   See also: ndi.session, ndi.query, table, outerjoin, 
%   ndi.fun.docTable.openminds, ndi.fun.docTable.treatment, 
%   ndi.fun.table.identifyValidRows
% Input argument validation
arguments
    session {mustBeA(session,{'ndi.session.dir','ndi.dataset.dir'})}
end
% --- Step 1: Get all subject documents ---
query = ndi.query('','isa','subject');
subjectDocs = session.database_search(query);
if isempty(subjectDocs)
    subjectTable = table(); % No subjects found, return an empty table
    return;
end

% Initialize table with core subject information efficiently
doc_ids = cellfun(@(d) d.document_properties.base.id, subjectDocs, 'UniformOutput', false);
local_ids = cellfun(@(d) d.document_properties.subject.local_identifier, subjectDocs, 'UniformOutput', false);
subjectTable = table(doc_ids(:), local_ids(:), 'VariableNames', {'SubjectDocumentIdentifier', 'SubjectLocalIdentifier'});

% --- Step 2: Perform a single, broad query for all openminds metadata ---
% This is expensive, but we only do it once.
q_all_openminds = ndi.query('','isa','openminds');
allOpenMindsDocs = session.database_search(q_all_openminds);

% --- Step 3: Process the pre-fetched documents and join them ---
% Get Strain/Species table
[strainTable,~,strainSubjects] = ndi.fun.docTable.openminds(session,'Strain',...
    'depends_on','subject_id', 'depends_on_docs', subjectDocs, 'allOpenMindsDocs', allOpenMindsDocs);
if isempty(strainTable)
    [strainTable,~,strainSubjects] = ndi.fun.docTable.openminds(session,'Species',...
    'depends_on','subject_id', 'depends_on_docs', subjectDocs, 'allOpenMindsDocs', allOpenMindsDocs);
end
if ~isempty(strainTable)
    strainTable.SubjectDocumentIdentifier = strainSubjects;
    subjectTable = outerjoin(subjectTable,strainTable,'MergeKeys',true);
end
% Get Biological Sex table
[bioSexTable,~,bioSexSubjects] = ndi.fun.docTable.openminds(session,'BiologicalSex',...
    'depends_on','subject_id', 'depends_on_docs', subjectDocs, 'allOpenMindsDocs', allOpenMindsDocs);
if ~isempty(bioSexTable)
    bioSexTable.SubjectDocumentIdentifier = bioSexSubjects;
    subjectTable = outerjoin(subjectTable,bioSexTable,'MergeKeys',true);
end
% Get treatment document table
[treatmentTable,~,treatmentSubjects] = ndi.fun.docTable.treatment(session,'depends_on_docs', subjectDocs);
if ~isempty(treatmentTable)
    treatmentTable.SubjectDocumentIdentifier = treatmentSubjects;
    subjectTable = outerjoin(subjectTable,treatmentTable,'MergeKeys',true);
end

% --- Step 4: Final cleanup ---
indValid = ndi.fun.table.identifyValidRows(subjectTable,'SubjectDocumentIdentifier',{''});
subjectTable = subjectTable(indValid,:);
if height(subjectTable) ~= numel(subjectDocs)
    warning('NDIFUNDOCTABLESUBJECT:SubjectMismatch',...
        'Found %i subject documents, but returned %i subject table rows.',...
        numel(subjectDocs),height(subjectTable))
end

