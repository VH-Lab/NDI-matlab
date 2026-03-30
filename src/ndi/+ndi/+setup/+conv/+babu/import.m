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
    rowNums = find(strcmp(csvTable.TableFileName,csvFiles{i}));
    for j = 1:numel(rowNums)
        rowNum = rowNums(j);
        Value = dataTable.(csvTable.ColumnName{rowNum});
        if iscell(Value), Value = str2double(Value); end
        Value(isnan(Value)) = [];
        subjectTable{rowNum} = table(Value);
        subjectTable{rowNum}{:,'StrainName'} = csvTable.StrainName(rowNum);
        subjectTable{rowNum}{:,'Figure'} = csvTable.Figure(rowNum);
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

%% Create subject groups for each condition and figure
subject_group_figure = cell(numel(csvFiles),1);
subject_group_condition = cell(height(csvTable),1);
for i = 1:numel(csvFiles)
    rowNums = find(strcmp(csvTable.TableFileName,csvFiles{i}));
    for j = 1:numel(rowNums)
        subject_group_condition = ndi.document('subject_group') + session.newdocument();

    end

    subject_group_figure = ndi.document('subject_group') + session.newdocument();
end

            for k = 1:numel(ind)
                subject_group_doc = subject_group_doc.add_dependency_value_n(...
                    'subject_id',wormTable.subject_id{ind(k)});
            end
            session.database_add(subject_group_doc);

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