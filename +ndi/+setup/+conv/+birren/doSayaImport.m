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

variableTable = readtable(fullfile(dataDir,"total_dataset.xlsx"));

variableTable.sessionID = repmat({S.id()}, height(variableTable), 1)

[subjectInfo,allSubjectNamesFromTable] = subM.getSubjectInfoFromTable(variableTable, @ndi.setup.conv.birren.createSubjectInformation);

variableTable.SubjectString = allSubjectNamesFromTable;
variableTable.Properties.RowNames = variableTable.filename;


%% Step 4: EPOCHPROBEMAPS. Build epochprobemaps.

% Create probeTable
name = {'bath';'Vm';};
reference = {1;1};
type = {'stimulator';'patch-Vm'};
deviceString = {'birren_abf:ai1';'birren_abf:ai1'};
probeTable = table(name,reference,type,deviceString);

% Create probePostfix
indEpoch = ndi.fun.table.identifyValidRows(variableTable,'IsExpMatFile');
recordingDates = datetime(variableTable.RecordingDate(indEpoch),...
    'InputFormat','MMM dd yyyy');
recordingDates = cellstr(char(recordingDates,'yyMMdd'));
sliceLabel = variableTable.SliceLabel(indEpoch);
sliceLabel(strcmp(sliceLabel,{''})) = {'a'};
variableTable.ProbePostfix = cell(height(variableTable),1);
variableTable{indEpoch,'ProbePostfix'} = cellfun(@(rd,celltype,opto,sl) ...
    ['_',rd,'_BNST',celltype(6:end),opto,'_',sl],...
    recordingDates,variableTable.CellType(indEpoch),...
    variableTable.OptoPostfix(indEpoch),sliceLabel,'UniformOutput',false);

% Create epoch probe maps
ndi.setup.NDIMaker.epochProbeMapMaker(dataParentDir,variableTable,probeTable,...
    'Overwrite',options.Overwrite,...
    'NonNaNVariableNames','IsExpMatFile',...
    'ProbePostfix','ProbePostfix');