function doImport(dataParentDir)

arguments
    dataParentDir (1,:) char {mustBeFolder}
end

dataPath = fullfile(dataParentDir,'Dabrowska');

badFolder = fullfile(myPath,'Electrophysiology Data - Wild-type/TGOT_IV_Curves_Type III_BNST_neurons/Apr 26  2022');
if isfolder(badFolder)
    movefile(badFolder,replace(badFolder,'  ',' '));
end

%% Step 1: VARIABLE TABLE. Get the file manifest and build a table,
%%         with one row per data file

[dirList,isDir] = vlt.file.manifest(dataPath);
fileList = dirList(~isDir);
include = ~contains(fileList,'/._') & ~startsWith(fileList,'._') & ...
    ~contains(fileList,'.DS_Store');
fileList = fileList(include);

% Get variable table
jsonPath = fullfile(userpath,'tools/NDI-matlab/+ndi/+setup/+conv/+dabrowska/dabrowskaDataLocation.json');
j = jsondecode(fileread(jsonPath));
variableTable = ndi.setup.conv.datalocation.processFileManifest(fileList,j);
variableTable{:,'SessionRef'} = {'Dabrowska'};
variableTable{:,'SessionPath'} = {'Dabrowska'};
variableTable{:,'SpeciesOntologyID'} = {'NCBITaxon:10116'}; % Rattus norvegicus
variableTable{:,'SubjectPostfix'} = {'@dabrowska-lab.rosalindfranklin.edu'};

%% Step 2: SESSIONS. Now that we have the file manifest, build sessions
%%
%%   Employ the sessionMaker

mySessionPath = dataParentDir;
SM = ndi.setup.NDIMaker.sessionMaker(mySessionPath,variableTable,...
    'NonNaNVariableNames','IsExpMatFile','Overwrite',true);
[sessionArray,variableTable.sessionInd] = SM.sessionIndices;

%% Add DAQ system
labName = 'dabrowskalab';
SM.addDaqSystem(labName,'Overwrite',true)

%% Step 3: SUBJECTS
%%
%% 

%% Create subject strings
for i = 1:height(variableTable)
    if isnan(variableTable.IsExpMatFile{i})
        variableTable.SubjectString{i} = '';
    else
        variableTable.SubjectString{i} = ndi.setup.conv.dabrowska.createSubjectInformation(variableTable(i,:));
    end
end

%% Step 4: PROBETABLE. Create a table that will help us build epochprobemaps.
%%
%%

% Create probeTable
name = {'bath';'Vm';'I'}; % the probes we have here
reference = {1;1;1};
type = {'stimulator';'patch-Vm';'patch-I'}; % the types
deviceString = {'dabrowska_mat:ai1';'dabrowska_mat:ai1';'dabrowska_mat:ao1'};
probeTable = table(name,reference,type,deviceString);

% Create probePostfix
epochInd = ~isnan(variableTable.sessionInd);
recordingDates = datetime(variableTable.RecordingDate(epochInd),...
    'InputFormat','MMM dd yyyy');
recordingDates = cellstr(char(recordingDates,'yyMMdd'));
sliceLabel = variableTable.sliceLabel(epochInd);
sliceLabel(strcmp(sliceLabel,{''})) = {'a'};
variableTable{epochInd,'ProbePostfix'} = cellfun(@(rd,sl) ['_',rd,'_',sl],...
    recordingDates,sliceLabel,'UniformOutput',false);

% Create epoch probe maps
ndi.setup.NDIMaker.epochProbeMapMaker(dataParentDir,variableTable,probeTable,...
    'Overwrite',true,...
    'NonNaNVariableNames','IsExpMatFile',...
    'ProbePostfix','ProbePostfix');

%% Step 5: STIMULUS BATH DOCS. Build the stimulus_bath documents
%%

sb = ndi.setup.NDIMaker.stimulusBathMaker(sessionArray{1},'dabrowska',...
    'GetProbes',true);

% Get mixture dictionary
jsonPath = fullfile(ndi.common.PathConstants.RootFolder,'+ndi','+setup','+conv',...
    '+dabrowska','dabrowksa_mixtures_dictionary.json');
mixture_dictionary = jsondecode(fileread(jsonPath));

% Get stimulus bath docs
stimulus_bath_docs = sb.table2bathDocs(variableTable,...
    'bath','BathConditionString',...
    'MixtureDictionary',mixture_dictionary,...
    'NonNaNVariableNames','sessionInd', ...
    'MixtureDelimeter','+',...
    'Overwrite',false);



