% function [] = import(dataParentDir,options)

% Input argument validation
% arguments
%     dataParentDir (1,:) char {mustBeFolder} = fullfile(userpath,'data')
%     options.Overwrite (1,1) logical = true
% end

dataParentDir = fullfile(userpath,'data');
options.Overwrite = true;
options.OverwritePrism2CSV = false;
options.OverwriteAVI2MP4 = false; 

labName = 'babu';

% Initialize progress bar
progressBar = ndi.gui.component.ProgressBarWindow('Import Dataset');
progressBar.setTimeout(hours(1));

%% Step 1: FILES. Get data path and files.

% Get data path
dataPath = fullfile(dataParentDir,labName);
addpath(genpath(dataPath));

% Get files
fileList = vlt.file.manifest(dataPath);

% If overwriting, delete NDI docs
if options.Overwrite
    ndiFiles = fileList(endsWith(fileList,'.ndi'));
    for i = 1:numel(ndiFiles)
        rmdir(fullfile(dataParentDir,ndiFiles{i}),'s');
    end
end

% Convert .prism files to .csv
ndi.fun.data.prism2csv(dataPath,'Overwrite',options.OverwritePrism2CSV);

% Convert .avi files to .mp4
ndi.fun.data.avi2mp4(dataPath,'Overwrite',options.OverwriteAVI2MP4);

% Get files by type
csvFiles = fileList(endsWith(fileList,'.csv'));
xlsxFiles = fileList(endsWith(fileList,'.xlsx'));
aviFiles = fileList(endsWith(fileList,'.avi'));
mp4Files = fileList(endsWith(fileList,'.mp4'));
imageFiles = fileList(endsWith(fileList,'.tif'));
plasmidFiles = fileList(endsWith(fileList,'.dna'));
otherFiles = setdiff(fileList,[csvFiles;xlsxFiles;aviFiles;mp4Files;...
    imageFiles;plasmidFiles]);

% Ignore table
indRemove = contains(csvFiles,{'Figure_3A_Data_1','Figure_4E_Data_2'});
csvFiles(indRemove) = [];

%% Step 2: MATCH TABLES AND VIDEOS

% Get table names and columns
csvTable = cell(numel(csvFiles),1);
for i = 1:numel(csvFiles)
    opts = detectImportOptions(csvFiles{i});
    ColumnName = opts.VariableNames';
    if any(contains(ColumnName,'Var'))
        dataTable = readtable(csvFiles{i});
        indEmpty = all(cellfun(@(x) isequal(x,'NA'),table2cell(dataTable)),1);
        ColumnName(indEmpty) = [];
    end
    if isempty(ColumnName)
        csvTable{i} = table();
    else
        TableFileName = repmat(csvFiles(i),numel(ColumnName),1);
        csvTable{i} = table(TableFileName,ColumnName);
    end
end
csvTable = ndi.fun.table.vstack(csvTable);

% Add placeholder subjects for which no TrainedToNaive data is given
ind = cellfun(@(f) find(contains(csvTable.TableFileName,f),1),{'3D','3E','S2C','S2D','S3B'});
csvTable = [csvTable;csvTable(ind,:)];
csvTable{(end-numel(ind)+1):end,'ColumnName'} = {'TrainedToNaive'};

% Extract manifest metadata
textParser = which(fullfile('+ndi','+setup','+conv',['+',labName],'textParser.json'));
csvTable = [csvTable,ndi.fun.parseText(table2cell(csvTable),textParser)];
videoTable = [cell2table(aviFiles,'VariableNames',{'VideoFileName'}),...
    ndi.fun.parseText(aviFiles,textParser)];

% Rename figures
csvTable{contains(csvTable.TableFileName,'Figure_S3B'),'FigureName'} = {'S3C'};
csvTable{contains(csvTable.TableFileName,'Figure_S3C'),'FigureName'} = {'S3D'};
csvTable{contains(csvTable.TableFileName,'Figure_S3D'),'FigureName'} = {'S3B'};
videoTable{contains(videoTable.VideoFileName,'Figure S3C'),'FigureName'} = {'S3D'};
videoTable{contains(videoTable.VideoFileName,'Figure S3D'),'FigureName'} = {'S3B'};

