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
% ndi.fun.data.avi2mp4(dataPath,'Overwrite',options.OverwriteAVI2MP4);

% Get files by type
csvFiles = fileList(endsWith(fileList,'.csv'));
xlsxFiles = fileList(endsWith(fileList,'.xlsx'));
aviFiles = fileList(endsWith(fileList,'.avi'));
mp4Files = fileList(endsWith(fileList,'.mp4'));
imageFiles = fileList(endsWith(fileList,'.tif'));
plasmidFiles = fileList(endsWith(fileList,'.dna'));
otherFiles = setdiff(fileList,[csvFiles;xlsxFiles;aviFiles;mp4Files;...
    imageFiles;plasmidFiles]);

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

% Extract manifest metadata
textParser = which(fullfile('+ndi','+setup','+conv',['+',labName],'textParser.json'));
csvTable = [csvTable,ndi.fun.parseText(table2cell(csvTable),textParser)];
videoTable = [cell2table(aviFiles,'VariableNames',{'VideoFileName'}),...
    ndi.fun.parseText(aviFiles,textParser)];

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
    dataTable = readtable(csvFiles{i});
    csvRows = find(strcmp(csvTable.TableFileName,csvFiles{i}));
    for j = 1:numel(csvRows)
        rowNum = csvRows(j);
        Value = dataTable.(csvTable.ColumnName{rowNum});
        if iscell(Value), Value = str2double(Value); end
        Value(isnan(Value)) = [];
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
subject_group_figure = cell(numel(csvFiles),1);
subject_group_condition = cell(height(csvTable),1);
for i = 1:numel(csvFiles)
    
    % Create subject group for the figure
    figureName = unique(csvTable.TableFileName(csvRows));
    subject_group_figure{i} = ndi.document('subject_group') + session.newdocument();
    subjectRows = find(strcmp(subjectTable.FigureName,figureName));
    for k = 1:numel(subjectRows)
        subject_group_figure{i} = subject_group_figure{i}.add_dependency_value_n(...
            'subject_id',subjectTable.SubjectDocumentIdentifier{subjectRows(k)});
    end

    % Create subject_group for the column
    csvRows = find(strcmp(csvTable.TableFileName,csvFiles{i}));
    for j = 1:numel(csvRows)
        columnName = csvTable.ColumnName{csvRows(j)};
        subject_group_condition{csvRows(j)} = ndi.document('subject_group') + session.newdocument();
        subjectRows = find(strcmp(subjectTable.FigureName,figureName) & ...
            strcmp(subjectTable.ColumnName,columnName));
        for k = 1:numel(subjectRows)
            subject_group_condition{csvRows(j)} = subject_group_condition{csvRows(j)}.add_dependency_value_n(...
                'subject_id',subjectTable.SubjectDocumentIdentifier{subjectRows(k)});
        end
    end
end

%session.database_add(subject_group_condition);
%session.database_add(subject_group_figure);

%% Step 4. TREATMENTS.

% Create treatment creator and maker
treatmentCreator = ndi.setup.conv.(labName).TreatmentCreator();
treatmentMaker = ndi.setup.NDIMaker.treatmentMaker();

% Add chemoattractant info
indTrainIAA = 
subjectTable.TrainOdor = 

% Add heat timing info
indHeat = subjectTable.Heat | subjectTable.Trained;
indHeatIAA = strcmp(subjectTable.FigureName,'S2D');
indIAAHeat = strcmp(subjectTable.FigureName,'S2C');
subjectTable.HeatOnset(indHeat) = hours(-21);
subjectTable.HeatOnset(indHeatIAA) = hours(-22);
subjectTable.HeatOnset(indIAAHeat) = hours(-22) + minutes(12);
subjectTable.HeatInterval(indHeat) = minutes(12);
subjectTable.HeatInterval(indHeatIAA | indIAAHeat) = minutes(24);



treatmentDocs = cell(height(subjectTable,1);
for i = 1:height(subjectTable)
    csvRow = strcmp(csvTable.FigureName,subjectTable.FigureName{i}) & ...
        strcmp(csvTable.FigureName,subjectTable.ColumnName{i});

    % Heat treatment
    if csvTable.Heat(csvRow) || csvTable.Trained(csvRow)

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
end

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

req_cols = {'location_ontologyName', 'location_name', 'mixture_table', ...
                        'administration_onset_time', 'administration_offset_time', 'administration_duration'};
            ndi.validators.mustHaveRequiredColumns(tableRow, req_cols);
            drug_struct.location_ontologyName = char(tableRow.location_ontologyName);
            drug_struct.location_name = char(tableRow.location_name);
            drug_struct.mixture_table = char(tableRow.mixture_table);
            drug_struct.administration_onset_time = char(tableRow.administration_onset_time);
            drug_struct.administration_offset_time = char(tableRow.administration_offset_time);
            drug_struct.administration_duration = tableRow.administration_duration;
%% Step 3. GET DATA.

% Create tableDocMaker
tableDocMaker = ndi.setup.NDIMaker.tableDocMaker(session,labName);

%%

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

% treatment_donor
% donor: subject_group (or subject_id)
% recipient: subject_id
% onset_time:
% offset_time:
% donated entity: agar plate post-training

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
% - unpaired protocol
% - odor (IAA, diacetyl, heptanone, or diacetyl)
% - chemical application (Xyl/imazapyr/2M5M/SGCDC/all3/all4/Methanol)

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