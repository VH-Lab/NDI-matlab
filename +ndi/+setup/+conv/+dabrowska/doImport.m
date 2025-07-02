 function sessionArray = doImport(dataParentDir,options)
% Section A: Import electrophysiology dataset
%   Step 1: VARIABLE TABLE. Get the file manifest and build a table, with one row per data file.
%   Step 2: SESSIONS. Now that we have the file manifest, build sessions.
%   Step 3: SUBJECTS. Build subject documents.
%   Step 4: EPOCHPROBEMAPS. Build epochprobemaps.
%   Step 5: STIMULUS DOCS. Build the stimulus bath and approach documents.
%   Step 6: CELL TYPES. Add openMinds celltypes and probe location documents.
%   Step 7: VIRUSES AND TREATMENTS. Add virus injection and optogenetic location treatment documents.
%
% Section B: Import behavioral dataset
%   Step 8: EPM DATA TABLE. Build data table for Elevated Plus Maze data.
%   Step 9: FPS DATA TABLE. Build data table for Fear-Potentiated Startle data.
%   Step 10: SUBJECTS. Build subject documents.
%   Step 11: ONTOLOGYTABLEROW. Build ontologyTableRow documents.

% Input argument validation
arguments
    dataParentDir (1,:) char {mustBeFolder}
    options.Overwrite (1,1) logical = false
end

%% Create progress bar
ndi.gui.component.ProgressBarWindow('Import Dataset');

% Get data path
dataPath = fullfile(dataParentDir,'Dabrowska');

% Deal with bad paths
badFolder = fullfile(dataPath,'Electrophysiology Data - Wild-type/TGOT_IV_Curves_Type III_BNST_neurons/Apr 26  2022');
if isfolder(badFolder)
    disp(['Removing extra space chacter in known folder ' badFolder])
    movefile(badFolder,replace(badFolder,'  ',' '));
end

badFolder = fullfile(dataPath,'Electrophysiology Data _ Optogenetics/AVP_Cre_SON/SON/Pre & TLS/Type III/Mar 16 223');
if isfolder(badFolder)
    disp(['Correcting year in known folder ' badFolder])
    movefile(badFolder,replace(badFolder,'223','2023'))
end

[fileList] = vlt.file.manifest(dataPath);
fileList = fullfile(dataParentDir,fileList);
badFileInd = find(contains(fileList,'Copy of'));
if ~isempty(badFileInd)
    fprintf('Removing "Copy of" from %i known files.\n',numel(badFileInd))
    for i = 1:numel(badFileInd)
        badFile = fileList{badFileInd(i)};
        movefile(badFile,replace(badFile,'Copy of ',''));
    end
end

%% Step 1: VARIABLE TABLE. Get the file manifest and build a table, with one row per data file.

[dirList,isDir] = vlt.file.manifest(dataPath);
fileList = dirList(~isDir);
include = ~contains(fileList,'/._') & ~startsWith(fileList,'._') & ...
    ~contains(fileList,'.DS_Store') & ~endsWith(fileList,'epochprobemap.txt') & ~endsWith(fileList,'.epochid.ndi');
fileList = fileList(include);

% Get variable table (electrophysiology)
jsonPath = fullfile(userpath,'tools/NDI-matlab/+ndi/+setup/+conv/+dabrowska/dabrowska_fileManifest_ephys.json');
j = jsondecode(fileread(jsonPath));
variableTable_ephys = ndi.setup.conv.datalocation.processFileManifest(fileList,j);

% Get variable table (optogenetics)
jsonPath = fullfile(userpath,'tools/NDI-matlab/+ndi/+setup/+conv/+dabrowska/dabrowska_fileManifest_opto.json');
j = jsondecode(fileread(jsonPath));
variableTable_opto = ndi.setup.conv.datalocation.processFileManifest(fileList,j);

% Deal with OTA and TLS
indEpoch = ndi.fun.table.identifyValidRows(variableTable_opto,'BathConditionString');
variableTable_opto.BathConditionString(indEpoch) = replace(variableTable_opto.BathConditionString(indEpoch),'TLS','Post');
OTAInd = find(ndi.fun.table.identifyValidRows(variableTable_opto,'OTA') & indEpoch);
for i = 1:numel(OTAInd)
    bcs = variableTable_opto.BathConditionString{OTAInd(i)};
    if ~contains(bcs,'OTA')
        variableTable_opto.BathConditionString(OTAInd(i)) = join({bcs,'OTA'},' + ');
    end