% Check strains
strainNames = {'N2','PT1194','PT3602','TM5848',...
    'BAB9001','BAB9002','BAB9003','BAB9004','BAB9005'};
if any(sum(csvTable{:,strainNames},2) > 1)
    error('Subjects matching more than one strain.')
end

% Assign strain names to csv files
csvTable{:,'StrainName'} = {'N2'};
for i = 1:numel(strainNames)
    indStrain = csvTable{:,strainNames{i}};
    csvTable.StrainName(indStrain) = strainNames(i);
end

% Add figure part # (if applicable)
for i = 1:height(csvTable)
    if ~isempty(csvTable.FigurePart{i})
        csvTable{i,'FigureName'} = {[csvTable.FigureName{i},num2str(csvTable.FigurePart{i})]};
    end
end

% Assign chemoattractants to csv columns
trainOdorants = {'TrainIAA','TrainDiacetyl','TrainBenzaldehyde','TrainHeptanone'};
if any(sum(csvTable{:,trainOdorants},2) > 1)
    error('Subjects matching more than one training odor.')
end
testOdorants = {'TestIAA','TestDiacetyl','TestBenzaldehyde','TestHeptanone'};
ind3B = strcmp(csvTable.FigureName,'3B');
csvTable.TrainIAA(ind3B) = true; csvTable.TestIAA(ind3B) = false;
if any(sum(csvTable{:,testOdorants},2) > 1)
    error('Subjects matching more than one testing odor.')
end

% Assign chemoattractant names to csv files
csvTable{:,'TrainOdor'} = {''};
csvTable{csvTable.Trained,'TrainOdor'} = {'IAA'};
csvTable{:,'TestOdor'} = {'IAA'};
for i = 1:numel(trainOdorants)
    indOdor = csvTable{:,trainOdorants{i}};
    csvTable.TrainOdor(indOdor) = {replace(trainOdorants{i},'Train','')};
    indOdor = csvTable{:,testOdorants{i}};
    csvTable.TestOdor(indOdor) = {replace(testOdorants{i},'Test','')};
end

% Assign chemicals
trainChemicals = {'Xylidine','Methanol','SGCDC','x2M5M','Imazapyr'};
indChemical = csvTable{:,trainChemicals};
chemicalMixture = cellfun(@(i) strjoin(trainChemicals(i),','),num2cell(indChemical,2),'UniformOutput',false);
csvTable.TrainOdor(any(indChemical,2)) = chemicalMixture(any(indChemical,2));

% Manual corrections
ind = strcmp(csvTable.FigureName,'3A');
csvTable{ind,{'TrainOdor','TestOdor'}} = repmat({'IAA','Heptanone'},sum(ind),1);
ind = strcmp(csvTable.FigureName,'6J') & strcmp(csvTable.ColumnName,'Supp');
csvTable.TrainOdor(ind) = {'Xylidine'}; csvTable.XylidineDose(ind) = 80;
csvTable{csvTable.Naive,'TrainOdor'} = {''};
csvTable{csvTable.Heat,'TrainOdor'} = {''};

%% Step 2: SESSIONS. Build the session.

% Create sessionMaker
SessionRef = {[labName,'_',char(datetime('now'),'yyyy')]};
SessionPath = {labName};
sessionMaker = ndi.setup.NDIMaker.sessionMaker(dataParentDir,...
    table(SessionRef,SessionPath),'Overwrite',options.Overwrite);

% Get the session object
sessions = sessionMaker.sessionIndices;
if options.Overwrite
    sessions{1}.cache.clear;
end
session = sessions{1};

%% Step 3. SUBJECTS. Get data and create subjects.

