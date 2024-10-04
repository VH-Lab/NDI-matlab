classdef PathConstants
% PathConstants - A set of path constants referenced by the NDI toolbox
%
%   RootFolder              | The path of the NDI distribution on this machine.
%   CommonFolder            | The path to the package ndi_common
%   DocumentFolder          | The path of the NDI document definitions
%   DocumentSchemaFolder    | The path of the NDI document validation schema
%   ExampleDataFolder       | The path to the NDI example sessions
%   Preferences             | A path to a directory of preferences files
%   FileCacheFolder         | A path where files may be cached (not deleted every time)
%   TempFolder              | The path to a directory that may be used for temporary files
%   TestFolder              | A path to a safe place to run test code
%   CalcDoc                 | A cell array of paths to NDI calculator document definitions
%   CalcDocSchema           | A cell array of paths to NDI calculator document schemas

    properties (Constant)
        % RootFolder - The path of the NDI distribution on this machine.
        RootFolder = ndi.toolboxdir()

        % CommonFolder - The path to the package ndi_common
        CommonFolder = fullfile(ndi.common.PathConstants.RootFolder, 'ndi_common')

        % DocumentFolder - The path of the NDI document definitions
        DocumentFolder = fullfile(ndi.common.PathConstants.CommonFolder, 'database_documents')
        
        % DocumentSchemaFolder - The path of the NDI document validation schema
        DocumentSchemaFolder = fullfile(ndi.common.PathConstants.CommonFolder, 'schema_documents')
        
        % ExampleDataFolder - The path to the NDI example sessions
        ExampleDataFolder = fullfile(ndi.common.PathConstants.CommonFolder, 'example_sessions')
        
        % TempFolder - The path to a directory that may be used for temporary files
        TempFolder {mustBeWritable} = fullfile(tempdir, 'nditemp')
        
        % TestFolder - A path to a safe place to run test code
        TestFolder {mustBeWritable} = fullfile(tempdir, 'nditestcode') % Todo: Use fixtures and test classes
        
        % FileCacheFolder - A path where files may be cached (not deleted every time)
        FileCacheFolder {mustBeWritable} = fullfile(userpath, 'Documents', 'NDI', 'NDI-filecache')
        
        % LogFolder - A path to a directory for storing logs
        LogFolder = fullfile(userpath, 'Documents', 'NDI', 'Logs')
        
        % Preferences - A path to a directory of preferences files
        Preferences {mustBeWritable} = fullfile(userpath, 'Preferences', 'NDI') % Todo: Use prefdir
        
        % CalcDoc - A cell array of paths to NDI calculator document definitions
        CalcDoc = ndi.common.PathConstants.findCalculatorDocumentDefinitions("database_documents")
        
        % CalcDocSchema - A cell array of paths to NDI calculator document schemas
        CalcDocSchema = ndi.common.PathConstants.findCalculatorDocumentDefinitions("schema_documents")
    end

    methods (Static, Access = private)
        function pathList = findCalculatorDocumentDefinitions(key)

            arguments
                key (1,1) string {mustBeMember(key, ["database_documents", "schema_documents"])}
            end
            
            persistent d
            if isempty(d)
                d = ndi.fun.find_calc_directories();
            end

            pathList = cell(1, numel(d));
            for i = 1:numel(d)
                pathList{i} = fullfile(d{i}, 'ndi_common', key);
                addpath(d{i})
            end
        end

        function folderPath = initializeFolder( folderPath )

        end
    end
end

function mustBeWritable(folderPath)
    if ~isfolder(folderPath)
        mkdir(folderPath)
    end

	ndiido = ndi.ido();
	fname = fullfile( folderPath, ['testfile_' ndiido.id() '.txt'] );
	fid = fopen(fname,'wt');
    if fid < 0
        throwWriteAccessDeniedError(folderPath)
    end
	fclose(fid);
	delete(fname);
end

function throwWriteAccessDeniedError(folderPath)
    [~, name] = fileparts(folderPath);
    error('NDI:FolderNotWritable', ...
          'We do not have write access to the "%s" at %s', name, folderPath)
end