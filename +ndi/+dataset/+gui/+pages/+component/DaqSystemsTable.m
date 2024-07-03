classdef DaqSystemsTable < applify.apptable
% Class interface for editing/configuring DAQ System in a uifigure

    % properties / app states depending on outside values:
    
    properties (Constant)
        COLUMN_NAMES = {'', 'Name', 'Select Data Source', 'Select Data Reader', 'File Parameters', '', ''}
        COLUMN_WIDTHS = [22, 100, 175, 130, 120, 22, 22]
    end

    properties
        EditDaqSystemButtonPushedFcn
    end 
    
    properties
        DaqSystemSpec % stuct/table/object representation of whats in table..
    end

    properties
        AppFigure % Todo: make sure this is set...
    end

    properties
        IsDirty = false     % Flag to show if data has changed.
        IsAdvancedView = true
        IsUpdating = false  % Flag to disable event notification when table is being updated.
    end

    methods % Structors
        function obj = DaqSystemsTable(daqSystemConfiguration, varargin)
        %FolderOrganizationTable Construct a FolderOrganizationTable instance
            warning('off', 'MATLAB:structOnObject')
            data = struct( daqSystemConfiguration );
            warning('on', 'MATLAB:structOnObject')
            varargin = [{'Data', data}, varargin];
            obj@applify.apptable(varargin{:})
            
            obj.AppFigure = ancestor(obj.Parent, 'figure');
        end
        
        function delete(obj)
        end
        
    end
    
    methods (Access = protected) % Implementation of superclass methods

        function assignDefaultTablePropertyValues(obj)
            obj.ColumnNames = obj.COLUMN_NAMES;
            obj.ColumnWidths = obj.COLUMN_WIDTHS;
            obj.ColumnHeaderHelpFcn = @ndi.dataset.gui.getTooltipMessage;
            obj.RowSpacing = 20;
        end
        
        function hRow = createTableRowComponents(obj, rowData, rowNum)
        
            hRow = struct(...
                          'RemoveImage', obj.createRemoveRowButton(rowNum, 1), ...
                        'NameEditField', obj.createDaqSystemNameEditfield(rowNum, 2), ...
                    'DaqSystemDropdown', obj.createDaqSystemSelectionDropdown(rowNum, 3), ...
                    'DaqReaderDropdown', obj.createDaqReaderSelectionDropdown(rowNum, 4), ...
              'FileParametersEditfield', obj.createFileParametersEditfield(rowNum, 5), ...
                           'EditButton', obj.createEditDaqSystemButton(rowNum, 6), ...
                             'AddImage', obj.createAddRowButton(rowNum, 7) ...
                             );
            
            if obj.NumRows == 0; hRow.RemoveImage.Enable = 'off'; end
            obj.updateRowComponentValues(hRow, rowData, rowNum)
        end

        function updateRowComponentValues(obj, rowComponents, rowData, rowNum)
        % updateRowComponentValues - Update component values from data
            
            if isempty(rowData.DaqReaderClass)
                rowComponents.DaqReaderDropdown.Value = '<Select reader>';
                obj.Data(rowNum).Type = '';
            else
                reader = strsplit(rowData.DaqReaderClass, '.');
                rowComponents.DaqReaderDropdown.Value = reader{end};
            end

            if ~isempty(rowData.FileParameters)
                rowComponents.DynamicRegexp.Value = strjoin( rowData.FileParameters, ',');
            end
        end
            
    end
    
    methods (Access = private)
        
        function onRootDirectorySet(obj)
            obj.onCurrentDataLocationSet()
        end

        function onCurrentDataLocationSet(obj)
        %onCurrentDataLocationSet Update controls based on current DataLoc
        
            if ~obj.IsConstructed; return; end
            
            obj.IsUpdating = true;
            
            obj.resetTable()
            
            obj.Data = obj.CurrentDataLocation.SubfolderStructure;
            
            % Recreate rows.
            for i = 1:numel(obj.Data)
                rowData = obj.getRowData(i);
                obj.createTableRow(rowData, i)
                
                obj.updateSubfolderItems(i); % Semicolon, this fcn has output.
                if ~obj.IsAdvancedView
                    obj.setRowDisplayMode(i, false)
                end
            end

            obj.IsUpdating = false;
        end
        
    end
    
    methods % Callbacks for row components
        
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

        function onRemoveRowButtonPushed(obj, src, ~)
            if nargin < 2 % Remove last row if no input is given.
                i = obj.NumRows;
            elseif isnumeric(src)
                i = src;
            else
                i = obj.getComponentRowNumber(src);
            end
            
            obj.removeRow(i)
        end

        function onDAQSystemNameChanged(obj, src, evt)
        end

        function onDaqSystemSelectionChanged(obj, src, evt)
        end

        function onDaqReaderSelectionChanged(obj, src, evt)
            % Todo: Need to expand full classname...
        end

        function onFileParametersValueChanged(obj, src, evt)

        end

        function onEditDaqSystemButtonPushed(obj, src, ~)
            if ~isempty(obj.EditDaqSystemButtonPushedFcn)
                hProgress = uiprogressdlg(obj.AppFigure, "Indeterminate", "on", "Message", "Opening DAQ System Editor");
                
                % Todo: Get DAQ System
                daqSystem = [];
                obj.EditDaqSystemButtonPushedFcn(daqSystem)

                delete(hProgress)
            end
        end

        function onAddDaqSystemButtonPushed(obj, src, evt)
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
            hButton.ButtonPushedFcn = @obj.onRemoveRowButtonPushed;
        end

        function hEditfield = createDaqSystemNameEditfield(obj, rowIdx, columnIdx)
        % createDaqSystemNameEditfield - Create editfield for entering a name

            [xi, y, wi, h] = obj.getCellPosition(rowIdx, columnIdx);
            hEditfield = uieditfield(obj.TablePanel, 'text');
            hEditfield.Position = [xi y wi h];
            hEditfield.FontName = 'Segoe UI';
            hEditfield.BackgroundColor = [1 1 1];
            hEditfield.ValueChangedFcn = @obj.onDAQSystemNameChanged;
        end

        function hDropdown = createDaqSystemSelectionDropdown(obj, rowIdx, columnIdx)
        % createSubfolderSelectionDropdown - Create dropdown for selecting subfolder name
            [xi, y, wi, h] = obj.getCellPosition(rowIdx, columnIdx);
            hDropdown = uidropdown(obj.TablePanel);
            hDropdown.Position = [xi y wi h];
            hDropdown.FontName = 'Segoe UI';
            hDropdown.BackgroundColor = [1 1 1];
            hDropdown.ValueChangedFcn = @obj.onDaqSystemSelectionChanged;
            hDropdown.Items = {'Multi-function DAQ'};
            hDropdown.Value = 'Multi-function DAQ';
        end

        function hDropdown = createDaqReaderSelectionDropdown(obj, rowIdx, columnIdx)
        % createSubfolderTypeSelectionDropdown - Create dropdown for selecting subfolder type
            [xi, y, wi, h] = obj.getCellPosition(rowIdx, columnIdx);
            hDropdown = uidropdown(obj.TablePanel);
            hDropdown.Position = [xi y wi h];
            hDropdown.ValueChangedFcn = @obj.onDaqReaderSelectionChanged;
            %hDropdown.Items = [{'<Select reader>'}, ndi.setup.daq.listDaqReaders()];
            hDropdown.Items = [{'<Select reader>'}, ndi.setup.daq.listDaqReaders()];
        end

        function hEditfield = createFileParametersEditfield(obj, rowIdx, columnIdx)
        % createFileParametersEditfield - Create editfield for entering a
        % file name expressinons

            [xi, y, wi, h] = obj.getCellPosition(rowIdx, columnIdx);
            hEditfield = uieditfield(obj.TablePanel, 'text');
            hEditfield.Position = [xi y wi h];
            hEditfield.FontName = 'Segoe UI';
            hEditfield.BackgroundColor = [1 1 1];
            hEditfield.ValueChangedFcn = @obj.onFileParametersValueChanged;
        end

        function hButton = createEditDaqSystemButton(obj, rowIdx, columnIdx)
        % createEditDaqSystemButton - Create button for editing DAQ system
            [xi, y, wi, h] = obj.getCellPosition(rowIdx, columnIdx);
            hButton = uibutton(obj.TablePanel);
            hButton.Position = [xi y wi h];
            hButton.Text = '';
            hButton.Icon = nansen.internal.getIconPathName('ellipsis.png');
            hButton.ButtonPushedFcn = @obj.onEditDaqSystemButtonPushed;
        end

        function bButton = createAddRowButton(obj, rowIdx, columnIdx)
        % createSubfolderTypeSelectionDropdown - Create dropdown for selecting subfolder type
            [xi, y, wi, h] = obj.getCellPosition(rowIdx, columnIdx);
            bButton = uibutton(obj.TablePanel);
            bButton.Position = [xi y wi h];
            bButton.Text = '';
            bButton.Icon = nansen.internal.getIconPathName('plus.png');
            bButton.ButtonPushedFcn = @obj.onAddDaqSystemButtonPushed;
            bButton.Enable = 'off';
        end
    end
end