end

% Combine variable tables with common rows
opto_rows = contains(variableTable_ephys.Properties.RowNames,'Optogenetics');
common_vars = intersect(variableTable_ephys.Properties.VariableNames,...
    variableTable_opto.Properties.VariableNames);
variableTable = variableTable_ephys(:,common_vars);
variableTable(opto_rows,:) = variableTable_opto(opto_rows,common_vars);

% Fix cell type string
cellTypeInd = ndi.fun.table.identifyValidRows(variableTable,'CellType');
variableTable.CellType(cellTypeInd) = cellfun(@(s) replace(s,'_',' '),...
    variableTable.CellType(cellTypeInd),'UniformOutput',false);
variableTable.CellType(~cellTypeInd) = {''};

% Create opto postfix
variableTable.OptoPostfix(:) = {''};
variableTable.OptoPostfix(opto_rows) = cellfun(@(p) ['_',p],...
    variableTable.ProbeLocationString(opto_rows), 'UniformOutput', false);

% Add additional metadata
variableTable{:,'SessionRef'} = {'Dabrowska_Electrophysiology'};
variableTable{:,'SessionPath'} = {'Dabrowska'};
variableTable{:,'SpeciesOntologyID'} = {'NCBITaxon:10116'}; % Rattus norvegicus
variableTable{:,'BiologicalSex'} = {'male'};
variableTable{:,'SubjectPostfix'} = {'@dabrowska-lab.rosalindfranklin.edu'};
variableTable{:,'SubjectPostfix'} = cellfun(@(celltype,opto) ...
    ['_BNST',celltype(6:end),opto,'@dabrowska-lab.rosalindfranklin.edu'],...
    variableTable.CellType,variableTable.OptoPostfix,'UniformOutput',false);

%% Step 2: SESSIONS. Now that we have the file manifest, build sessions.

% Employ the sessionMaker
mySessionPath = dataParentDir;
SM = ndi.setup.NDIMaker.sessionMaker(mySessionPath,variableTable,...
    'NonNaNVariableNames','IsExpMatFile','Overwrite',options.Overwrite);
[sessionArray,variableTable.sessionInd,variableTable.sessionID] = SM.sessionIndices;

% Add DAQ system
labName = 'dabrowskalab';
SM.addDaqSystem(labName,'Overwrite',options.Overwrite)

%% Step 3: SUBJECTS. Build subject documents.

% query = ndi.query('','isa','subject');
% subjects = sessionArray{1}.database_search(query);
% sessionArray{1}.database_rm(subjects);
subM = ndi.setup.NDIMaker.subjectMaker();
[subjectInfo_ephys,variableTable.SubjectString] = ...
    subM.getSubjectInfoFromTable(variableTable,...
    @ndi.setup.conv.dabrowska.createSubjectInformation);
% We have no need to delete any previously made subjects because we remade all the sessions
% but if we did we could use the subM.deleteSubjectDocs method
% subM.deleteSubjectDocs(sessionArray,subjectInfo_ephys.subjectName);
subDocStruct = subM.makeSubjectDocuments(subjectInfo_ephys);
subM.addSubjectsToSessions(sessionArray, subDocStruct.documents);

%% Step 4: EPOCHPROBEMAPS. Build epochprobemaps.

% Create probeTable
name = {'bath';'Vm';'I'};
reference = {1;1;1};
type = {'stimulator';'patch-Vm';'patch-I'};
deviceString = {'dabrowska_mat:ai1';'dabrowska_mat:ai1';'dabrowska_mat:ao1'};
probeTable = table(name,reference,type,deviceString);

% Create probePostfix
indEpoch = ndi.fun.table.identifyValidRows(variableTable,'IsExpMatFile');
recordingDates = datetime(variableTable.RecordingDate(indEpoch),...
    'InputFormat','MMM dd yyyy');
recordingDates = cellstr(char(recordingDates,'yyMMdd'));
sliceLabel = variableTable.SliceLabel(indEpoch);
sliceLabel(strcmp(sliceLabel,{''})) = {'a'};
variableTable.ProbePostfix = cell(height(variableTable),1);
variableTable{indEpoch,'ProbePostfix'} = cellfun(@(rd,celltype,opto,sl) ...
    ['_',rd,'_BNST',celltype(6:end),opto,'_',sl],...
    recordingDates,variableTable.CellType(indEpoch),...
    variableTable.OptoPostfix(indEpoch),sliceLabel,'UniformOutput',false);

