function S = import_data(dataPath)
% IMPORT_DATA - Build an NDI session with subjects from a Birren lab epochs table.
%
%   S = NDI.SETUP.CONV.BIRREN.IMPORT_DATA(DATAPATH)
%
%   This function takes a base directory path to create and populate a new NDI session.
%   It reads the epoch information directly from 'sayaTable.xls' located within DATAPATH.
%
%   It performs the following steps:
%   1. Reads the epoch metadata from 'sayaTable.xls'.
%   2. Initializes a new NDI session directly in the specified DATAPATH and adds
%      the 'sjbirrenlab' DAQ systems using ndi.setup.lab.
%   3. Uses the ndi.setup.NDIMaker.subjectMaker.addSubjectsFromTable method
%      to process the EPOCHSTABLE, create NDI documents for each unique subject,
%      and add them to the session's database.
%   4. Prepares the epochs table with a subject-specific postfix and calls the
%      epochProbeMapMaker a single time to generate all map files efficiently.
%   5. Creates a treatment table based on the metadata in the epochs table.
%
%   Inputs:
%       dataPath (char)     - The full path to the directory where 'sayaTable.xls' is located
%                             and where the NDI session will be created.
%
%   Outputs:
%       S (ndi.session.dir) - The newly created NDI session object, now populated
%                             with the subjects from the table.
%
%   Example:
%       myDataPath = '/path/to/my/labdata_session';
%       if ~exist(myDataPath,'dir'), mkdir(myDataPath); end
%       % Ensure 'sayaTable.xls' and data subdirectories are in myDataPath
%       newSession = ndi.setup.conv.birren.import_data(myDataPath);
%

    % 1. Read the epochs table from the specified Excel file
    disp("Reading epoch data from 'sayaTable.xls'...");
    epochsTable = readtable(fullfile(dataPath,'sayaTable.xls'));

    % 2. Define session path and create the NDI session object using ndi.setup.lab
    sessionPath = dataPath; % The session is now created at the dataPath
    if ~exist(sessionPath, 'dir')
        mkdir(sessionPath);
    end
    
    [~, session_ref] = fileparts(sessionPath);
    disp('Initializing session and adding DAQ systems for sjbirrenlab...');
    S = ndi.setup.lab('sjbirrenlab', session_ref, sessionPath);

    % 3. Create and add subjects from the table using the new consolidated method
    subM = ndi.setup.NDIMaker.subjectMaker();
    creator = ndi.setup.conv.birren.SubjectInformationCreator();
    [subjectInfo, allSubjectNames] = subM.addSubjectsFromTable(S, epochsTable, creator);

    if isempty(subjectInfo.subjectName)
        % The addSubjectsFromTable method already displays a message,
        % but we still need to exit the importer if no subjects were added.
        disp('Import halted as no subjects were added.');
        return;
    end
    
    % 4. Create epoch probe maps using the ProbePostfix method
    disp('Creating epoch probe maps using the ProbePostfix method...');
    
    %   a. Define the BASE probe table (generic names)
    daqsystem_name = 'sjbirren_abf'; % This name comes from your JSON file
    name = {'bath';'Vm'};
    reference = {1;1};
    type = {'stimulator';'patch-Vm'};
    deviceString = {[daqsystem_name ':ai1'];[daqsystem_name ':ai1']};
    probeTable = table(name,reference,type,deviceString);

    %   b. Create and populate the ProbePostfix column in epochsTable
    epochsTable.ProbePostfix = cell(height(epochsTable), 1);
    for i = 1:height(epochsTable)
        subject_id = allSubjectNames{i};
        postfix_parts = split(subject_id, '@');
        postfix = ['_' postfix_parts{1}]; % e.g., '_2024_08_20_1'
        epochsTable.ProbePostfix{i} = postfix;
    end

    %   c. Prepare the rest of the table for the epochProbeMapMaker
    epochsTable.SubjectString = allSubjectNames;
    epochsTable.Properties.RowNames = epochsTable.filename;
    
    %   d. Make a SINGLE call to the epochProbeMapMaker with the ProbePostfix argument
    ndi.setup.NDIMaker.epochProbeMapMaker(dataPath, epochsTable, probeTable, ...
        'ProbePostfix', 'ProbePostfix', ...
        'Overwrite', true);

    % 5. Create the treatment table for debugging
    disp('Creating treatment table...');
    treatment_creator = ndi.setup.conv.birren.TreatmentCreator();
    treatmentTable = treatment_creator.create(epochsTable, allSubjectNames, S);
    disp('Created Treatment Table:');
    TM = ndi.setup.NDIMaker.treatmentMaker();
    TM.addTreatmentsFromTable(S, treatmentTable);

    disp('Import complete.');

end
