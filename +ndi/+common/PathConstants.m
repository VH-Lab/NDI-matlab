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
        DocumentFolder {mustUpdateDidGlobals(DocumentFolder, "$NDIDOCUMENTPATH")} = ...
            fullfile(ndi.common.PathConstants.CommonFolder, 'database_documents')

        % DocumentSchemaFolder - The path of the NDI document validation schema
        DocumentSchemaFolder  {mustUpdateDidGlobals(DocumentSchemaFolder, '$NDISCHEMAPATH')} = ...
            fullfile(ndi.common.PathConstants.CommonFolder, 'schema_documents')

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
        CalcDoc {mustUpdateDidGlobals(CalcDoc, '$NDICALCDOCUMENTPATH')} = ...
            ndi.common.PathConstants.findCalculatorDocumentDefinitions("database_documents")

        % CalcDocSchema - A cell array of paths to NDI calculator document schemas
        CalcDocSchema {mustUpdateDidGlobals(CalcDocSchema, '$NDICALCSCHEMAPATH')} = ...
            ndi.common.PathConstants.findCalculatorDocumentDefinitions("schema_documents")
    end

    methods (Static)
        function placeholder = getNdiPathPlaceholderName(name)
            persistent nameMap
            if isempty(nameMap)
                scriptLocation = fileparts(mfilename('fullpath'));
                nameMapFilePath = fullfile(scriptLocation, 'resources', 'pathNameMapping.json');
                S = jsondecode( fileread(nameMapFilePath) );
                nameMap = containers.Map(fieldnames(S), struct2cell(S));
            end

            identifier = string( nameMap(name) );
            placeholder = "$NDI" + upper(identifier);
        end

        function updateDIDConstants()
            dependencies = {...
                '$NDISCHEMAPATH', ndi.common.PathConstants.DocumentFolder; ...
                '$NDIDOCUMENTPATH', ndi.common.PathConstants.DocumentSchemaFolder; ...
                '$NDICALCDOCUMENTPATH', ndi.common.PathConstants.CalcDoc; ...
                '$NDICALCSCHEMAPATH', ndi.common.PathConstants.CalcDocSchema };

            definitionsMap = did.common.PathConstants.definitions;

            for i = 1:size(dependencies, 1)
                key = dependencies{i,1};
                value = dependencies{i,2};
                if ~isKey(definitionsMap, key) && ~isempty(value)
                    definitionsMap(key) = value;
                end
            end
        end
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
                %addpath(d{i})  % Matlab hangs for me here; it doesn't like this being called from a constant definition
                % error: `Unable to determine if 'ndi.common.PathConstants.CommonFolder' is a function.`...
                %        ` The MATLAB Path or current folder changed too many times during the search.`
            end
        end
    end
end

function mustUpdateDidGlobals(value, key)
    ndi.common.assertDIDInstalled()
    definitionsMap = did.common.PathConstants.definitions;
    if ~isKey(definitionsMap, key)
        if ~isempty(value)
            definitionsMap(key) = value; %#ok<NASGU> This is a handle object
        else
            if strcmp(key, "$NDIDOCUMENTPATH")
                error('Could not update DID globals')
            else
                %pass
            end
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
