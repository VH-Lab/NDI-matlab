function createDaqReaderDialog()
    
    ndiDir = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
    % ndiDir = ndi.util.toolboxdir()
    
    variables = fullfile(ndiDir, '+ndi', '+daq', 'templates', ...
                             'daq_reader_variables.json');

    S = jsondecode(fileread(variables));

    readers = ndi.setup.daq.listDaqReaders();
    S.ReaderSuperClass = categorical(readers(1), readers);

    se = structeditor.StructEditorApp(S, ...
        'Title', 'Create New DAQ Reader', ...
        'Theme', structeditor.enum.Theme.NDI);

    se.OkButtonText = 'Create';
    % uiwait(se)
    % 
    % disp(se.Data)
end