% Get all subjects
subjectTable = cell(height(csvTable),1);
for i = 1:numel(csvFiles)
    csvRows = find(strcmp(csvTable.TableFileName,csvFiles{i}));
    dataTable = readtable(csvFiles{i});
    for j = 1:numel(csvRows)
        rowNum = csvRows(j);
        if ismember(csvTable.ColumnName{rowNum},dataTable.Properties.VariableNames)
            Value = dataTable.(csvTable.ColumnName{rowNum});
            if iscell(Value), Value = str2double(Value); end
            Value(isnan(Value)) = [];
        else
            Value = nan(1,1);
        end
        subjectTable{rowNum} = table(Value);
        subjectTable{rowNum}{:,'StrainName'} = csvTable.StrainName(rowNum);
        subjectTable{rowNum}{:,'FigureName'} = csvTable.FigureName(rowNum);
        subjectTable{rowNum}{:,'ColumnName'} = csvTable.ColumnName(rowNum);
        subjectTable{rowNum}{:,'N'} = (1:numel(Value))';
    end
end
subjectTable = ndi.fun.table.vstack(subjectTable);

% Create subjects
subjectMaker = ndi.setup.NDIMaker.subjectMaker();
subjectCreator = ndi.setup.conv.(labName).SubjectInformationCreator();
[~,subjectTable.SubjectLocalIdentifier,subjectTable.SubjectDocumentIdentifier] = subjectMaker.addSubjectsFromTable( ...
    session, subjectTable, subjectCreator);

% Add csv info to table
subjectTable = join(subjectTable,csvTable,'Keys',{'FigureName','ColumnName','StrainName'},...
    'KeepOneCopy',intersect(subjectTable.Properties.VariableNames,csvTable.Properties.VariableNames));

%% Create subject groups for each condition and figure

% Merge Figure 5A and 5B (matched)
ind = strcmp(subjectTable.FigureName,'5A') | strcmp(subjectTable.FigureName,'5B');
subjectTable{ind,'FigureName'} = {'5AB'};
ind = strcmp(csvTable.FigureName,'5A') | strcmp(csvTable.FigureName,'5B');
csvTable{ind,'FigureName'} = {'5AB'};

subject_group_figure = cell(numel(csvFiles),1);
subject_group_condition = cell(height(csvTable),1);
for i = 1:numel(csvFiles)
    
    % Create subject group for the figure
    csvRows = find(strcmp(csvTable.TableFileName,csvFiles{i}));
    figureName = unique(csvTable.FigureName(csvRows));
    subject_group_figure{i} = ndi.document('subject_group') + session.newdocument();
    subjectRows = find(strcmp(subjectTable.FigureName,figureName));
    for k = 1:numel(subjectRows)
        subject_group_figure{i} = subject_group_figure{i}.add_dependency_value_n(...
            'subject_id',subjectTable.SubjectDocumentIdentifier{subjectRows(k)});
    end
    subjectTable{subjectRows,'SubjectGroupIdentifier_Figure'} = {subject_group_figure{i}.id};

    % Create subject_group for the column
    for j = 1:numel(csvRows)
        columnName = csvTable.ColumnName{csvRows(j)};
        subject_group_condition{csvRows(j)} = ndi.document('subject_group') + session.newdocument();
        subjectRows = find(strcmp(subjectTable.FigureName,figureName) & ...
            strcmp(subjectTable.ColumnName,columnName));
        for k = 1:numel(subjectRows)
            subject_group_condition{csvRows(j)} = subject_group_condition{csvRows(j)}.add_dependency_value_n(...
                'subject_id',subjectTable.SubjectDocumentIdentifier{subjectRows(k)});
        end
        subjectTable{subjectRows,'SubjectGroupIdentifier_Column'} = {subject_group_condition{csvRows(j)}.id};
    end
end

session.database_add(subject_group_condition);
session.database_add(subject_group_figure);

%% Step 4. TREATMENTS.

