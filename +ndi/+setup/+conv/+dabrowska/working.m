

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

% Get variable table (electrophysiology)
jsonPath = fullfile(myDir,'tools/NDI-matlab/+ndi/+setup/+conv/+dabrowska/dabrowska_fileManifest_ephys.json');
j = jsondecode(fileread(jsonPath));
variableTable_ephys = ndi.setup.conv.datalocation.processFileManifest(fileList,j);

% Get variable table (optogenetics)
jsonPath = fullfile(myDir,'tools/NDI-matlab/+ndi/+setup/+conv/+dabrowska/dabrowska_fileManifest_opto.json');
j = jsondecode(fileread(jsonPath));
variableTable_opto = ndi.setup.conv.datalocation.processFileManifest(fileList,j);

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
sliceLabel = variableTable.sliceLabel(epochInd);
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
[sessionArray,variableTable.sessionInd] = S.sessionIndices;

% Add DAQ system
labName = 'dabrowskalab';
S.addDaqSystem(labName,'Overwrite',true)

%% Stimulus Bath

sb = ndi.setup.NDIMaker.stimulusBathMaker(sessionArray{1},'dabrowska',...
    'GetProbes',true);

% Get mixture dictionary
jsonPath = fullfile(myDir,'tools/NDI-matlab/+ndi/+setup/+conv/+dabrowska/dabrowksa_mixtures_dictionary.json');
mixture_dictionary = jsondecode(fileread(jsonPath));

%% Get stimulus bath docs
stimulus_bath_docs = sb.table2bathDocs(variableTable,...
    'bath','BathConditionString',...
    'MixtureDictionary',mixture_dictionary,...
    'NonNaNVariableNames','sessionInd', ...
    'MixtureDelimeter','+',...
    'Overwrite',false);