% Create epoch probe maps
ndi.setup.NDIMaker.epochProbeMapMaker(dataParentDir,variableTable,probeTable,...
    'Overwrite',options.Overwrite,...
    'NonNaNVariableNames','IsExpMatFile',...
    'ProbePostfix','ProbePostfix');

%% Step 5: STIMULUS DOCS. Build the stimulus bath and approach documents.

sd = ndi.setup.NDIMaker.stimulusDocMaker(sessionArray{1},'dabrowska',...
    'GetProbes',true);

% Get mixture dictionary
jsonPath = fullfile(ndi.common.PathConstants.RootFolder,'+ndi','+setup','+conv',...
    '+dabrowska','dabrowska_mixtures_dictionary.json');
mixture_dictionary = jsondecode(fileread(jsonPath));

% Get stimulus bath docs
sd.table2bathDocs(variableTable,...
    'bath','BathConditionString',...
    'MixtureDictionary',mixture_dictionary,...
    'NonNaNVariableNames','sessionInd', ...
    'MixtureDelimeter','+',...
    'Overwrite',options.Overwrite);

% Define approachName
% indTLS = ndi.fun.table.identifyValidRows(variableTable,'TLS'); % some paths missing TLS
indApproach = find(opto_rows & indEpoch);
indPre = cellfun(@(bcs) contains(bcs,'Pre'),variableTable.BathConditionString(indApproach));
indPost = cellfun(@(bcs) contains(bcs,'Post'),variableTable.BathConditionString(indApproach));
variableTable.ApproachName = cell(height(variableTable),1);
variableTable.ApproachName(indApproach(indPre)) = {'EMPTY:Approach: Before optogenetic tetanus'};
variableTable.ApproachName(indApproach(indPost)) = {'EMPTY:Approach: After optogenetic tetanus'};

% Get stimulus approach docs
sd.table2approachDocs(variableTable,'ApproachName',...
    'NonNaNVariableNames','sessionInd', ...
    'Overwrite',options.Overwrite);

%% Step 6: CELL TYPES. Add openMinds celltypes and probe location documents.

% Get subjects
query = ndi.query('','isa','subject');
subjects = sessionArray{1}.database_search(query);
subjectID = cellfun(@(s) s.id, subjects, 'UniformOutput', false);
subjectLocalID = cellfun(@(s) s.document_properties.subject.local_identifier, subjects, 'UniformOutput', false); 

% Get patch-Vm and patch-I probes
query = ndi.query('element.type','contains_string','patch');
probes = sessionArray{1}.database_search(query);
subjectID_probes = cellfun(@(p) p.dependency_value('subject_id'),probes,'UniformOutput',false);

% Intialize cell arrays to hold docs
cellTypeDocs = cell(numel(subjects),1);
probeLocationDocs = cell(numel(subjects),1);
for i = 1:numel(probes)

    % Create openMinds cell type doc
    subjectInd = strcmpi(subjectID,subjectID_probes{i});
    variableTableInd = strcmpi(variableTable.SubjectString,subjectLocalID{subjectInd});
    typeString = variableTable.CellType{variableTableInd};
    if contains(typeString,'Type') % skip if type not specified
        [ontologyID,name,~,description,~] = ndi.ontology.lookup(['EMPTY:',typeString,' BNST neuron']);
        celltype = openminds.controlledterms.CellType('name',name,...
                'preferredOntologyIdentifier',ontologyID,'description',description);
        cellTypeDocs(i) = ndi.database.fun.openMINDSobj2ndi_document(celltype,...
            sessionArray{1}.id,'element',probes{i}.id);
    else
        cellTypeDocs{i} = 'remove';
    end

    % Create probe location doc
    probe_location = struct('ontology_name','UBERON:0001880',...
        'name','bed nucleus of stria terminalis (BNST)');
    probeLocationDocs{i} = ndi.document('probe_location',...
        'probe_location', probe_location) + sessionArray{1}.newdocument();
    probeLocationDocs{i} = probeLocationDocs{i}.set_dependency_value(...
        'probe_id', probes{i}.id);
end