% Add heat training timing info
indHeat = subjectTable.Heat | subjectTable.Trained;
indHeatIAA = strcmp(subjectTable.FigureName,'S2D');
indIAAHeat = strcmp(subjectTable.FigureName,'S2C');
subjectTable.HeatOnset(indHeat) = hours(-21);
subjectTable.HeatOnset(indHeatIAA) = hours(-22);
subjectTable.HeatOnset(indIAAHeat) = hours(-22) + minutes(12);
subjectTable{:,'TrainInterval'} = minutes(12);
subjectTable.TrainInterval(indHeatIAA | indIAAHeat) = minutes(24);

% Get times points of chemical training
indOdor = strcmp(subjectTable.TrainOdor,'IAA') | strcmp(subjectTable.TrainOdor,'Diacetyl') | ...
    strcmp(subjectTable.TrainOdor,'Heptanone') | strcmp(subjectTable.TrainOdor,'Benzaldehyde');
subjectTable.Odor = indOdor;
subjectTable.OdorOnset(indOdor) = hours(-21);
subjectTable.OdorOnset(indHeatIAA) = hours(-22) + minutes(12);
subjectTable.OdorOnset(indIAAHeat) = hours(-22);
subjectTable{:,'OdorDuration'} = minutes(2);
indChemical = contains(subjectTable.TrainOdor,'Xylidine') | contains(subjectTable.TrainOdor,'x2M5M') | ...
    contains(subjectTable.TrainOdor,'SGCDC') | contains(subjectTable.TrainOdor,'Imazapyr') | ...
    contains(subjectTable.TrainOdor,'Methanol');
subjectTable.Chemical = indChemical;
chemicalStart = -hours(20*ones(height(subjectTable),1));
indValue = indChemical & ~isnan(subjectTable.Hours);
chemicalStart(indValue) = -hours(subjectTable.Hours(indValue));
subjectTable.OdorOnset(indChemical) = chemicalStart(indChemical);
subjectTable.OdorDuration(indChemical) = -subjectTable.OdorOnset(indChemical);

% Get matched onset times
for i = 1:height(csvTable)
    ind = strcmp(subjectTable.FigureName,csvTable.FigureName{i});
    subjectTable.FoodOnset(ind) = min([subjectTable.OdorOnset(ind);subjectTable.HeatOnset(ind)]);
end

% Get transfer time for washes
indWash = subjectTable.Pick | subjectTable.M9;
subjectTable.TransferTime = nan(height(subjectTable),1);
subjectTable.TransferTime(indWash) = subjectTable.Hours(indWash);
subjectTable.TransferTime(indWash & contains(subjectTable.TableFileName,'immediate')) = 0;
subjectTable.TransferTime(indWash & isnan(subjectTable.TransferTime)) = 12;

% Get transfer donor ids
indTransfer = subjectTable.Transfer;
donorColumnName = cellfun(@(r,c) strjoin({r,c},'To'),subjectTable.TransferRecipient(indTransfer),subjectTable.TransferDonor(indTransfer),'UniformOutput',false);
donorColumnName(strcmp(donorColumnName,'TrainedToklp_6RescueNaive')) = {'klp_6RescueTrainedToNaive'};
donorColumnName(strcmp(donorColumnName,'NaiveToklp_6RescueTrained')) = {'klp_6RescueNaiveToTrained'};
donorFigureName = subjectTable.FigureName(indTransfer);
subjectTable{:,'donor_id'} = {''};
subjectTable.donor_id(indTransfer) = cellfun(@(c,f) unique(subjectTable.SubjectGroupIdentifier_Column(strcmpi(subjectTable.ColumnName,c) & strcmpi(subjectTable.FigureName,f))),...
    donorColumnName,donorFigureName,'UniformOutput',false);
subjectTable.TransferTime(indTransfer) = 20;

% Create treatment table
treatmentCreator = ndi.setup.conv.(labName).TreatmentCreator();
treatmentTable = treatmentCreator.create(subjectTable,session);

% Create treatment docs
treatmentMaker = ndi.setup.NDIMaker.treatmentMaker();
treatmentDocs = treatmentMaker.addTreatmentsFromTable(session,treatmentTable);
session.database_add(treatmentDocs);

