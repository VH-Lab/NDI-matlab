function doImport(dataParentDir,options)

arguments
    dataParentDir (1,:) char {mustBeFolder}
    options.Overwrite (1,1) logical = false
end

%%
progressBar = ndi.gui.component.ProgressBarWindow('Import Dataset');

dataPath = fullfile(dataParentDir,'Dabrowska');

%% Deal with bad paths

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
variableTable{:,'SessionRef'} = {'Dabrowska'};
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

%% Step 3: SUBJECTS

subM = ndi.setup.NDIMaker.subjectMaker();
[subjectInfo,variableTable.SubjectString] = ...
    subM.getSubjectInfoFromTable(variableTable,...
    @ndi.setup.conv.dabrowska.createSubjectInformation);
% We have no need to delete any previously made subjects because we remade all the sessions
% but if we did we could use the subM.deleteSubjectDocs method
subM.deleteSubjectDocs(sessionArray,subjectInfo.subjectName);
subDocStruct = subM.makeSubjectDocuments(subjectInfo);
subM.addSubjectsToSessions(sessionArray, subDocStruct.documents);

%% Step 4: PROBETABLE. Create a table that will help us build epochprobemaps.

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

%% Step 5: STIMULUS DOCS. Build the stimulus documents

sd = ndi.setup.NDIMaker.stimulusDocMaker(sessionArray{1},'dabrowska',...
    'GetProbes',true);

% Get mixture dictionary
jsonPath = fullfile(ndi.common.PathConstants.RootFolder,'+ndi','+setup','+conv',...
    '+dabrowska','dabrowska_mixtures_dictionary.json');
mixture_dictionary = jsondecode(fileread(jsonPath));

% Get stimulus bath docs
stimulus_bath_docs = sd.table2bathDocs(variableTable,...
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
stimulus_approach_docs = sd.table2approachDocs(variableTable,'ApproachName',...
    'NonNaNVariableNames','sessionInd', ...
    'Overwrite',options.Overwrite);

%% Create EPM and FPS table docs

% Get session
S = ndi.session.dir(dataPath);

% Initialize tableDocMaker
tdm = ndi.setup.NDIMaker.tableDocMaker(S,'dabrowska');

%% Get combined EPM data table
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
    ind = contains(varNames,'Var') | contains(varNames,'Test');
    sheetTable(:,ind) = [];

    % Edit varname that does not contain sheetname
    sheetVar = replace(sheetnames_EPM{i},' ','');
    varNames = sheetTable.Properties.VariableNames;
    ind = contains(varNames,'300S');
    sheetTable.Properties.VariableNames{ind} = replace(varNames{ind},'x',sheetVar);
   
    % Join data tables
    if i == 1
        dataTable_EPM = sheetTable;
    else
        dataTable_EPM = outerjoin(dataTable_EPM,sheetTable,'Keys',{'Animal','Treatment'},...
            'MergeKeys',true);
    end
end

% Add unique subject identifiers with strain and virus information
dataTable_EPM.Animal = char(arrayfun(@(animal) ['sd_rat_OTRCre_',num2str(animal,'%.3i'),...
    '@dabrowska-lab.rosalindfranklin.edu'],dataTable_EPM.Animal,'UniformOutput',false));
dataTable_EPM.Treatment = char(dataTable_EPM.Treatment);
dataTable_EPM.Test_Duration(:) = 300;

docsEPM = tdm.table2ontologyTableRowDocs(dataTable_EPM,{'Animal','Treatment'},...
    'Overwrite',false);

%% Get combined FPS data table

filename_FPS = 'FPS_OTR-Cre+_Saline vs CNO_DREADDs-Gi_Experiment 1-final.xlsx';
filename_FPS = fullfile(dataPath,'Behavioral Data','FPS',filename_FPS);
% [~,sheetnames_FPS] = xlsfinfo(filename_FPS);
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

% Add unique subject and group identifiers
dataTable_FPS.Subject_ID = char(arrayfun(@(subject) ['sd_rat_OTRCre_',subject{1},...
    '@dabrowska-lab.rosalindfranklin.edu'],dataTable_FPS.Subject_ID,'UniformOutput',false));
dataTable_FPS.Group_ID = char(cellfun(@(sid) sid(6),dataTable_FPS.Session_ID));

% Convert cells to char arrays
dataTable_FPS.Trial_ID = char(dataTable_FPS.Trial_ID);
dataTable_FPS.Run_Time = char(dataTable_FPS.Run_Time);
dataTable_FPS.Sheet_Name = char(dataTable_FPS.Sheet_Name);

% Remove redundant (or unused columns)
dataTable_FPS(:,{'Trial_List_Block','Chamber_ID','Session_ID','Param',...
    'TimeStampPT'}) = [];

docsFPS = tdm.table2ontologyTableRowDocs(dataTable_FPS,...
    {'Subject_ID','Trial_Num','Sheet_Name'},'Overwrite',false);