function [subjectTable] = subject(session)
%SUBJECT Creates a summary table of subjects and their associated metadata.
%
%   subjectTable = subject(SESSION)
%
%   This function queries an NDI session to find all subject documents. For each
%   subject, it then finds and integrates information from associated 'openminds'
%   documents related to 'Strain', 'Species', and 'BiologicalSex', as well as
%   'treatment' documents.
%
%   The function aggregates properties from these dependent documents, such as
%   species name, strain, biological sex, and treatment details. It then
%   formats this aggregated information into a single summary table. Each row
%   in the output table represents a unique subject, and the columns contain
%   the subject's identifiers along with details from its linked documents.
%   Metadata from associated documents is joined using 'SubjectDocumentIdentifier'.
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

% Get all subject documents in the session
query = ndi.query('','isa','subject');
subjectDocs = session.database_search(query);

% Get openminds document table
[strainTable,~,strainSubjects] = ndi.fun.docTable.openminds(session,'Strain','depends_on','subject_id');
if isempty(strainTable)
    [strainTable,~,strainSubjects] = ndi.fun.docTable.openminds(session,'Species','depends_on','subject_id');
end
[bioSexTable,~,bioSexSubjects] = ndi.fun.docTable.openminds(session,'BiologicalSex','depends_on','subject_id');

% Get treatment document table
[treatmentTable,~,treatmentSubjects] = ndi.fun.docTable.treatment(session,'depends_on','subject_id');

% Add SubjectDocumentIdentifier to tables
strainTable.SubjectDocumentIdentifier = strainSubjects;
bioSexTable.SubjectDocumentIdentifier = bioSexSubjects;
treatmentTable.SubjectDocumentIdentifier = treatmentSubjects;

% Initialize table
subjectTable = table();

% Loop through each subject document
for i = 1:numel(subjectDocs)

    % Get subject's local and document id
    subjectTable.SubjectDocumentIdentifier(i) = {subjectDocs{i}.document_properties.base.id};
    subjectTable.SubjectLocalIdentifier(i) = {subjectDocs{i}.document_properties.subject.local_identifier};
end

% Add associated metadata
subjectTable = outerjoin(subjectTable,strainTable,'MergeKeys',true);
subjectTable = outerjoin(subjectTable,bioSexTable,'MergeKeys',true);
if ~isempty(treatmentTable)
    subjectTable = outerjoin(subjectTable,treatmentTable,'MergeKeys',true);
end

% Remove any metadata not linked to a subject
indValid = ndi.fun.table.identifyValidRows(subjectTable,'SubjectDocumentIdentifier',{''});
subjectTable = subjectTable(indValid,:);

if height(subjectTable) ~= numel(subjectDocs)
    warning('NDIFUNDOCTABLESUBJECT:SubjectMismatch',...
        'Found %i subject documents, but returned %i subject table rows.',...
        numel(subjectDocs),height(subjectTable))

end