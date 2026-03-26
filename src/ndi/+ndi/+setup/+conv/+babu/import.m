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
    TableFileName = repmat(csvFiles(i),numel(ColumnName),1);
    csvTable{i} = table(TableFileName,ColumnName);
end
csvTable = ndi.fun.table.vstack(csvTable);

% Extract manifest metadata
textParser = which(fullfile('+ndi','+setup','+conv',['+',labName],'textParser.json'));
csvTable = [csvTable,ndi.fun.parseText(table2cell(csvTable),textParser)];
videoTable = [cell2table(aviFiles,'VariableNames',{'VideoFileName'}),...
    ndi.fun.parseText(aviFiles,textParser)];

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

%% Step 3. SUBJECTS AND TABLES.



%%

% Create subjectMaker
% subjectMaker = ndi.setup.NDIMaker.subjectMaker();
% subjectCreator = eval(ndi.setup.conv.(labName).subjectInformationCreator);

% Create tableDocMaker
% tableDocMaker = ndi.setup.NDIMaker.tableDocMaker(session,labName);

% Each cell of a table refers to a subject, each column of a table can
% refer to a subject_group. Videos and images can be linked to the 
% subject_groups. Should treatments be linked to subjects or
% subject_groups?

% ontologyTableRow
for i = 1:numel(csvFiles)
    dataTable = readtable(csvFiles{i})
end
% subject | CI | 


%% Step 4.TABLES.

%% Step 5. IMAGES AND VIDEOS

% read 

% treatment: heat *should this be treatment_drug too?*
% treatment_drug: chemoattractant (IAA, hepatanone, diacetyl)
% behavioral measurement: chemotaxis index


% end