

% steve's working doc

myPath = '/Users/vanhoosr/Library/CloudStorage/GoogleDrive-steve@walthamdatascience.com/Shared drives/Dabrowska';


[fileList,isDir] = vlt.file.manifest(myPath);
filefileList = fileList(~isDir);

incl = []; for i=1:numel(filefileList), if ~contains(filefileList{i},'/._'), incl(end+1) = i; end; end
filefileList = filefileList(incl);
incl = []; for i=1:numel(filefileList), if ~startsWith(filefileList{i},'._'), incl(end+1) = i; end; end
filefileList = filefileList(incl);

t = ndi.setup.conv.datalocation.processFileManifest(filefileList,j,'relativePathPrefix','Dabrowska/');

 % constants

t{:,"SpeciesOntologyID"} = "NCBITaxon:10116"; % Rattus norvegicus
t{:,"SubjectPostfix"} = "@dabrowska-lab.rosalindfranklin.edu";

 % how to assign strains?

 % how to assign species:

sp = openminds.controlledterms.Species;
sp.preferredOntologyIdentifier="NCBITaxon:10116";
sp.name = "Rattus norvegicus";

st_sd = openminds.core.research.Strain;
st_sd.geneticStrainType = "wildtype";
st_sd.species = sp;
st_sd.ontologyIdentifier = "RRID:RGD_70508";
st_sd.name = "SD"; 

st_wi = openminds.core.research.Strain;
st_wi.geneticStrainType = "wildtype";
st_wi.species = sp;
st_wi.ontologyIdentifier = "RRID:RGD_13508588";
st_wi.name = "WI"; 

st_trans = openminds.core.research.Strain;
st_trans.geneticStrainType = "knockin";
st_trans.species = sp;
st_trans.backgroundStrain = [st_sd st_wi ];

st_avpcre = st_trans;
st_avpcre.name = 'AVP-Cre';

st_crfcre = st_trans;
st_crfcre.name = 'CRF-Cre';

st_otrirescre = st_trans;
st_otrirescre.name = 'OTR-IRES-Cre';

  % hangers on

L1 = (cellfun(@(x) ~isequaln(x,NaN), t.IsExpMatFile)) & cellfun(@(x) isequaln(x,NaN), t.BathConditionString);


 % need to add table constant elements, join 
 % epochprobmap_daqsystem: dabrowska_intracell
 % probes: dabrowska_current: patch-I
 %    dabrowska_voltage: patch-V
 %    dabrowska_stimulator: stimulator

bath_background


What are the species?



What are the strains?


%% jess's working lines

% Set paths
myDir = '/Users/jhaley/Documents/MATLAB';
myPath = fullfile(myDir,'data','Dabrowska');

% Edit file path with an extra space
badFolder = fullfile(myPath,'Electrophysiology Data - Wild-type/TGOT_IV_Curves_Type III_BNST_neurons/Apr 26  2022');
try
    movefile(badFolder,replace(badFolder,'  ',' '))
catch ME
    warning('Bad path already fixed')
end

% Edit file path missing 0
badFolder = fullfile(myPath,'Electrophysiology Data _ Optogenetics/AVP_Cre_SON/SON/Pre & TLS/Type III/Mar 16 223');
try
    movefile(badFolder,replace(badFolder,'223','2023'))
catch ME
    warning('Bad path already fixed')
end

% Get files
[dirList,isDir] = vlt.file.manifest(myPath);
fileList = dirList(~isDir);
include = ~contains(fileList,'/._') & ~startsWith(fileList,'._') & ...
    ~contains(fileList,'.DS_Store'); 
fileList = fileList(include);

% Edit files that say 'Copy of'
for i = 1:numel(fileList)
    if contains(fileList{i},'Copy of')
        myFile = fullfile(myDir,'data',fileList{i});
        movefile(myFile,replace(myFile,'Copy of ',''));
        fileList{i} = replace(fileList{i},'Copy of ','');
    end
end

% Get variable table (electrophysiology)
jsonPath = fullfile(userpath,'tools/NDI-matlab/+ndi/+setup/+conv/+dabrowska/dabrowska_fileManifest_ephys.json');
j = jsondecode(fileread(jsonPath));
variableTable_ephys = ndi.setup.conv.datalocation.processFileManifest(fileList,j);

% Get variable table (optogenetics)
jsonPath = fullfile(userpath,'tools/NDI-matlab/+ndi/+setup/+conv/+dabrowska/dabrowska_fileManifest_opto.json');
j = jsondecode(fileread(jsonPath));
variableTable_opto = ndi.setup.conv.datalocation.processFileManifest(fileList,j);

% Deal with OTA and TLS
epochInd = cellfun(@(sr) ~any(isnan(sr)),variableTable_opto.BathConditionString);
variableTable_opto.BathConditionString(epochInd) = replace(variableTable_opto.BathConditionString(epochInd),'TLS','Post');
OTAInd = find(cellfun(@(sr) ~any(isnan(sr)),variableTable_opto.OTA) & epochInd);
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

%% Create subjects
for i = 1:height(variableTable)
    if isnan(variableTable.IsExpMatFile{i})
        variableTable.SubjectString{i} = '';
    else
        variableTable.SubjectString{i} = ndi.setup.conv.dabrowska.createSubjectInformation(variableTable(i,:));
    end
