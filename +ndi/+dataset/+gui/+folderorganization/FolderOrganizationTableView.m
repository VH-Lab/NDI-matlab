classdef FolderOrganizationTableView < handle
    
    properties (Access = private)
        UITable
    end

    properties (Access = private)
        DataModel
    end

    properties (Access = private)
        FolderModelChangedListener
        ShowAdvancedOptions = true % Todo: Change default to false...
    end

    methods % Constructor
        function obj = FolderOrganizationTableView(dataModel, uiTable)
            if ~nargin; return; end
            obj.DataModel = dataModel;
            obj.UITable = uiTable;

            % Add listeners for model events
            obj.FolderModelChangedListener = listener(obj.DataModel, ...
                'FolderModelChanged', @obj.onFolderModelChanged);
        end
    end

    methods 
        function update(obj)
            obj.updateTableView()
        end

        function showAdvancedOptions(obj)
            obj.ShowAdvancedOptions = true;
            
            obj.UITable.VisibleColumns = [true,true,true,true];
            obj.UITable.ColumnWidth(1:2) = {185, 175};

            obj.updateTableView()
            drawnow
            obj.UITable.redraw()
        end

        function hideAdvancedOptions(obj)
            obj.ShowAdvancedOptions = false;

            obj.UITable.VisibleColumns = [true,true,false,false];
            obj.UITable.ColumnWidth(1:2) = {'2x', '1x'};

            obj.updateTableView()
            drawnow
            obj.UITable.redraw()
        end
    end

    % Callback functions handling folder model events
    methods (Access = private)
        function onFolderModelChanged(obj, src, evt)
            obj.updateTableView()
        end
    end

    methods (Access = private)
        function updateTableView(obj)
            S = obj.DataModel.getFolderLevelStruct();
            if isempty(S); return; end

            for i = 1:numel(S)
                subFolderOptions = obj.DataModel.listFoldersAtDepth(i);
                subFolderOptions = [{'<Select a Folder>'}, subFolderOptions]; %#ok<AGROW>

                if isempty(char(S(i).Name))
                    S(i).Name = subFolderOptions{1};
                elseif ~any(strcmp(S(i).Name, subFolderOptions))
                    S(i).Name = subFolderOptions{1};
                end
                S(i).Name = categorical({char(S(i).Name)}, subFolderOptions);

                % Update ignorelist to comma separated char
                S(i).IgnoreList = strjoin( S(i).IgnoreList, ', ');
            end

            if ~obj.ShowAdvancedOptions
                %S = rmfield(S, {'Expression', 'IgnoreList'});
            end

            % Assign the struct array as the tables data...
            obj.UITable.updateData(S)

            % Only allow removal of the last folder level.
            numFolderLevels = numel(obj.DataModel.FolderLevels);
            obj.UITable.disableRemoveRowButton(1:numFolderLevels-1)
            obj.UITable.enableRemoveRowButton(numFolderLevels)
        end
    end
end