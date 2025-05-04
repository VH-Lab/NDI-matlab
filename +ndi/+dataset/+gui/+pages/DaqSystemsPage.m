classdef DaqSystemsPage < ndi.gui.window.wizard.abstract.Page

    % Setting pagedata shouls update the widgets table..
    
    % Todo: Create the uiwidget table...
    % Add listeners for cell edited, row added and row removed.

    % Responsibility:
    %   Update widget from data
    %   Update data from widget

    properties (Constant)
        Name = "DAQ Systems"
        Title = "DAQ Systems"
        Description = "Select DAQ Systems for your dataset"
    end
    
    properties (Access = private)
        Widget % Todo: UITable?
        TableGridLayout
    end
    
    properties (SetAccess = ?ndi.gui.window.wizard.WizardApp)
        PageData ndi.dataset.gui.models.DaqSystemCollection
    end

    properties %(Dependent)
        EditDaqSystemFcn
    end

    events
        %UserAction
    end

    methods
        function obj = DaqSystemsPage()

        end
    end

    methods
        function set.PageData(obj, value)
            obj.PageData = value;
            obj.postSetPageData()
        end

        function set.EditDaqSystemFcn(obj, value)
            obj.EditDaqSystemFcn = value;
        end

        function value = get.EditDaqSystemFcn(obj)
            value = obj.EditDaqSystemFcn;
        end
    end

    methods (Access = protected)
        function onPageEntered(obj)
            % Subclasses may override
        end

        function onPageExited(obj)
            % Subclasses may override
        end

        function createComponents(obj)            
            obj.TableGridLayout = uigridlayout(obj.UIPanel);
            obj.TableGridLayout.ColumnWidth={'1x'};
            obj.TableGridLayout.RowHeight={'1x'};
            obj.TableGridLayout.Padding = [20,0,20,0];
            obj.TableGridLayout.BackgroundColor = 'w';

            customColumnFcn = @(h, varargin) ...
                ndi.dataset.gui.pages.component.DAQSystemEditButtons(h, ...
                    'ButtonPushedFcn', @obj.onDaqSystemActionButtonPushed);

            obj.Widget = WidgetTable(obj.TableGridLayout, 'ItemName', 'DAQ System Configuration');
            obj.Widget.HeaderBackgroundColor = "#FFFFFF";
            obj.Widget.HeaderForegroundColor = "#002054";
            obj.Widget.BackgroundColor = 'w';
            obj.Widget.ColumnNames = {'DAQ system type', 'DAQ System Name', 'DAQ reader', ''};
            obj.Widget.ColumnWidth = {185, 175, 150, 100};
            obj.Widget.ColumnWidget = {'', '', '', customColumnFcn};
            obj.Widget.TableBorderType = 'none';
            obj.Widget.MinimumColumnWidth = 120;            
            
            if isempty(obj.PageData) || isempty(obj.PageData.DaqSystems)
                % Set DefaultRowData if PageData is empty..
                tbl = obj.getDefaultDAQConfigTable();
                obj.Widget.setDefaultRowData(tbl);
            else
                tbl = obj.convertDaqSystemObjectToTable(obj.PageData.DaqSystems);
                obj.Widget.Data = tbl;
            end

            % Set callbacks...
            obj.Widget.RowAddedFcn = @obj.onDAQSystemAdded;
            obj.Widget.RowRemovedFcn = @obj.onDAQSystemRemoved;
            obj.Widget.CellEditedFcn = @obj.onTableCellValueChanged;

            %obj.Widget.EditDaqSystemButtonPushedFcn = @obj.onEditDaqSystemButtonPushed;
        end
    end

    methods (Access = private)
        function onDaqSystemActionButtonPushed(obj, src, evt)
            rowIndex = src.Parent.Layout.Row;
            
            switch evt.UserAction
                case 'Load'
                    [fileName, folder] = uigetfile('*.json');
                    if fileName==0
                        return
                    end

                    obj.PageData.DaqSystems(rowIndex) = ...
                        ndi.setup.DaqSystemConfiguration.fromConfigFile(fullfile(folder, fileName));
                    newValue = obj.PageData.DaqSystems(rowIndex).Name;
                    obj.Widget.updateCellValue(rowIndex, 2, char(newValue))
                    
                case 'Edit'
                    if ~isempty(obj.EditDaqSystemFcn)
                        daqSystem = obj.PageData.DaqSystems(rowIndex);
                        updateDaqSystem = obj.EditDaqSystemFcn(daqSystem);

                        obj.PageData.DaqSystems(rowIndex) = updateDaqSystem;
                        newValue = obj.PageData.DaqSystems(rowIndex).Name;
                        % Todo: Categoricals should dynamically update.
                        % What about dropdown items...?
                        obj.Widget.updateCellValue(rowIndex, 2, char(newValue))
                    end
            end

            % disp(rowIndex)

            % Todo: Get rowdata and rowIndex and add to event data...
            % obj.notify('UserAction', evt); % Todo: use event?
        end

        function onTableCellValueChanged(obj, src, evt)
            
            switch evt.Indices(2)
                case 1 % DAQ System type

                    daqSystemNames = obj.getDaqSystemsForType(evt.NewData);
                    names = [{'<Select DAQ System>', '<Load from File...>'}, daqSystemNames];

                    dependentData = categorical(names(1), names);
                    src.updateCellValue(evt.Indices(1), 2, dependentData)

                case 2 % DAQ system name
                    idx = evt.Indices(1);

                    if strcmp(char(evt.NewData), '<Load from File...>')
                        [fileName, folder] = uigetfile('*.json');
                        if fileName==0
                            newValue = '<Select DAQ System>';
                            src.updateCellValue(evt.Indices(1), 2, newValue)
                        else
                            obj.PageData.DaqSystems(idx) = ...
                                ndi.setup.DaqSystemConfiguration.fromConfigFile(fullfile(folder, fileName));
                            newValue = obj.PageData.DaqSystems(idx).Name;
                            src.updateCellValue(evt.Indices(1), 2, char(newValue))
                        end
                    elseif strcmp(char(evt.NewData), '<Select DAQ System>')
                        %pass. Todo: reset

                    else
                         obj.PageData.DaqSystems(idx) = ...
                             ndi.setup.DaqSystemConfiguration.fromDeviceName(evt.NewData);
                    end


                    % Load daq system from file...
           
                    % Todo: Update daqreader?
            end
        end

        function onDAQSystemAdded(obj, srv, evt)
            obj.PageData.DaqSystems(evt.RowIndex) = ndi.setup.DaqSystemConfiguration();
        end

        function onDAQSystemRemoved(obj, srv, evt)
            obj.PageData.DaqSystems(evt.RowIndex) = [];
        end

        function postSetPageData(obj)
        end
    end

    methods (Static)
        function daqData = getDefaultDAQConfigTable()
            
            daqData = struct(...
	            'DAQSystemType', "EPhys", ...
                'Name', "", ...
    	        'DAQReader', "n-trode", ...
                'Edit', true);
        
            %todo
            daqSystemTypes = {...
                '<Select DAQ System Type>', ...
                'Multifunction DAQ', ...
                '2-Photon-Microscope', ...
                'Electrophysiology'};
            
            [daqSystemNames, fileNames] = ndi.setup.daq.system.listDaqSystemNames();
            names = [{'<Select DAQ System>', '<Load from File...>'}, daqSystemNames];

            daqData.Name = categorical(names(1), names);
            daqData.DAQSystemType = categorical({'<Select DAQ System Type>'}, daqSystemTypes);
        
            % Todo: filter by DAQSystemType
            daqReaderTypes = ndi.setup.daq.listDaqReaders();
            daqData.DAQReader = categorical(daqReaderTypes(1), daqReaderTypes);
        
            daqData = struct2table(daqData, "AsArray", true);
        end

        function daqSystemNames = getDaqSystemsForType(typeName)
            % Todo: Should be accessible / easy access for editing
            switch typeName
                case '<Select DAQ System Type>'
                    daqSystemNames = ...
                        ndi.setup.daq.system.listDaqSystemNames();

                case '2-Photon-Microscope'
                    daqSystemNames = {'ScanImage', 'PrairieView'};

                case 'Multifunction DAQ'
                    daqSystemNames = {};

                case 'Electrophysiology'
                    daqSystemNames = ...
                        ndi.setup.daq.system.listDaqSystemNames();
            end
        end

        function tbl = convertDaqSystemObjectToTable(daqSystemConfig)
            tbl = ndi.dataset.gui.pages.DaqSystemsPage.getDefaultDAQConfigTable();

            numItems = numel(daqSystemConfig);
            tbl = repmat(tbl, numItems, 1);

            [daqReaderTypes, ~, fcnNames] = ndi.setup.daq.listDaqReaders();

            for i = 1:numItems
                if daqSystemConfig(i).Name == ""
                    tbl{i, "Name"} = "<Select DAQ System>";
                else
                    tbl{i, "Name"} = daqSystemConfig(i).Name;
                end

                % Match daq reader short names and fullnames?
                isMatch = strcmp(daqSystemConfig(i).DaqReaderClass, fcnNames);
                tbl{i, "DAQReader"} = daqReaderTypes(isMatch);

                %todo: set type...
            end
        end
    end
end