% Remove cellTypeDoc indices with no document
cellTypeDocs(strcmpi(cellTypeDocs,'remove')) = [];

% Add documents to database
sessionArray{1}.database_add(cellTypeDocs);
sessionArray{1}.database_add(probeLocationDocs);

%% Step 7: VIRUSES AND TREATMENTS. Add virus injection and optogenetic location treatment documents.

% Indices of optogenetic subjects
subjectLocalID_opto = unique(variableTable.SubjectString(opto_rows));
[~,subjectInd_opto] = intersect(subjectLocalID,subjectLocalID_opto);

% Location key
anatomy = containers.Map({'PVN','SCN','SON'},...
    {'UBERON:0001930','UBERON:0002034','UBERON:0001929'});

% Intialize cell array to hold docs
treatmentDocs = cell(numel(subDocStruct),1);

for i = 1:numel(subjectInd_opto)

    % Get subject id
    subject_id = subjectID{subjectInd_opto(i)};

    % Get indices of variableTable matching that subject
    variableTableInd = ndi.fun.table.identifyMatchingRows(variableTable,'SubjectString',...
        subjectLocalID{subjectInd_opto(i)});

    % Get optogenetic location
    optoLocation = unique(variableTable.ProbeLocationString(variableTableInd));

    % Create treatment document
    ontologyID = ndi.ontology.lookup('EMPTY:Optogenetic Tetanus Stimulation Target Location');
    treatment = struct('ontologyName',ontologyID,...
        'name','Optogenetic Tetanus Stimulation Target Location',...
        'numeric_value',[],...
        'string_value',anatomy(optoLocation{:}));
    treatmentDocs{i} = ndi.document('treatment',...
        'treatment', treatment) + sessionArray{1}.newdocument();
    treatmentDocs{i} = treatmentDocs{i}.set_dependency_value(...
        'subject_id', subject_id);
end

% Add documents to database
sessionArray{1}.database_add(treatmentDocs);

%% Step 8: EPM DATA TABLE. Build data table for Elevated Plus Maze data.

% Get combined EPM data table
filename_EPM = 'EPM_OTR-cre+_Saline vs CNO_DREADDs-Gi_2 Groups_final-5.23.25.xlsx';
filename_EPM = fullfile(dataPath,'Behavioral Data','EPM',filename_EPM);
[~,sheetnames_EPM] = xlsfinfo(filename_EPM);
warning('off', 'MATLAB:table:ModifiedAndSavedVarnames');
for i = 1:numel(sheetnames_EPM)

    % Get data table and variable names
    sheetTable = readtable(filename_EPM,'Sheet',sheetnames_EPM{i},...
        'VariableNamingRule','modify');

    % Remove rows where Animal value is NaN
    sheetTable = sheetTable(ndi.fun.table.identifyValidRows(sheetTable,'Animal'),:);

    % Remove unused columns
    varNames = sheetTable.Properties.VariableNames;
    ind = contains(varNames,'Var');
    sheetTable(:,ind) = [];
    sheetTable.Test(isnan(sheetTable.Test)) = 0; % remove NaN for proper table join

    % Edit varname that does not contain sheetname
    sheetVar = replace(sheetnames_EPM{i},' ','');
    varNames = sheetTable.Properties.VariableNames;
    ind = contains(varNames,'300S');
    sheetTable.Properties.VariableNames{ind} = replace(varNames{ind},'x',sheetVar);
   
    % Join data tables
    if i == 1
        dataTable_EPM = sheetTable;
    else
        dataTable_EPM = outerjoin(dataTable_EPM,sheetTable,'Keys',{'Animal','Test','Treatment'},...
            'MergeKeys',true);
    end
end

% Replace NaNs for undefined test numbers
dataTable_EPM.Test(dataTable_EPM.Test == 0) = NaN;

% Add test duration variable
dataTable_EPM.Test_Duration(:) = 300; % seconds

% Add experiment id
dataTable_EPM.Experiment_ID(:) = 1;
dataTable_EPM.Experiment_ID(dataTable_EPM.Animal >= 300) = 2;

% Exclude animals not expressing mCherry
dataTable_EPM.Exclude(:) = false;
dataTable_EPM.Exclude(dataTable_EPM.Animal == 239 | dataTable_EPM.Animal == 258) = true;

%% Step 9: FPS DATA TABLE. Build data table for Fear-Potentiated Startle data.

