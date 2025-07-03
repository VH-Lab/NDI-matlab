function doStacyImport(S, options)
% DOSTACYIMPORT - Imports VH Lab subject and stimulus metadata into an NDI session.
%
%   DOSTACYIMPORT(S, ...)
%
%   This function serves as a pipeline to import metadata for a VH Lab
%   experimental session, represented by the ndi.session.dir object S.
%
%   The import process is divided into several stages:
%   1.  Subject Information: Reads subject data using `subjectInfoTable`,
%       checks for existing subject documents in the session, and creates
%       new documents only for new subjects using `subjectMaker`.
%   2.  Stimulus Approaches: Reads epoch-specific approaches and purposes
%       using `approachMappingTable` and creates the corresponding NDI
%       documents using `stimulusDocMaker`.
%   3.  Treatments: (Placeholder) A section is reserved for importing
%       treatment data.
%
%   This function can also take name/value pairs that modify its behavior:
%   |------------------|----------------------------------------------------|
%   | 'Overwrite'      | A boolean (true/false) that determines whether to  |
%   | (false)          | overwrite existing documents. Default is false.    |
%   |------------------|----------------------------------------------------|
%
%   Example:
%       % Assuming 'mySession' is a valid ndi.session.dir object
%       mySession = ndi.session.dir('/path/to/vhlab/session');
%       ndi.setup.conv.vhlab.doStacyImport(mySession, 'Overwrite', true);
%
    arguments
        S (1,1) ndi.session.dir
        options.Overwrite (1,1) logical = false
    end

    disp('Beginning VH Lab import process...');

    %% Stage 1: Subject Information
    disp('Stage 1: Processing subject information...');

    % First, find any subject documents that already exist in the session
    disp('Searching for existing subject documents...');
    existing_subjects_q = ndi.query('', 'isa', 'subject');
    existingSubjectDocs = S.database_search(existing_subjects_q);
    fprintf('Found %d existing subject documents.\n', numel(existingSubjectDocs));

    % Get the subject information from the lab-specific function
    subject_info_table = ndi.setup.conv.vhlab.subjectInfoTable(S);

    % Use the subjectMaker to process the table and create documents
    subM = ndi.setup.NDIMaker.subjectMaker();

    [subjectInfo, ~] = subM.getSubjectInfoFromTable(subject_info_table, ...
        @ndi.setup.conv.vhlab.createSubjectInformation);

    % Make documents, providing the existing ones to avoid duplicates
    subDocStruct = subM.makeSubjectDocuments(subjectInfo, ...
        'existingSubjectDocs', existingSubjectDocs);
    
    % Add any newly created documents to the session
    subM.addSubjectsToSessions({S}, subDocStruct.documents);

    treatmentTable = ndi.setup.conv.vhlab.treatmentTable(S);
    subM.makeSubjectTreatments(S,treatmentTable,"doAdd",true);

    disp('Stage 1: Subject information processing complete.');
    
    %% Stage 2: Stimulus Approaches and Purposes
    disp('Stage 2: Processing stimulus approaches and purposes...');
    S.getprobes(); % make sure we've accessed the probes

    % Get the table of epoch/approach mappings
    approach_T = ndi.setup.conv.vhlab.approachMappingTable(S);
    
    % Use the stimulusDocMaker to convert the table rows to NDI documents
    % The 'FilenameVariable' is 'epochid' because the epoch IDs correspond
    % to the epoch directory names. The 'approachVariable' is 'approachMapping'.
    stimMaker = ndi.setup.NDIMaker.stimulusDocMaker(S,'vhlab');    
    if ~isempty(approach_T)
        stimMaker.table2approachDocs(approach_T, 'approachMapping', ...
            'FilenameVariable', 'epochid', 'Overwrite', options.Overwrite);
    else
        disp('Approach mapping table is empty, no approach documents to create.');
    end

    disp('Stage 2: Stimulus approach processing complete.');

    %% Stage 3: Treatments
    disp('Stage 3: Processing treatments (placeholder)...');
    % This section is for importing treatment information.
    %
    % % 1. Get treatment data from the lab-specific function
    % treatment_T = ndi.setup.conv.vhlab.treatmentTable(S);
    %
    % % 2. Process the treatment table. This might involve creating 'treatment'
    % %    documents or using the tableDocMaker for more complex data.
    % %    For example:
    % % tdm = ndi.setup.NDIMaker.tableDocMaker(S, 'vhlab');
    % % tdm.table2ontologyTableRowDocs(treatment_T, {'subjectIdentifier','treatment'});
    %
    disp('Stage 3: Complete.');

    disp('Stage 4: Add probe locations for Andrea Stacy (LGN always)')

    p = S.getprobes('type','n-trode')
    pld = ndi.fun.doc.probe.probeLocations4probes(S,p,repmat({'UBERON:0002479'},numel(p),1),'doAdd',true);

    disp('Stage 4: Complete')
    

    disp('Stage 5: Import extracellular spike recordings')

    ndi.setup.conv.vhlab.importMeasuredDataCells(S);

    disp('Stage 5: Complete')    

    disp('VH Lab import process finished.');
end