end

%% Create epoch probe maps

% Create probeTable
name = {'bath';'Vm';'I'};
reference = {1;1;1};
type = {'stimulator';'patch-Vm';'patch-I'};
deviceString = {'dabrowska_mat:ai1';'dabrowska_mat:ai1';'dabrowska_mat:ao1'};
probeTable = table(name,reference,type,deviceString);

% Create probePostfix
epochInd = cellfun(@(sr) ~any(isnan(sr)),variableTable.IsExpMatFile);
recordingDates = datetime(variableTable.RecordingDate(epochInd),...
    'InputFormat','MMM dd yyyy');
recordingDates = cellstr(char(recordingDates,'yyMMdd'));
sliceLabel = variableTable.SliceLabel(epochInd);
sliceLabel(strcmp(sliceLabel,{''})) = {'a'};
variableTable.ProbePostfix = cell(height(variableTable),1);
variableTable{epochInd,'ProbePostfix'} = cellfun(@(rd,sl) ['_',rd,'_',sl],...
    recordingDates,sliceLabel,'UniformOutput',false);

% Create epoch probe maps
myPath = fullfile(myDir,'data');
ndi.setup.NDIMaker.epochProbeMapMaker(myPath,variableTable,probeTable,...
    'Overwrite',true,...
    'NonNaNVariableNames','IsExpMatFile',...
    'ProbePostfix','ProbePostfix');

%% Create NDI sessions
S = ndi.setup.NDIMaker.sessionMaker(myPath,variableTable,...
    'NonNaNVariableNames','IsExpMatFile','Overwrite',true);
[sessionArray,variableTable.SessionInd] = S.sessionIndices;

% Add DAQ system
labName = 'dabrowskalab';
S.addDaqSystem(labName,'Overwrite',true)

%% Stimulus Bath

sb = ndi.setup.NDIMaker.stimulusBathMaker(sessionArray{1},'dabrowska',...
    'GetProbes',true);

% Get mixture dictionary
jsonPath = fullfile(myDir,'tools/NDI-matlab/+ndi/+setup/+conv/+dabrowska/dabrowksa_mixtures_dictionary.json');
mixture_dictionary = jsondecode(fileread(jsonPath));

%% Create stimulus bath docs
stimulus_bath_docs = sb.table2bathDocs(variableTable,...
    'bath','BathConditionString',...
    'MixtureDictionary',mixture_dictionary,...
    'NonNaNVariableNames','SessionInd', ...
    'MixtureDelimeter','+',...
    'Overwrite',false);

%% Create stimulus approach docs

%stimulus_approach_docs = ndi.setup.stimulus.vhlab.add_stimulus_approach(sessionArray{1},filename);

%% Create EPM and FPS table docs

myDir = '/Users/jhaley/Documents/MATLAB';
myPath = fullfile(myDir,'data','Dabrowska');

% Get session
S = ndi.session.dir(myPath);

% Initialize tableDocMaker
tdm = ndi.setup.NDIMaker.tableDocMaker(S,'dabrowska');

%% Get combined EPM data table
filename_EPM = 'EPM_OTR-cre+_Saline vs CNO_DREADDs-Gi_2 Groups_final-5.23.25.xlsx';
filename_EPM = fullfile(myPath,'Behavioral Data','EPM',filename_EPM);
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

% tdm.createOntologyTableRowDoc(dataTable(1,:),'Animal','Overwrite',false);
docsEPM = tdm.table2ontologyTableRowDocs(dataTable_EPM,'Animal','Overwrite',false);

%% Get combined FPS data table

filename_FPS = 'FPS_OTR-Cre+_Saline vs CNO_DREADDs-Gi_Experiment 1-final.xlsx';
filename_FPS = fullfile(myPath,'Behavioral Data','FPS',filename_FPS);
% [~,sheetnames_FPS] = xlsfinfo(filename_FPS);
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

%% Compiling a table of the file paths

exportTable = cell2table(variableTable.Properties.RowNames,'VariableNames',{'filePath'});
[filePath,fileName] = fileparts(exportTable.filePath);
exportTable{:,{'subjectName','cellID'}} = {''};

for i = 1:numel(fileName)
    probeMapFileName = [filePath{i},filesep,fileName{i},'.epochprobemap.txt'];
    try
        probeMap = readtable(probeMapFileName, 'Delimiter', '\t', 'PreserveVariableNames', true);
        exportTable.subjectName(i) = probeMap.subjectstring(1);
        exportTable.cellID(i) = {probeMap.name{1}(end)};
    end
end

[~,~,cellNum] = unique(exportTable(:,{'subjectName','cellID'}),'rows','stable');
cellNum = cellNum - 1; cellNum(cellNum == 0) = NaN;
exportTable.cellNum = cellNum;
[~,~,subjectNum] = unique(exportTable(:,{'subjectName'}),'rows','stable');
subjectNum = subjectNum - 1; subjectNum(subjectNum == 0) = NaN;
exportTable.subjectNum = subjectNum;
exportTable = movevars(exportTable,'filePath','After','cellNum');
exportTable = movevars(exportTable,{'subjectNum','cellNum'},'Before','subjectName');

exportPath = fullfile(userpath,'data','Dabrowska','subjectTable_250702.xls');
writetable(exportTable,exportPath);