% Get combined FPS data table
filename_FPS = 'FPS_OTR-Cre+_Saline vs CNO_DREADDs-Gi_Experiment 1-final.xlsx';
filename_FPS = fullfile(dataPath,'Behavioral Data','FPS',filename_FPS);
sheetnames_FPS = {'Pre-test 1','Pre-test 2','Shock Reactivity','Cue test 1',...
    'Context 1','Cue test 2','Context 2','Cue test 3'};

dataTable_FPS = cell(size(sheetnames_FPS));
for i = 1:numel(sheetnames_FPS)

    % Get data table and variable names
    sheetTable = readtable(filename_FPS,'Sheet',sheetnames_FPS{i},...
        'VariableNamingRule','modify');

    % Remove rows where SubjectID value is ''
    sheetTable = sheetTable(ndi.fun.table.identifyValidRows(sheetTable,'Trial_Num'),:);

    % Edit varname that does not contain sheetname
    sheetTable.Sheet_Name = repmat(sheetnames_FPS(i),height(sheetTable),1);
   
    % Store sheet table
    dataTable_FPS{i} = sheetTable;
end

% Join sheet tables
dataTable_FPS = ndi.fun.table.vstack(dataTable_FPS);

% Convert Subject_ID to double
dataTable_FPS.Subject_ID = cellfun(@(s) str2double(s),dataTable_FPS.Subject_ID);

% Add group identifiers and recording date
dataTable_FPS.Group_ID = cellfun(@(s) str2double(s(6)),dataTable_FPS.Session_ID);

% Remove redundant (or unused columns)
dataTable_FPS(:,{'Trial_List_Block','Chamber_ID','Session_ID','Param',...
    'TimeStampPT'}) = [];

%% Step 10: SUBJECTS. Build subject documents.

% Create subject table
subjectTable_behavior = dataTable_EPM(:,'Animal');
subjectTable_behavior{:,'SessionRef'} = {'Dabrowska_Behavior'};
subjectTable_behavior{:,'SessionPath'} = {'Dabrowska'};
subjectTable_behavior{:,'SpeciesOntologyID'} = {'NCBITaxon:10116'}; % Rattus norvegicus
subjectTable_behavior{:,'BiologicalSex'} = {'male'};
subjectTable_behavior{:,'IsWildType'} = NaN;
subjectTable_behavior{:,'IsOTRCre'} = {'OTRCre'};
subjectTable_behavior{:,'IsCRFCre'} = NaN;
subjectTable_behavior{:,'IsAVPCre'} = NaN;
subjectTable_behavior{:,'sessionID'} = sessionArray{1}.identifier;
subjectTable_behavior{:,'RecordingDate'} = 'Aug 19 2022';
subjectTable_behavior{:,'SubjectPostfix'} = arrayfun(@(si) ...
    ['_',num2str(si),'@dabrowska-lab.rosalindfranklin.edu'],...
    subjectTable_behavior.Animal,'UniformOutput',false);

% Employ the subjectMaker
[subjectInfo_behavior,subjectTable_behavior.SubjectString] = ...
    subM.getSubjectInfoFromTable(subjectTable_behavior,...
    @ndi.setup.conv.dabrowska.createSubjectInformation);
subDocStruct = subM.makeSubjectDocuments(subjectInfo_behavior);
subM.addSubjectsToSessions(sessionArray, subDocStruct.documents);

% Add subject strings to data tables
dataTable_EPM = join(dataTable_EPM,subjectTable_behavior(:,{'Animal','SubjectString'}),'Keys','Animal');
dataTable_FPS = join(dataTable_FPS,subjectTable_behavior(:,{'Animal','SubjectString'}),...
    'LeftKeys','Subject_ID','RightKeys','Animal');

%% Step 11: ONTOLOGYTABLEROW. Build ontologyTableRow documents.

% Check dictionary/ontology for new variables

% Initialize tableDocMaker
tdm = ndi.setup.NDIMaker.tableDocMaker(sessionArray{1},'dabrowska');

% Create EPM docs
tdm.table2ontologyTableRowDocs(dataTable_EPM,{'SubjectString','Treatment'},...
    'Overwrite',options.Overwrite);

% Create FPS docs
tdm.table2ontologyTableRowDocs(dataTable_FPS,...
    {'SubjectString','Trial_Num','Sheet_Name'},'Overwrite',options.Overwrite);
