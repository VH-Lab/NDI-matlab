classdef FolderOrganizationTable < applify.apptable
% FolderOrganizationTable - A table for uifigures to specify folder organization

% Note: this class is a mess when it comes to updating the data and values.
% Needs work in order to instantly update the datalocation model on
% changes. The methods for updating are misused, so that whenever the
% subfolder example selection is changed, add row and remove row is called,
% although this does not mean the model is changed. Need to separate
% methods better...

%   Methods that use updateSubfolderItems
%       - addrow
%       - subfolderChanged
%       - onIgnoreExpressionValueChanged
%       - onFilterExpressionValueChanged
%       - onRootDirectorySet
%
%   should separate beteen whether 1) names of existing subfolder levels are
%   changed, 2) subfolders levels are added or removed and 3) datalocation
%   is set/changed.

    % updateRowData
    % updateDirectoryTree

    properties (Constant)
        COLUMN_NAMES = {'', 'Select subfolder example', 'Set subfolder type', 'Exclusion list', 'Inclusion list', ''}
        COLUMN_WIDTHS = [22, 175, 130, 90, 125, 22]
    end

    % properties / app states depending on outside values:
    properties
        RootDirectory

        % Data... Should be an object with callbacks and events?
        
        % stuct/table/object representation of whats in table..
        SubfolderStructure
        CurrentDataLocation
    end

    properties
        AppFigure % Todo: make sure this is set... Needed???
    end

    properties
        IsDirty = false     % Flag to show if data has changed.
        IsAdvancedView = true
        IsUpdating = false  % Flag to disable event notification when table is being updated.
    end

    properties (Access = private)
        FolderOrganizationFilterListener
    end
    
    events
        FilterChanged
        ModelChanged
    end
    
    methods % Structors
        function obj = FolderOrganizationTable(folderOrganizationModel, varargin)
        %FolderOrganizationTable - Construct a FolderOrganizationTable instance
            
            % Todo:
            % 2 inputs: 
            %   1) Root directory
            %   2) Folder organization model...
            
            if ~isempty(folderOrganizationModel)
                varargin = [varargin, {'Data', folderOrganizationModel.FolderLevels}];
            end

            obj@applify.apptable(varargin{:})
            
            if ~isempty(folderOrganizationModel)
                obj.SubfolderStructure = folderOrganizationModel.FolderLevels;   
            end

            obj.IsUpdating = true;
            for i = 1:obj.NumRows
                obj.updateSubfolderItems(i);
            end
            obj.IsDirty = false;
            obj.IsUpdating = false;
            obj.AppFigure = ancestor(obj.Parent, 'figure');
        end
        
        function delete(obj)
            isDeletable = @(h) ~isempty(h) && isvalid(h);
            
            if isDeletable(obj.FolderOrganizationFilterListener)
                delete(obj.FolderOrganizationFilterListener)
            end
        end
    end

    methods % Set/get
        function set.RootDirectory(obj, newValue)
            obj.RootDirectory = newValue;
            obj.onRootDirectorySet()
        end

        function set.SubfolderStructure(obj, newValue)
            obj.SubfolderStructure = newValue;
            obj.onSubfolderStructureSet()
        end
    end 
    
    methods (Access = protected) % Implementation of superclass (UIControlTable) methods

        function assignDefaultTablePropertyValues(obj)
            obj.ColumnNames = obj.COLUMN_NAMES;
            obj.ColumnWidths = obj.COLUMN_WIDTHS;
            obj.ColumnHeaderHelpFcn = @ndi.dataset.gui.getTooltipMessage;
            obj.RowSpacing = 20;
        end
        
        function hRow = createTableRowComponents(obj, rowData, rowNum)
        
            hRow = struct(...
                      'RemoveImage', obj.createRemoveRowButton(rowNum, 1), ...
                'SubfolderDropdown', obj.createSubfolderSelectionDropdown(rowNum, 2), ...
            'SubfolderTypeDropdown', obj.createSubfolderTypeSelectionDropdown(rowNum, 3), ...
                    'DynamicRegexp', obj.createFilterExpressionEditfield(rowNum, 5), ...
                       'IgnoreList', obj.createIgnoreExpressionEditfield(rowNum, 4), ...
                         'AddImage', obj.createAddRowButton(rowNum, 6) ...
                         );
            
            % Customize components...
            if obj.NumRows == 0; hRow.RemoveImage.Enable = 'off'; end
            if rowNum == 1; hRow.RemoveImage.Enable = 'off'; end
           
            if rowNum > 1
                % Disable the button for add new row on the previous row.
                obj.RowControls(rowNum-1).AddImage.Enable = 'off';
            end

            obj.updateRowComponentValues(hRow, rowData, rowNum)
        end

        function updateRowComponentValues(obj, rowComponents, rowData, rowNum)
        % updateRowComponentValues - Update component values from data
            
            if isempty(rowData.Type) || strcmp(rowData.Type, 'Undefined')
                rowComponents.SubfolderTypeDropdown.Value = 'Select type';
                obj.Data(rowNum).Type = 'Undefined';
            else
                rowComponents.SubfolderTypeDropdown.Value = rowData.Type;
            end

            if ~isempty(rowData.Expression)
                rowComponents.DynamicRegexp.Value = rowData.Expression;
            end

            if ~isempty(rowData.IgnoreList)
                rowComponents.IgnoreList.Value = strjoin(rowData.IgnoreList, ', ');
            end
        end
    end
    
    methods (Access = private) % Callbacks for table / component
        
        function onRootDirectorySet(obj)
        %onRootDirectorySet - Update table when root directory is set
            if ~obj.IsConstructed; return; end
            
            obj.IsUpdating = true;
            obj.resetTable()
            obj.Data = obj.SubfolderStructure;
            obj.updateTable()
            obj.IsUpdating = false;
        end

        function onSubfolderStructureSet(obj)
        %onSubfolderStructureSet - Update table when subfolder structure is set

            if ~obj.IsConstructed; return; end

            obj.IsUpdating = true;
            obj.resetTable()
            obj.Data = obj.SubfolderStructure;
            obj.updateTable()
            obj.IsUpdating = false;
        end
    end

    methods % Todo: (Access = protected) % Override superclass (UIControlTable) methods
        function wasSuccess = addRow(obj, src, ~)
            
            src.Enable = 'off';
            addRow@applify.apptable(obj)
            
            % Get row number of new row.
            rowNum = obj.getComponentRowNumber(src) + 1;

            if ~obj.IsAdvancedView
                obj.setRowDisplayMode(rowNum, false)
            end
            
            % Todo: should refactor this so that first, we check if folders
            % are available, then add row if confirmed...
            wasSuccess = obj.updateSubfolderItems(rowNum);
            if ~wasSuccess
                obj.removeRow()
                return
            end
            
            evtData = event.EventData();
            obj.notify('FilterChanged', evtData)
        end
        
        function removeRow(obj, src, ~)
            
            if nargin < 2 % Remove last row if no input is given.
                i = obj.NumRows;
            elseif isnumeric(src)
                i = src;
            else
                i = obj.getComponentRowNumber(src);
            end
            
            removeRow@applify.apptable(obj, i)
            
            % Enable button for adding new row on the row above the one 
            % that was just removed.
            if i > 1
                obj.RowControls(i-1).AddImage.Enable = 'on';
            end
            
            evtData = event.EventData();
            obj.notify('FilterChanged', evtData)
        end
    
        % Todo: Generalize. Should be method of UIControlTable to get
        % current data as a table
        function S = getSubfolderStructure(obj)

            % This method retrieves data from components and places it in a
            % struct.
            
            S = struct('Name', {}, 'Type', {}, 'Expression', {}, 'IgnoreList', {{}});
            
            for j = 1:numel(obj.RowControls)
                
                S(j).Name = obj.RowControls(j).SubfolderDropdown.Value;
                S(j).Type = obj.RowControls(j).SubfolderTypeDropdown.Value;
                
                if strcmp(S(j).Type, 'Select type')
                    S(j).Type = 'Undefined';
                end
                
                inputExpr = obj.RowControls(j).DynamicRegexp.Value;

                % Convert input expressions to expression that can be
                % used with the regexp function
                if strcmp(S(j).Type, 'Date')
                    S(j).Expression = utility.string.dateformat2expression(inputExpr);
                    S(j).Expression = utility.string.numbersymbol2expression(S(j).Expression);
                else
                    S(j).Expression = utility.string.numbersymbol2expression(inputExpr);
                end
                
                ignoreList = obj.RowControls(j).IgnoreList.Value;
                if isempty(ignoreList)
                    S(j).IgnoreList = {};
                else
                    S(j).IgnoreList = strsplit(obj.RowControls(j).IgnoreList.Value, ',');
                    S(j).IgnoreList = strtrim(S(j).IgnoreList);
                    % If someone accidentally entered a comma at the end of
                    % the list.
                    if isempty(S(j).IgnoreList{end})
                        S(j).IgnoreList(end) = [];
                    end
                end
            end
        end
    end

    methods % (Access = protected) % Internal methods
        
        function notify(obj, eventName, eventData)
        %notify Disable event notification when table is being updated
        %
        %   Note: Some methods that notify about events are being invoked
        %   during table update. The method ensures that events are not
        %   triggered during table update.
        
            if obj.IsUpdating 
                return; 
            else
                notify@handle(obj, eventName, eventData)
            end
        end
        
        function showAdvancedOptions(obj)
            
            % Relocate / show header elements
            obj.setColumnHeaderDisplayMode(true)

            % Relocate / show column elements
            for i = 1:numel(obj.RowControls)
                obj.setRowDisplayMode(i, true)
            end
            
            obj.IsAdvancedView = true;
            drawnow
        end
        
        function hideAdvancedOptions(obj)
            
            % Relocate / show header elements
            obj.setColumnHeaderDisplayMode(false)
            
            % Relocate / show column elements
            for i = 1:numel(obj.RowControls)
                obj.setRowDisplayMode(i, false)
            end
            
            obj.IsAdvancedView = false;
            drawnow
        end
                
        function setColumnHeaderDisplayMode(obj, showAdvanced)
            
            xOffset = sum(obj.ColumnWidths(4:5)) + obj.ColumnSpacing;
            visibility = 'off';

            if showAdvanced
                xOffset = -1 * xOffset;
                visibility = 'on';
            end
            
            % Relocate / show header elements
            %obj.ColumnHeaderLabels{2}.Position(3) = obj.ColumnHeaderLabels{2}.Position(3) + xOffset;
            %obj.ColumnLabelHelpButton{2}.Position(1) = obj.ColumnLabelHelpButton{2}.Position(1) + xOffset;
            
            obj.ColumnHeaderLabels{3}.Position(1) = obj.ColumnHeaderLabels{3}.Position(1) + xOffset;
            obj.ColumnLabelHelpButton{3}.Position(1) = obj.ColumnLabelHelpButton{3}.Position(1) + xOffset;
            
            obj.ColumnHeaderLabels{4}.Visible = visibility;
            obj.ColumnLabelHelpButton{4}.Visible = visibility;
            
            obj.ColumnHeaderLabels{5}.Visible = visibility;
            obj.ColumnLabelHelpButton{5}.Visible = visibility;
        end
        
        function setRowDisplayMode(obj, rowNum, showAdvanced)
            
            xOffset = sum(obj.ColumnWidths(4:5)) + obj.ColumnSpacing;
            visibility = 'off';

            if showAdvanced
                xOffset = -1 * xOffset;
                visibility = 'on';
            end
            
            hRow = obj.RowControls(rowNum);
            hRow.SubfolderDropdown.Position(3) = hRow.SubfolderDropdown.Position(3) + xOffset;
            hRow.SubfolderTypeDropdown.Position(1) = hRow.SubfolderTypeDropdown.Position(1) + xOffset;
            hRow.DynamicRegexp.Visible = visibility;
            hRow.IgnoreList.Visible = visibility;
        end
        
        function markClean(obj)
            obj.IsDirty = false;
        end
        
        function markDirty(obj)
            obj.IsDirty = true;
        end
    end

    methods % Updating subfolders...
        function updateTable(obj)
            
            % Recreate rows.
            for i = 1:numel(obj.Data)
                rowData = obj.getRowData(i);
                obj.createTableRow(rowData, i)
                
                obj.updateSubfolderItems(i); % Semicolon, this fcn has output.
                if ~obj.IsAdvancedView
                    obj.setRowDisplayMode(i, false)
                end
            end
        end
        
        function subfolderChanged(obj, src, ~)
            
            obj.IsDirty = true;
            iRow = obj.getComponentRowNumber(src);
            
            %Update data property obj.Data(iRow).Name
            obj.Data(iRow).Name = obj.RowControls(iRow).SubfolderDropdown.Value;

            if iRow == obj.NumRows
                return
            end
            
            % Update list of subfolder items on the next row
            obj.updateSubfolderItems( iRow+1 )
            
            % Remove subfolders on successive rows if present
            for i = iRow+2:numel(obj.NumRows)
                obj.removeRow()
            end
        end

        function success = updateSubfolderItems(obj, iRow)
        %updateSubfolderItems Update values in controls...
            
            success = true;

            % if isempty(obj.CurrentDataLocation.RootPath)
            %     rootDirectoryPath = '';
            % else
            %     rootDirectoryPath = obj.CurrentDataLocation.RootPath(1).Value;
            % end

            rootDirectoryPath = obj.RootDirectory;
            
            % Get path for parent folder of current row (subfolder depth)
            parentFolderPath = obj.getFolderPathAtDepth(iRow-1);
            
            % List subfolders at current level:
            subfolderNames = obj.listFoldersAtDepth(parentFolderPath, iRow);

            % Todo: Add something like this if implementing virtual folders
            % in a datalocation
