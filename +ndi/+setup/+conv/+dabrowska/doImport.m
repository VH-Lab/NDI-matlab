 function sessionArray = doImport(dataParentDir,options)
% Section A: Import electrophysiology dataset
%   Step 1: VARIABLE TABLE. Get the file manifest and build a table, with one row per data file
%   Step 2: SESSIONS. Now that we have the file manifest, build sessions
%   Step 3: SUBJECTS. Build subject documents.
%   Step 4: EPOCHPROBEMAPS. Build epochprobemaps.
%   Step 5: STIMULUS DOCS. Build the stimulus bath and approach documents
%
% Section B: Import behavioral dataset
%   Step 6: EPM DATA TABLE. Build data table for Elevated Plus Maze data.
%   Step 7: FPS DATA TABLE. Build data table for Fear-Potentiated Startle data.
%   Step 8: SUBJECTS. Build subject documents.
%   Step 9: ONTOLOGYTABLEROW. Build ontologyTableRow documents.

% Input argument validation
arguments
    dataParentDir (1,:) char {mustBeFolder}
    options.Overwrite (1,1) logical = false
end

% Create progress bar
ndi.gui.component.ProgressBarWindow('Import Dataset');

% Get data path
dataPath = fullfile(dataParentDir,'Dabrowska');

% Deal with bad paths
badFolder = fullfile(dataPath,'Electrophysiology Data - Wild-type/TGOT_IV_Curves_Type III_BNST_neurons/Apr 26  2022');
if isfolder(badFolder)
    disp(['Removing extra space in known folder ' badFolder])
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

%% Step 1: VARIABLE TABLE. Get the file manifest and build a table, with one row per data file

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
indEpoch = ndi.util.identifyValidRows(variableTable_opto,'BathConditionString');
variableTable_opto.BathConditionString(indEpoch) = replace(variableTable_opto.BathConditionString(indEpoch),'TLS','Post');
OTAInd = find(ndi.util.identifyValidRows(variableTable_opto,'OTA') & indEpoch);
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

% Add additional metadata
variableTable{:,'SessionRef'} = {'Dabrowska_Electrophysiology'};
variableTable{:,'SessionPath'} = {'Dabrowska'};
variableTable{:,'SpeciesOntologyID'} = {'NCBITaxon:10116'}; % Rattus norvegicus
variableTable{:,'SubjectPostfix'} = {'@dabrowska-lab.rosalindfranklin.edu'};
variableTable{:,'BiologicalSex'} = {'male'};

%% Step 2: SESSIONS. Now that we have the file manifest, build sessions

% Employ the sessionMaker
mySessionPath = dataParentDir;
SM = ndi.setup.NDIMaker.sessionMaker(mySessionPath,variableTable,...
    'NonNaNVariableNames','IsExpMatFile','Overwrite',options.Overwrite);
[sessionArray,variableTable.sessionInd,variableTable.sessionID] = SM.sessionIndices;

% Add DAQ system
labName = 'dabrowskalab';
SM.addDaqSystem(labName,'Overwrite',options.Overwrite)

%% Step 3: SUBJECTS. Build subject documents.

subM = ndi.setup.NDIMaker.subjectMaker();
[subjectInfo_ephys,variableTable.SubjectString] = ...
    subM.getSubjectInfoFromTable(variableTable,...
    @ndi.setup.conv.dabrowska.createSubjectInformation);
% We have no need to delete any previously made subjects because we remade all the sessions
% but if we did we could use the subM.deleteSubjectDocs method
subM.deleteSubjectDocs(sessionArray,subjectInfo_ephys.subjectName);
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
indEpoch = ndi.util.identifyValidRows(variableTable,'IsExpMatFile');
recordingDates = datetime(variableTable.RecordingDate(indEpoch),...
    'InputFormat','MMM dd yyyy');
recordingDates = cellstr(char(recordingDates,'yyMMdd'));
sliceLabel = variableTable.SliceLabel(indEpoch);
sliceLabel(strcmp(sliceLabel,{''})) = {'a'};
variableTable.ProbePostfix = cell(height(variableTable),1);
variableTable{indEpoch,'ProbePostfix'} = cellfun(@(rd,sl) ['_',rd,'_',sl],...
    recordingDates,sliceLabel,'UniformOutput',false);

% Create epoch probe maps
ndi.setup.NDIMaker.epochProbeMapMaker(dataParentDir,variableTable,probeTable,...
    'Overwrite',options.Overwrite,...
    'NonNaNVariableNames','IsExpMatFile',...
    'ProbePostfix','ProbePostfix');

%% Step 5: STIMULUS DOCS. Build the stimulus bath and approach documents

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
indTLS = ndi.util.identifyValidRows(variableTable,'TLS');
indApproach = find(indTLS & indEpoch);
indPre = cellfun(@(bcs) contains(bcs,'Pre'),variableTable.BathConditionString(indApproach));
indPost = cellfun(@(bcs) contains(bcs,'Post'),variableTable.BathConditionString(indApproach));
variableTable.ApproachName = cell(height(variableTable),1);
variableTable.ApproachName(indApproach(indPre)) = {'Approach: Before optogenetic tetanus'};
variableTable.ApproachName(indApproach(indPost)) = {'Approach: After optogenetic tetanus'};

% Get stimulus approach docs
sd.table2approachDocs(variableTable,'ApproachName',...
    'NonNaNVariableNames','sessionInd', ...
    'Overwrite',options.Overwrite);

%% Step 6: EPM DATA TABLE. Build data table for Elevated Plus Maze data.

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
    sheetTable = sheetTable(ndi.util.identifyValidRows(sheetTable,'Animal'),:);

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

%% Step 7: FPS DATA TABLE. Build data table for Fear-Potentiated Startle data.

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
    sheetTable = sheetTable(ndi.util.identifyValidRows(sheetTable,'Trial_Num'),:);

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

%% Step 8: SUBJECTS. Build subject documents.

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
subM.deleteSubjectDocs(sessionArray,subjectInfo_behavior.subjectName);
subDocStruct = subM.makeSubjectDocuments(subjectInfo_behavior);
subM.addSubjectsToSessions(sessionArray, subDocStruct.documents);

% Add subject strings to data tables
dataTable_EPM = join(dataTable_EPM,subjectTable_behavior(:,{'Animal','SubjectString'}),'Keys','Animal');
dataTable_FPS = join(dataTable_FPS,subjectTable_behavior(:,{'Animal','SubjectString'}),...
    'LeftKeys','Subject_ID','RightKeys','Animal');

%% Step 9: ONTOLOGYTABLEROW. Build ontologyTableRow documents.

% Check dictionary/ontology for new variables

% Initialize tableDocMaker
tdm = ndi.setup.NDIMaker.tableDocMaker(sessionArray{1},'dabrowska');

% Create EPM docs
tdm.table2ontologyTableRowDocs(dataTable_EPM,{'SubjectString','Treatment'},...
    'Overwrite',options.Overwrite);

% Create FPS docs
tdm.table2ontologyTableRowDocs(dataTable_FPS,...
    {'SubjectString','Trial_Num','Sheet_Name'},'Overwrite',options.Overwrite);