function sessionArray = doSayaImport(dataDir)

arguments
    dataDir (1,:) char {mustBeFolder}
end

sessionPath = fullfile(dataDir);
sessionPathNDI = fullfile(sessionPath,'.ndi');

if isfolder(sessionPathNDI)
    S = ndi.session.dir(sessionPath);
    disp(['Session exists, exiting'])
    return;
else
    S = ndi.setup.lab('sjbirrenlab','saya',sessionPath);
end

variableTable = readtable(fullfile(dataDir,"total_dataset_updated FINAL.xlsx"));

for i=1:height(T),
 [par,fname,ext]=fileparts(variableTable.filename{i});
 if isempty(ext),
    variableTable.filename{i} = [variableTable.filename{i} '.abf'];
 end;
end;

variableTable.sessionID = repmat({S.id()}, height(variableTable), 1)

subM = ndi.setup.NDIMaker.subjectMaker();

[subjectInfo,allSubjectNamesFromTable] = subM.getSubjectInfoFromTable(variableTable, @ndi.setup.conv.birren.createSubjectInformation);

variableTable.SubjectString = allSubjectNamesFromTable;
variableTable.Properties.RowNames = cellfun(@(x,y) cat(2,x,filesep,y), variableTable.folderPath, variableTable.filename, 'UniformOutput',false);


%% Step 4: EPOCHPROBEMAPS. Build epochprobemaps.

% Create probeTable
name = {'bath';'Vm';};
reference = {1;1};
type = {'stimulator';'patch-Vm'};
deviceString = {'birren_abf:ai1';'birren_abf:ai1'};
probeTable = table(name,reference,type,deviceString);

% Create epoch probe maps
ndi.setup.NDIMaker.epochProbeMapMaker(dataDir,variableTable,probeTable,...
    'Overwrite',options.Overwrite,...
    'NonNaNVariableNames','folderPath');