%% Step 5. DATAPOINTS.

treatmentFile = which(fullfile('+ndi','+setup','+conv','+babu','treatments.json'));
treatments = jsondecode(fileread(treatmentFile));

dataTable = subjectTable(:,{'Value','SubjectDocumentIdentifier'});
dataTable.mixture_table = cellfun(@(o) ndi.database.fun.writetablechar(struct2table(treatments.([o,'_test']))),...
    subjectTable.TestOdor,'UniformOutput',false);
dataTable{:,'odorVolume'} = 1;
dataTable{:,'duration'} = 10;

% Create chemotaxis tables
indCI = ~subjectTable.FluorescenceIntensity & ~subjectTable.NumPuncta & ...
    ~subjectTable.Velocity & ~isnan(subjectTable.Value);
ciTable = renamevars(dataTable(indCI,:),'Value','CI');
speedTable = renamevars(dataTable(subjectTable.Velocity,:),'Value','speed');

% Create fluorescence tables
dataTable = removevars(dataTable,{'odorVolume','mixture_table','duration'});
dataTable{:,'neuron'} = 'IL2 neuron';
dataTable{:,'neuronID'} = 'WBbt:0005118';
fluorTable = renamevars(dataTable(subjectTable.FluorescenceIntensity,:),'Value','fluorescence');
punctaTable = renamevars(dataTable(subjectTable.NumPuncta,:),'Value','puncta');

% Create tableDocMaker
tableDocMaker = ndi.setup.NDIMaker.tableDocMaker(session,labName);

if options.Overwrite
    query = ndi.query('','isa','ontologyTableRow');
    docs = session.database_search(query);
    session.database_rm(docs);
end

% Make ontologyTableRow docs
ciDocs = tableDocMaker.table2ontologyTableRowDocs(ciTable,...
    'DependencyVariable','SubjectDocumentIdentifier',...
    'Overwrite',options.Overwrite);
speedDocs = tableDocMaker.table2ontologyTableRowDocs(speedTable,...
    'DependencyVariable','SubjectDocumentIdentifier',...
    'Overwrite',options.Overwrite);
fluorDocs = tableDocMaker.table2ontologyTableRowDocs(fluorTable,...
    'DependencyVariable','SubjectDocumentIdentifier',...
    'Overwrite',options.Overwrite);
punctaDocs = tableDocMaker.table2ontologyTableRowDocs(punctaTable,...
    'DependencyVariable','SubjectDocumentIdentifier',...
    'Overwrite',options.Overwrite);

%% Step 6. IMAGESTACKS AND GENERIC_FILES.

%%
% Each cell of a table refers to a subject, each column of a table can
% refer to a subject_group. Videos and images can be linked to the 
% subject_groups. Should treatments be linked to subjects or
% subject_groups?

% subject <- species, strain, bioSex, strainType, treatments
% ~100 subjects <- subject_group (plot)
% 20-30 subjects <- subject_group (condition) <- videos

% 5 x treatment_drug: 
% - mixture table: 37 C, odor
% - onset: datetime(-20 hours) convert to YYYY-MM-DDThh:mm:ssZ
% - offset: -19 hours - 58 minutes

% treatment_drug:
% - mixture table: heat-killed vs. live OP50
% - onset: days earlier
% - offset: 0 hours

% treatment_drug:
% - mixture table: chemicals

% ontologyTableRow:
% - chemotaxis index
% - chemoattractant name
% - chemoattractant id
% - chemotaxis assay duration
% - c. elegans velocity during chemotaxis assay

% subjects (plate 1) <- subject_group (condition 1)
% subjects (plate 2) <- subject_group (condition 2)
% at time t subjects (plate2) experienced the emissions of subjects (plate 1)
% emissions of subject_group (condition 1)

% treatment_transfer
% depends_on: subject_id (recipient)
% donor_id: subject_group
% timestamp:
% entity_name: agar plate medium
% entity_ontologyNode: MICRO:0000480
% method_name: M9 buffer wash
% method_ontologyNode: EMPTY:0000

