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

% Initialize progress bar
progressBar = ndi.gui.component.ProgressBarWindow('Import Dataset');
progressBar.setTimeout(hours(1));

%% Step 1: FILES. Get data path and files.

labName = 'babu';
dataPath = fullfile(dataParentDir,labName);

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
[~, gitRoot] = system('git rev-parse --show-toplevel');
rBinPath = '/usr/local/bin/Rscript';
rScriptPath = fullfile(strtrim(gitRoot), 'src', 'ndi', '+ndi', '+fun', '+data', 'prism2csv.R');
if exist(rScriptPath, 'file')
    cmd = sprintf('"%s" --verbose "%s" "%s" "%s" "%s"', rBinPath, ...
        rScriptPath, dataPath, 'NULL',char(string(logical(options.OverwritePrism2CSV)).upper));
    [status, result] = system(cmd,"-echo");
end
ndi.fun.data.prism2csv(dataPath,'Overwrite',options.OverwritePrism2CSV);

% Convert .avi files to .mp4
ndi.fun.data.avi2mp4(dataPath,'Overwrite',options.OverwriteAVI2MP4);



% Re-export csvs
    
    


% Get files by type
tableFiles = fileList(endsWith(fileList,'.csv') | endsWith(fileList,'.xlsx'));
videoFiles = fileList(endsWith(fileList,'.mp4'));
imageFiles = fileList(endsWith(fileList,'.tif'));
plasmidFiles = fileList(endsWith(fileList,'.dna'));
otherFiles = setdiff(fileList,[tableFiles;videoFiles;imageFiles;plasmidFiles]);

% Get video metatdata
jsonPath = which(fullfile('+ndi','+setup','+conv',['+',labName],'fileManifest.json'));
j = jsondecode(fileread(jsonPath));
videoTable = ndi.setup.conv.datalocation.processFileManifest(videoFiles,j);
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
    sessions{2}.cache.clear;
end
session = sessions{1};

%% Step 3. SUBJECTMAKER AND TABLEDOCMAKER.

% Create subjectMaker
subjectMaker = ndi.setup.NDIMaker.subjectMaker();
subjectCreator = eval(ndi.setup.conv.(labName).subjectInformationCreator);

% Create tableDocMaker
tableDocMaker = ndi.setup.NDIMaker.tableDocMaker(session,labName);
tableDocMaker_ecoli = ndi.setup.NDIMaker.tableDocMaker(sessions{2},labName);

%% 

% treatment: heat *should this be treatment_drug too?*
% treatment_drug: chemoattractant (IAA, hepatanone, diacetyl)
% behavioral measurement: chemotaxis index



% end