% % %             if isempty(dirName)
% % %                 % show message...
% % %                 [~, dirName] = utility.path.listFiles(folderPath);
% % %             end
            
            % Get handle to dropdown control
            hSubfolderDropdown = obj.RowControls(iRow).SubfolderDropdown;
            
            % Show message dialog and return if no subfolders are found.
            if isempty(rootDirectoryPath)
                hSubfolderDropdown.Items = {'Root folder is not specified'};
                if ~nargout; clear success; end
                return
            elseif ~isfolder( rootDirectoryPath )
                hSubfolderDropdown.Items = {'Root folder does not exist'};
                if ~nargout; clear success; end
                return
            elseif isempty(subfolderNames) % && iRow > 1
% %                 message = 'No subfolders were found within the selected folder';
% %                 hFigure = ancestor(obj.Parent, 'figure');
% %                 uialert(hFigure, message, 'Aborting')
                success = false;
                hSubfolderDropdown.Items = {'No subfolders were found'};            
                if ~nargout; clear success; end
                return
            end
            
            % Need to update field based on current data.
            hSubfolderDropdown.Items = subfolderNames;
            
            if isempty( char( obj.Data(iRow).Name ) ) 
                % Select the first subfolder:
                newValue = subfolderNames{1};
            else
                if ~contains(hSubfolderDropdown.Items, obj.Data(iRow).Name)
                    % Todo: Add message saying that folder was not
                    % available in detected items.
                    newValue = subfolderNames{1};
                else
                    newValue = obj.Data(iRow).Name;
                end
            end
            
            if ~isequal(hSubfolderDropdown.Value, newValue)
                hSubfolderDropdown.Value = newValue;
                if ~obj.IsUpdating
                    obj.subfolderChanged(hSubfolderDropdown)
                end
            end
            
            obj.Data(iRow).Name = hSubfolderDropdown.Value;
            
            % Switch button for adding new row.
            if iRow == obj.NumRows
                obj.RowControls(iRow).AddImage.Enable = 'on';
            end
            
            obj.IsDirty = true;
            
            if ~nargout; clear success; end
        end
    end

    methods (Access = private) % Todo: methods of folder model
        function folderPath = getFolderPathAtDepth(obj, subfolderDepth)
        % getFolderAtDepth - Get path name for the subfolder at given depth
                    
            rootDirectoryPath = obj.RootDirectory;

            if subfolderDepth >= 0 && ~isempty(rootDirectoryPath)
                folderPath = rootDirectoryPath;
        
                for iLevel = 1:subfolderDepth % Get folderpath from data struct...
                    folderPath = fullfile(folderPath, obj.Data(iLevel).Name);
                end
            else
                folderPath = '';
            end
        end

        function folderNames = listFoldersAtDepth(obj, parentFolderPath, subfolderDepth)
        % listFoldersAtDepth - List all folders at a given depth which pass filters     
            S = obj.getSubfolderStructure();
            
            % Look for subfolders in the folderpath
            [~, folderNames] = utility.path.listSubDir(parentFolderPath, ...
                S(subfolderDepth).Expression, S(subfolderDepth).IgnoreList);
        end
    end

    methods (Access = private) % Callbacks for row components
        % Callback for SubfolderSelectionDropdown
        function onSubfolderSelectionChanged(obj, src, ~)
            obj.subfolderChanged(src)
        end
        
        % Callback for SubfolderSelectionTypeDropdown
        function onSubFolderTypeSelectionChanged(obj, src, evt)
            iRow = obj.getComponentRowNumber(src);
            obj.SubfolderStructure(iRow).Type = src.Value;
            obj.Data(iRow).Type = src.Value;
            obj.markDirty()
        end
        
        % Callback for IgnoreExpressionEditfield
        function onIgnoreExpressionValueChanged(obj, src, evt)
            iRow = obj.getComponentRowNumber(src);
            if isempty(src.Value)
                obj.Data(iRow).IgnoreList = {};
            else
                obj.Data(iRow).IgnoreList = strtrim( strsplit(src.Value, ',') );
            end
            obj.SubfolderStructure(iRow).IgnoreList = obj.Data(iRow).IgnoreList;
            obj.markDirty()
            
            evtData = event.EventData();
            obj.notify('FilterChanged', evtData)
            
            obj.updateSubfolderItems(iRow)
        end
        
        % Callback for FilterExpressionEditfield
        function onFilterExpressionValueChanged(obj, src, evt)
            iRow = obj.getComponentRowNumber(src);
            obj.Data(iRow).Expression = src.Value;
            obj.markDirty()
            
            evtData = event.EventData();
            obj.notify('FilterChanged', evtData)
            
            obj.updateSubfolderItems(iRow); % supress output
        end
        
        % Callback for AddRowButton
        function onAddSubfolderButtonPushed(obj, src, ~)
            
            wasSuccess = obj.addRow(src);
            
            % Show message to user if this failed.
            if ~wasSuccess
                hFigure = ancestor(obj.Parent, 'figure');
                message = 'No subfolders were found within the selected folder';
                uialert(hFigure, message, 'Aborting')
            else
                obj.SubfolderStructure(end+1) = feval( class(obj.SubfolderStructure) );
            end
        end

        function onRemoveSubfolderLevelButtonPushed(obj, ~, ~)
            obj.removeRow()
            obj.SubfolderStructure(end) = [];
        end
    end

    methods (Access = private) % Create individual components
        function hButton = createRemoveRowButton(obj, rowIdx, columnIdx)
        % createRemoveRowButton - Button with minus icon for removing row
            [xi, y, wi, h] = obj.getCellPosition(rowIdx, columnIdx);
            hButton = uibutton(obj.TablePanel);
            hButton.Position = [xi y wi h];
            hButton.Text = '';
            hButton.Icon = nansen.internal.getIconPathName('minus.png');
            hButton.ButtonPushedFcn = @obj.onRemoveSubfolderLevelButtonPushed;
        end

        function hDropdown = createSubfolderSelectionDropdown(obj, rowIdx, columnIdx)
        % createSubfolderSelectionDropdown - Create dropdown for selecting subfolder name
            [xi, y, wi, h] = obj.getCellPosition(rowIdx, columnIdx);
            hDropdown = uidropdown(obj.TablePanel);
            hDropdown.Position = [xi y wi h];
            hDropdown.FontName = 'Segoe UI';
            hDropdown.BackgroundColor = [1 1 1];
            hDropdown.ValueChangedFcn = @obj.onSubfolderSelectionChanged;
            hDropdown.Items = {'Select subfolder'};
            hDropdown.Value = 'Select subfolder';
        end

        function hDropdown = createSubfolderTypeSelectionDropdown(obj, rowIdx, columnIdx)
        % createSubfolderTypeSelectionDropdown - Create dropdown for selecting subfolder type
            [xi, y, wi, h] = obj.getCellPosition(rowIdx, columnIdx);
            hDropdown = uidropdown(obj.TablePanel);
            hDropdown.Position = [xi y wi h];
            hDropdown.ValueChangedFcn = @obj.onSubFolderTypeSelectionChanged;
            % Todo: Get from enum?
            hDropdown.Items = {'Select type', 'Date', 'Subject', 'Session', 'Epoch', 'Other'};
        end

        function hEditfield = createFilterExpressionEditfield(obj, rowIdx, columnIdx)
        % createFilterExpressionEditfield - Create editfield for entering a filter expression
        %
        %   This field will be used to filter the folders on the
        %   corresponding subfolder level.
            [xi, y, wi, h] = obj.getCellPosition(rowIdx, columnIdx);
            hEditfield = uieditfield(obj.TablePanel, 'text');
            hEditfield.Position = [xi y wi h];
            hEditfield.FontName = 'Segoe UI';
            hEditfield.BackgroundColor = [1 1 1];
            hEditfield.ValueChangedFcn = @obj.onFilterExpressionValueChanged;
        end

        function hEditfield = createIgnoreExpressionEditfield(obj, rowIdx, columnIdx)
        % createSubfolderTypeSelectionDropdown - Create dropdown for selecting subfolder type
            [xi, y, wi, h] = obj.getCellPosition(rowIdx, columnIdx);
            hEditfield = uieditfield(obj.TablePanel, 'text');
            hEditfield.Position = [xi y wi h];
            hEditfield.FontName = 'Segoe UI';
            hEditfield.BackgroundColor = [1 1 1];
            hEditfield.ValueChangedFcn = @obj.onIgnoreExpressionValueChanged;
        end

        function bButton = createAddRowButton(obj, rowIdx, columnIdx)
        % createSubfolderTypeSelectionDropdown - Create dropdown for selecting subfolder type
            [xi, y, wi, h] = obj.getCellPosition(rowIdx, columnIdx);
            bButton = uibutton(obj.TablePanel);
            bButton.Position = [xi y wi h];
            bButton.Text = '';
            bButton.Icon = nansen.internal.getIconPathName('plus.png');
            bButton.ButtonPushedFcn = @obj.onAddSubfolderButtonPushed;
            bButton.Enable = 'off';
        end
    end
end