% SUBJECT
% - species

% TRAINING
% plates contain OP50 (live or heat-killed)
% 5 x [2 minutes (37C and/or odor), 10 minutes 22C]
% maintain on training plate for 20 hours at 22C

% TRAINING (alternatives)
% - wash w/ M9
% - transfer to different plate
% - heat-killed food
% - unpaired protocol *
% - odor (IAA, diacetyl, heptanone, or diacetyl) *
% - chemical application (Xyl/imazapyr/2M5M/SGCDC/all3/all4/Methanol) *

% TESTING
% plates contain 1uL 1% IAA, diacetyl, heptanone, or diacetyl


% Figure 1B
% - naive, trained w/ heat, IAA, heat+IAA

% Figure 1D-F
% - naive, trained w/ heat, IAA, heat+IAA
% - animals transfered to new plate at 0, 6, or 12 hours after training

% Figure S1C
% - naive, trained w/ heat, IAA, heat+IAA
% - M9 wash 12 hours after training

% Figure 2B
% - naive, trained w/ heat+IAA, naive to trained, trained to naive
% - <30 mins after training, swap

% Figure 2C
% - same as 2B with heat-killed OP50

% Figure S2C
% naive, trained, naive to trained
% unpaired training 5 x [2 minutes (IAA), 10 minutes 22C, 2 minutes(37C)]

% Figure S2D
% naive, trained, naive to trained
% unpaired training 5 x [2 minutes (37C), 10 minutes 22C, 2 minutes(IAA)]

% Figure 3A-I
% naive, trained w/ heat+odor, naive to trained, trained to naive
% |   | trained | tested |
% | A | IAA | heptanone |
% | B | IAA | benzaldehyde |
% | C | IAA | diacetyl |
% | D | heptanone | heptanone |
% | E | heptanone | IAA |
% | F | benzaldehyde | benzaldehyde |
% | G | benzaldehyde | IAA |
% | H | diacetyl | diacetyl |
% | I | diacetyl | IAA |

% Figure 4A-C
% - naive, trained w/ heat, IAA, heat+IAA
% - daf-22, klp-6, cil-7

% Figure 4E
% - N2 naive, klp-6 naive, klp-6 trained to N2 trained w/ heat+IAA, N2
% trained to klp-6 trained w/ heat+IAA

% Figure 4F
% - naive, trained, naive to trained, trained to naive
% - klp-6 rescue

% Figure 5A-B


% Figure 5D-E
% - naive, trained w/ heat, IAA, heat+IAA
% - cil-7::mNG

% Figure S5


% Figure 6A-C
% - naive animals + (70/80 mM Xyl) + (imazapyr+2M5M+SGCDC)
% - tested on IAA 3.5, 6, or 20 hours after chemical application

% Figure S6B-C
% - naive animals + (imazapyr/2M5M/SGCDC/all3)
% - tested on IAA 3.5 or 6 hours after chemical application

% Figure 6D-F
% - same as 6A-C, tested on diacetyl

% Figure S6D-E
% - same as S6B-C, tested on diacetyl

% Figure 6G


% Figure 6H
% - naive animals + (methanol/80mM Xyl)
% - tested on IAA, heptanone, benzaldehyde 20 hours after chemical application

% Figure S6G




% testing (depend on subject) - on 1DOA
% - ontologyTableRow : chemotaxis index | chemoattractant id + quantity
% - ontologyTableRow : # of puncta
% - ontologyTableRow : fluorescence intensity

% subject_group (depend on subjects)

% videos (depend on subject_group)
% - imageStack
% - imageStack_parameters
% - ontology_label

% images

% plasmid maps

% LC_ms

%% Step 4.TABLES.

%% Step 5. IMAGES AND VIDEOS

% read 

% treatment: heat *should this be treatment_drug too?*
% treatment_drug: chemoattractant (IAA, hepatanone, diacetyl)
% behavioral measurement: chemotaxis index


% end