classdef FolderOrganizationModel < ndi.internal.mixin.JsonSerializable & matlab.mixin.SetGet

% Todo: Rename to FolderTreeModel

    properties (Constant) % ndi.internal.mixin.JsonSerializable
        VERSION = "1.0.0"
        DESCRIPTION = "NDI Folder Organization Model"
    end

    properties (Transient)
        RootDirectory
    end

    properties (Transient, Dependent) % or setaccess immutable...
        %PresetFolderModels
    end

    properties
        % FolderLevels - A list of FolderLevels objects
        FolderLevels (1,:) ndi.dataset.gui.models.FolderLevel

        % SubFolders - A list of names (string) for subfolders located
        % within a session / data folder. Currently no functional role.
        SubFolders (1,:) string
    end

    events
        FolderLevelChanged
        FolderLevelAdded
        FolderLevelRemoved

        % OR:
        FolderModelChanged
    end

    methods % Constructor
        function obj = FolderOrganizationModel(propertyValues)
            arguments
                propertyValues.?ndi.dataset.gui.models.FolderOrganizationModel
            end
            
            obj.set(propertyValues)
        end
    end

    methods % public methods
        function assertExistSubfolders(obj)
            numFolderLevels = numel(obj.FolderLevels);
            subFolderOptions = obj.listFoldersAtDepth(numFolderLevels+1);

            assert( ~isempty(subFolderOptions), 'No subfolders exist at the given folder level' )
        end
        
        function folderRelativePath = getExampleFolder(obj)
            folderRelativePath = fullfile(obj.FolderLevels.Name);
        end

        function [folderLevel, folderLevelIdx] = getFolderLevel(obj, folderLevelType)
            arguments
                obj
                folderLevelType (1,1) ndi.dataset.gui.enum.FolderLevelType
            end

            folderLevelIdx = find( [obj.FolderLevels.Type] == folderLevelType);
            folderLevel = obj.FolderLevels(folderLevelIdx);
        end

        function value = getFolderLevelType(obj)
            value = [obj.FolderLevels.Type];
        end

        function setFolderLevelType(obj, value)
            for i = 1:numel(obj.FolderLevels)
                obj.FolderLevels(i).Type = value(i);
            end
        end

        function value = getSubfolders(obj, options)
            arguments
                obj
                options.Type (1,1) ndi.dataset.gui.enum.FolderLevelType
                options.Id (1,:) string = missing
            end

            %value = unique(obj.SubFolders);
        end

        function addSubFolderLevel(obj, propertyValues)
            arguments
                obj
                propertyValues.?ndi.dataset.gui.models.FolderLevel %#ok<INUSA>
            end

            nvPairs=namedargs2cell(propertyValues);
            obj.FolderLevels(end+1) = ndi.dataset.gui.models.FolderLevel(nvPairs{:});
            obj.notify('FolderModelChanged')
        end

        function removeSubfolderLevel(obj, folderLevelIdx)
            obj.FolderLevels(folderLevelIdx) = [];
            obj.notify('FolderModelChanged')
        end
        
        function updateFolderLevel(obj, folderLevelIdx, propertyName, newValue)
            
            obj.FolderLevels(folderLevelIdx).(propertyName) = newValue;
            
            % Todo: eventdata??

            obj.notify('FolderModelChanged')
        end

        function addSubfolders(obj, subFolderNames)
            subFolderNames = reshape(subFolderNames, 1, []);
            obj.SubFolders = [obj.SubFolders, subFolderNames];
        end
    end

    methods
        function S = getFolderLevelStruct(obj)

            S = struct.empty;

            % Todo: Assign fieldnames and loop...
            warnState = warning('off', 'MATLAB:structOnObject');
            for i = 1:numel(obj.FolderLevels)
                if i == 1
                    S = struct(obj.FolderLevels(i));
                else
                    S(i) = struct(obj.FolderLevels(i));
                end
            end
            warning(warnState)
            if ~isempty(S)
                S = rmfield(S, 'FolderNamePrefix');
            end
        end

        function updateFolderLevelFromStruct(obj, S)
            obj.FolderLevels(:) = []; % Delete existing

            for i = 1:numel(S)
                nvPairs = namedargs2cell(S(i));
                obj.addSubFolderLevel(nvPairs{:})
            end
        end
    
        function folderPath = listAllFolders(obj)
        % listAllFolders - List all folders in a root directory based on model
            folderPath = string.empty;
            
            S = obj.getFolderLevelStruct();
            if isempty(S); return; end
            
            folderPath = cellstr(obj.RootDirectory);

            for i = 1:numel(S)

                % Look for subfolders in the folderpath
                folderPath = recursiveDir(folderPath, ...
                    'Expression', S(i).Expression, ...
                    'Ignore', S(i).IgnoreList, ...
                    'Type', 'folder', ...
                    'RecursionDepth', 1, ...
                    'OutputType', 'FilePath');
            end
        end
    end
    

    % Methods of folder model
    methods (Access = private) 
        function folderPath = getFolderPathAtDepth(obj, subfolderDepth)
        % getFolderAtDepth - Get path name for the subfolder at given depth
            
            rootDirectoryPath = obj.RootDirectory;
            numFolderLevels = numel(obj.FolderLevels);

            % Todo: Assert subfolderDepth is not deeper than number of subfo
            assert(subfolderDepth <= numFolderLevels, ...
                'Subfolder depth must be less than or equal to %d', numFolderLevels)

            if subfolderDepth >= 0 && ~isempty(rootDirectoryPath)
                folderPath = rootDirectoryPath;
        
                for iLevel = 1:subfolderDepth % Get folderpath from data struct...
                    if isempty( char(obj.FolderLevels(iLevel).Name) )
                        error('NDI:FolderModel:FolderNameIsEmpty', 'Folder name is not specified for folder level %d', iLevel)
                    end
                    folderPath = fullfile(folderPath, obj.FolderLevels(iLevel).Name);
                end
            else
                folderPath = '';
            end
        end
    end

    methods (Access = public)
        function folderNames = listFoldersAtDepth(obj, subfolderDepth)
        % listFoldersAtDepth - List all folders at a given depth which pass filters     
            S = obj.getFolderLevelStruct();
            
            rootFolderPath = obj.getFolderPathAtDepth(subfolderDepth-1);

            if subfolderDepth <= numel(obj.FolderLevels)
                expression = S(subfolderDepth).Expression;
                ignoreList = S(subfolderDepth).IgnoreList;
            else
                expression = "";
                ignoreList = string.empty;
            end

            % Look for subfolders in the folderpath
            L = recursiveDir(rootFolderPath, ...
                'Expression', expression, ...
                'Ignore', ignoreList, ...
                'Type', 'folder', ...
                'RecursionDepth', 1);

            folderNames = {L.name};
        end
    end

    methods (Access = protected)
        % function fromStruct(obj, S)
        % 
        % end
    end

    methods (Static)
        function T = getDefaultFolderLevelTable()
            folderLevel = ndi.dataset.gui.models.FolderLevel();
            warnState = warning('off', 'MATLAB:structOnObject');
            S = struct(folderLevel);
            warning(warnState)
            S = rmfield(S, 'FolderNamePrefix');
            T = struct2table(S, "AsArray", true);
            T = addprop(T, 'VariableTitle', 'variable');
            T.Properties.CustomProperties.VariableTitle = {'Select subfolder example', 'Set subfolder type', 'Exclusion list', 'Inclusion list'};
        end
    end

    methods (Static)
        function obj = fromJson(jsonStr)
            className = mfilename('class');
            obj = fromJson@ndi.internal.mixin.JsonSerializable(jsonStr, className);
        end
    end
end