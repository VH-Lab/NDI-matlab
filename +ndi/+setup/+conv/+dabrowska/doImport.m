function doImport(dataParentDir)

arguments
    dataParentDir (1,:) char {mustBeFolder}
end

dataPath = fullfile(dataParentDir,'Dabrowska');

badFolder = fullfile(dataPath,'Electrophysiology Data - Wild-type/TGOT_IV_Curves_Type III_BNST_neurons/Apr 26  2022');
if isfolder(badFolder)
    disp(['Removing extra space in known folder ' badFolder])
    movefile(badFolder,replace(badFolder,'  ',' '));
end

%% Step 1: VARIABLE TABLE. Get the file manifest and build a table,
%%         with one row per data file

[dirList,isDir] = vlt.file.manifest(dataPath);
fileList = dirList(~isDir);
include = ~contains(fileList,'/._') & ~startsWith(fileList,'._') & ...
    ~contains(fileList,'.DS_Store') & ~endsWith(fileList,'epochprobemap.txt') & ~endsWith(fileList,'.epochid.ndi');
fileList = fileList(include);

% Get variable table
jsonPath = fullfile(userpath,'tools/NDI-matlab/+ndi/+setup/+conv/+dabrowska/dabrowska_fileManifest_ephys.json');
j = jsondecode(fileread(jsonPath));
variableTable = ndi.setup.conv.datalocation.processFileManifest(fileList,j);
variableTable{:,'SessionRef'} = {'Dabrowska'};
variableTable{:,'SessionPath'} = {'Dabrowska'};
variableTable{:,'SpeciesOntologyID'} = {'NCBITaxon:10116'}; % Rattus norvegicus
variableTable{:,'SubjectPostfix'} = {'@dabrowska-lab.rosalindfranklin.edu'};
variableTable{:,'BiologicalSex'} = {'male'};

%% Step 2: SESSIONS. Now that we have the file manifest, build sessions
%%
%%   Employ the sessionMaker

mySessionPath = dataParentDir;
SM = ndi.setup.NDIMaker.sessionMaker(mySessionPath,variableTable,...
    'NonNaNVariableNames','IsExpMatFile','Overwrite',true);
[sessionArray,variableTable.sessionInd,variableTable.sessionID] = SM.sessionIndices;

%% Add DAQ system
labName = 'dabrowskalab';
SM.addDaqSystem(labName,'Overwrite',true)

%% Step 3: SUBJECTS
%%
%% 
subM = ndi.setup.NDIMaker.subjectMaker();
[subjectInfo,variableTable.SubjectString] = subM.getSubjectInfoFromTable(variableTable,@ndi.setup.conv.dabrowska.createSubjectInformation);
% We have no need to delete any previously made subjects because we remade all the sessions
% but if we did we could use the subM.deleteSubjectDocs method
subDocStruct = subM.makeSubjectDocuments(subjectInfo);
subM.addSubjectsToSessions(sessionArray, subDocStruct.documents);

%% Step 4: PROBETABLE. Create a table that will help us build epochprobemaps.
%%
%%

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



