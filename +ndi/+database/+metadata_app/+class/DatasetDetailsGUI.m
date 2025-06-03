classdef DatasetDetailsGUI < handle
    %DATASETDETAILSGUI Manages UI for the Dataset Details tab.

    properties (Access = public)
        ParentApp % Handle to the MetadataEditorApp instance
        UIBaseContainer % Parent uicontainer for this GUI's elements
        
        % UI Components for Accessibility & Versioning
        ReleaseDateDatePicker matlab.ui.control.DatePicker
        LicenseDropDown matlab.ui.control.DropDown
        LicenseHelpButton matlab.ui.control.Button
        FullDocumentationEditField matlab.ui.control.EditField
        VersionIdentifierEditField matlab.ui.control.EditField
        VersionInnovationEditField matlab.ui.control.EditField

        % Labels for Accessibility & Versioning
        AccessibilityLabel matlab.ui.control.Label
        ReleaseDateDatePickerLabel matlab.ui.control.Label
        LicenseDropDownLabel matlab.ui.control.Label
        FullDocumentationEditFieldLabel matlab.ui.control.Label
        VersionIdentifierEditFieldLabel matlab.ui.control.Label
        VersionInnovationEditFieldLabel matlab.ui.control.Label

        % UI Components for Funding
        FundingUITable matlab.ui.control.Table
        AddFundingButton matlab.ui.control.Button
        RemoveFundingButton matlab.ui.control.Button
        MoveFundingUpButton matlab.ui.control.Button
        MoveFundingDownButton matlab.ui.control.Button
        FundingUITableLabel matlab.ui.control.Label
        
        % UI Components for Related Publications
        RelatedPublicationUITable matlab.ui.control.Table
        AddRelatedPublicationButton matlab.ui.control.Button
        RemovePublicationButton matlab.ui.control.Button
        MovePublicationUpButton matlab.ui.control.Button
        MovePublicationDownButton matlab.ui.control.Button
        RelatedPublicationUITableLabel matlab.ui.control.Label
    end

    properties (Access = private)
        ResourcesPath % Path to resources, e.g., for icons
    end

    methods
        function obj = DatasetDetailsGUI(parentAppHandle, uiParentContainer)
            obj.ParentApp = parentAppHandle;
            obj.UIBaseContainer = uiParentContainer;

            if isprop(obj.ParentApp, 'ResourcesPath') && isfolder(obj.ParentApp.ResourcesPath)
                obj.ResourcesPath = obj.ParentApp.ResourcesPath;
            else
                guiFilePath = fileparts(mfilename('fullpath'));
                obj.ResourcesPath = fullfile(guiFilePath, '..', '+Apps', 'resources');
            end
            
            obj.createDatasetDetailsUIComponents();
        end

        function initialize(obj)
            % Set up callbacks for all managed UI components
            obj.ReleaseDateDatePicker.ValueChangedFcn = @(~,event) obj.releaseDateValueChanged(event);
            obj.LicenseDropDown.ValueChangedFcn = @(~,event) obj.licenseDropDownValueChanged(event);
            obj.LicenseHelpButton.ButtonPushedFcn = @(~,event) obj.licenseHelpButtonPushed(event);
            obj.FullDocumentationEditField.ValueChangedFcn = @(~,event) obj.fullDocumentationValueChanged(event);
            obj.VersionIdentifierEditField.ValueChangedFcn = @(~,event) obj.versionIdentifierValueChanged(event);
            obj.VersionInnovationEditField.ValueChangedFcn = @(~,event) obj.versionInnovationValueChanged(event);

            obj.AddFundingButton.ButtonPushedFcn = @(~,event) obj.addFundingButtonPushed(event);
            obj.RemoveFundingButton.ButtonPushedFcn = @(~,event) obj.removeFundingButtonPushed(event);
            % Add MoveUp/Down funding callbacks if implemented
            if isprop(obj,'MoveFundingUpButton'), obj.MoveFundingUpButton.ButtonPushedFcn = @(~,event) obj.moveFundingPushed('Funding', 'up'); end
            if isprop(obj,'MoveFundingDownButton'), obj.MoveFundingDownButton.ButtonPushedFcn = @(~,event) obj.moveFundingPushed('Funding', 'down'); end


            obj.AddRelatedPublicationButton.ButtonPushedFcn = @(~,event) obj.addRelatedPublicationButtonPushed(event);
            obj.RemovePublicationButton.ButtonPushedFcn = @(~,event) obj.removePublicationButtonPushed(event);
            % Add MoveUp/Down publication callbacks if implemented
            if isprop(obj,'MovePublicationUpButton'), obj.MovePublicationUpButton.ButtonPushedFcn = @(~,event) obj.movePublicationPushed('Publication', 'up'); end
            if isprop(obj,'MovePublicationDownButton'), obj.MovePublicationDownButton.ButtonPushedFcn = @(~,event) obj.movePublicationPushed('Publication', 'down'); end
            
            if isprop(obj,'FundingUITable'), obj.FundingUITable.CellEditCallback = @(src,event) obj.fundingTableCellEdited(event); end % If direct edit is allowed
            if isprop(obj,'FundingUITable'), obj.FundingUITable.CellSelectionCallback = @(src,event) obj.tableCellSelected(src,event,'Funding'); end

            if isprop(obj,'RelatedPublicationUITable'), obj.RelatedPublicationUITable.CellEditCallback = @(src,event) obj.publicationTableCellEdited(event); end
            if isprop(obj,'RelatedPublicationUITable'), obj.RelatedPublicationUITable.CellSelectionCallback = @(src,event) obj.tableCellSelected(src,event,'Publication'); end


            obj.populateLicenseDropdown();
            obj.drawDatasetDetails(); % Initial population of UI from data
        end

        function createDatasetDetailsUIComponents(obj)
            parent = obj.UIBaseContainer; % This is app.DatasetDetailsPanel
            iconsPath = fullfile(obj.ResourcesPath, 'icons');

            % Main grid within the panel (was GridLayout18 in MetadataEditorApp)
            mainGrid = uigridlayout(parent, [2 1], 'RowHeight', {'fit', '1x'}, 'Padding', [10 10 10 10], 'RowSpacing', 15); % Adjusted padding

            % Top part: Accessibility and Funding (was GridLayout19)
            topPartGrid = uigridlayout(mainGrid); 
            topPartGrid.Layout.Row = 1; topPartGrid.Layout.Column = 1;
            topPartGrid.ColumnWidth = {'1x', '1x'}; topPartGrid.ColumnSpacing = 20;

            % --- Accessibility Section (was GridLayout22) ---
            accessibilityGrid = uigridlayout(topPartGrid);
            accessibilityGrid.Layout.Row = 1; accessibilityGrid.Layout.Column = 1;
            accessibilityGrid.ColumnWidth = {'fit', '1x'}; accessibilityGrid.RowHeight = {23, 23, 23, 23, 23, 23};
            accessibilityGrid.RowSpacing = 5; accessibilityGrid.ColumnSpacing = 10;

            obj.AccessibilityLabel = uilabel(accessibilityGrid, 'Text', 'Accessibility & Versioning', 'FontWeight', 'bold');
            obj.AccessibilityLabel.Layout.Row=1; obj.AccessibilityLabel.Layout.Column=[1,2]; % Span columns

            obj.ReleaseDateDatePickerLabel = uilabel(accessibilityGrid, 'Text', 'Release Date', 'HorizontalAlignment', 'right');
            obj.ReleaseDateDatePickerLabel.Layout.Row=2; obj.ReleaseDateDatePickerLabel.Layout.Column=1;
            obj.ReleaseDateDatePicker = uidatepicker(accessibilityGrid);
            obj.ReleaseDateDatePicker.Layout.Row=2; obj.ReleaseDateDatePicker.Layout.Column=2;

            obj.LicenseDropDownLabel = uilabel(accessibilityGrid, 'Text', 'License (*)', 'HorizontalAlignment', 'right');
            obj.LicenseDropDownLabel.Layout.Row=3; obj.LicenseDropDownLabel.Layout.Column=1;
            licenseHelpGrid = uigridlayout(accessibilityGrid); 
            licenseHelpGrid.Layout.Row=3; licenseHelpGrid.Layout.Column=2;
            licenseHelpGrid.ColumnWidth = {'1x',25}; licenseHelpGrid.Padding = [0 0 0 0]; licenseHelpGrid.RowHeight = {'fit'};
            obj.LicenseDropDown = uidropdown(licenseHelpGrid);
            obj.LicenseDropDown.Layout.Row=1; obj.LicenseDropDown.Layout.Column=1;
            obj.LicenseHelpButton = uibutton(licenseHelpGrid, 'push', 'Text', '', 'Icon', fullfile(iconsPath, 'help.png'));
            obj.LicenseHelpButton.Layout.Row=1; obj.LicenseHelpButton.Layout.Column=2;

            obj.FullDocumentationEditFieldLabel = uilabel(accessibilityGrid, 'Text', 'Full Documentation', 'HorizontalAlignment', 'right');
            obj.FullDocumentationEditFieldLabel.Layout.Row=4; obj.FullDocumentationEditFieldLabel.Layout.Column=1;
            obj.FullDocumentationEditField = uieditfield(accessibilityGrid, 'text');
            obj.FullDocumentationEditField.Layout.Row=4; obj.FullDocumentationEditField.Layout.Column=2;

            obj.VersionIdentifierEditFieldLabel = uilabel(accessibilityGrid, 'Text', 'Version Identifier (*)', 'HorizontalAlignment', 'right');
            obj.VersionIdentifierEditFieldLabel.Layout.Row=5; obj.VersionIdentifierEditFieldLabel.Layout.Column=1;
            obj.VersionIdentifierEditField = uieditfield(accessibilityGrid, 'text');
            obj.VersionIdentifierEditField.Layout.Row=5; obj.VersionIdentifierEditField.Layout.Column=2;

            obj.VersionInnovationEditFieldLabel = uilabel(accessibilityGrid, 'Text', 'Version Innovation', 'HorizontalAlignment', 'right');
            obj.VersionInnovationEditFieldLabel.Layout.Row=6; obj.VersionInnovationEditFieldLabel.Layout.Column=1;
            obj.VersionInnovationEditField = uieditfield(accessibilityGrid, 'text');
            obj.VersionInnovationEditField.Layout.Row=6; obj.VersionInnovationEditField.Layout.Column=2;

            % --- Funding Section (was FundingGridLayout) ---
            obj.FundingGridLayout = uigridlayout(topPartGrid); 
            obj.FundingGridLayout.Layout.Row=1; obj.FundingGridLayout.Layout.Column=2;
            obj.FundingGridLayout.ColumnWidth = {'1x', 40}; 
            obj.FundingGridLayout.RowHeight = {23, '1x'};
            obj.FundingGridLayout.RowSpacing = 5;

            obj.FundingUITableLabel = uilabel(obj.FundingGridLayout, 'Text', 'Funding', 'FontWeight', 'bold');
            obj.FundingUITableLabel.Layout.Row=1; obj.FundingUITableLabel.Layout.Column=1;
            obj.FundingUITable = uitable(obj.FundingGridLayout, 'ColumnName', {'Funder'; 'Award Title'; 'Award ID'}, 'RowName', {});
            obj.FundingUITable.Layout.Row=2; obj.FundingUITable.Layout.Column=1;
            
            fundingButtonsGrid = uigridlayout(obj.FundingGridLayout);
            fundingButtonsGrid.Layout.Row=2; fundingButtonsGrid.Layout.Column=2;
            fundingButtonsGrid.RowHeight={'fit','fit',10,'fit','fit','1x'}; fundingButtonsGrid.ColumnWidth={'1x'}; fundingButtonsGrid.Padding = [0 0 0 0]; fundingButtonsGrid.RowSpacing = 5;
            obj.AddFundingButton = uibutton(fundingButtonsGrid, 'push', 'Text', '', 'Icon', fullfile(iconsPath, 'plus.png'));
            obj.AddFundingButton.Layout.Row=1; obj.AddFundingButton.Layout.Column=1;
            obj.RemoveFundingButton = uibutton(fundingButtonsGrid, 'push', 'Text', '', 'Icon', fullfile(iconsPath, 'minus.png'));
            obj.RemoveFundingButton.Layout.Row=2; obj.RemoveFundingButton.Layout.Column=1;
            obj.MoveFundingUpButton = uibutton(fundingButtonsGrid, 'push', 'Text', '', 'Icon', fullfile(iconsPath, 'up.png'));
            obj.MoveFundingUpButton.Layout.Row=4; obj.MoveFundingUpButton.Layout.Column=1; 
            obj.MoveFundingDownButton = uibutton(fundingButtonsGrid, 'push', 'Text', '', 'Icon', fullfile(iconsPath, 'down.png'));
            obj.MoveFundingDownButton.Layout.Row=5; obj.MoveFundingDownButton.Layout.Column=1;

            % --- Bottom part: Related Publications (was GridLayout20) ---
            obj.GridLayout20 = uigridlayout(mainGrid); 
            obj.GridLayout20.Layout.Row=2; obj.GridLayout20.Layout.Column=1;
            obj.GridLayout20.ColumnWidth = {'1x', 40}; 
            obj.GridLayout20.RowHeight = {23, '1x'};
            obj.GridLayout20.RowSpacing = 5;

            obj.RelatedPublicationUITableLabel = uilabel(obj.GridLayout20, 'Text', 'Related Publications', 'FontWeight', 'bold');
            obj.RelatedPublicationUITableLabel.Layout.Row=1; obj.RelatedPublicationUITableLabel.Layout.Column=1;
            obj.RelatedPublicationUITable = uitable(obj.GridLayout20, 'ColumnName', {'Publication (e.g., Title, Journal)'; 'DOI'; 'PMID'; 'PMCID'}, 'RowName', {});
            obj.RelatedPublicationUITable.Layout.Row=2; obj.RelatedPublicationUITable.Layout.Column=1;
            
            publicationButtonsGrid = uigridlayout(obj.GridLayout20);
            publicationButtonsGrid.Layout.Row=2; publicationButtonsGrid.Layout.Column=2;
            publicationButtonsGrid.RowHeight={'fit','fit',10,'fit','fit','1x'}; publicationButtonsGrid.ColumnWidth={'1x'}; publicationButtonsGrid.Padding = [0 0 0 0]; publicationButtonsGrid.RowSpacing = 5;
            obj.AddRelatedPublicationButton = uibutton(publicationButtonsGrid, 'push', 'Text', '', 'Icon', fullfile(iconsPath, 'plus.png'));
            obj.AddRelatedPublicationButton.Layout.Row=1; obj.AddRelatedPublicationButton.Layout.Column=1;
            obj.RemovePublicationButton = uibutton(publicationButtonsGrid, 'push', 'Text', '', 'Icon', fullfile(iconsPath, 'minus.png'));
            obj.RemovePublicationButton.Layout.Row=2; obj.RemovePublicationButton.Layout.Column=1;
            obj.MovePublicationUpButton = uibutton(publicationButtonsGrid, 'push', 'Text', '', 'Icon', fullfile(iconsPath, 'up.png'));
            obj.MovePublicationUpButton.Layout.Row=4; obj.MovePublicationUpButton.Layout.Column=1; 
            obj.MovePublicationDownButton = uibutton(publicationButtonsGrid, 'push', 'Text', '', 'Icon', fullfile(iconsPath, 'down.png'));
            obj.MovePublicationDownButton.Layout.Row=5; obj.MovePublicationDownButton.Layout.Column=1;
        end

        function drawDatasetDetails(obj)
            fprintf('DEBUG (DatasetDetailsGUI): Drawing Dataset Details UI.\n');
            dsStruct = obj.ParentApp.DatasetInformationStruct;

            obj.ReleaseDateDatePicker.Value = ifthenelse(isfield(dsStruct, 'ReleaseDate') && ~isempty(dsStruct.ReleaseDate) && isdatetime(dsStruct.ReleaseDate) && ~isnat(dsStruct.ReleaseDate), dsStruct.ReleaseDate, NaT);
            obj.LicenseDropDown.Value = ifthenelse(isfield(dsStruct, 'License'), dsStruct.License, obj.LicenseDropDown.ItemsData{1}); % Default to first valid, or placeholder
            obj.FullDocumentationEditField.Value = ifthenelse(isfield(dsStruct, 'FullDocumentation'), dsStruct.FullDocumentation, '');
            obj.VersionIdentifierEditField.Value = ifthenelse(isfield(dsStruct, 'VersionIdentifier'), dsStruct.VersionIdentifier, '1.0.0');
            obj.VersionInnovationEditField.Value = ifthenelse(isfield(dsStruct, 'VersionInnovation'), dsStruct.VersionInnovation, 'This is the first version of the dataset');

            if isfield(dsStruct, 'Funding') && (isstruct(dsStruct.Funding) || istable(dsStruct.Funding)) && ~isempty(dsStruct.Funding)
                if istable(dsStruct.Funding)
                    obj.FundingUITable.Data = dsStruct.Funding;
                else
                    obj.FundingUITable.Data = struct2table(dsStruct.Funding, 'AsArray',true);
                end
            else
                obj.FundingUITable.Data = table([],[],[], 'VariableNames', {'funder','awardTitle','awardNumber'});
            end

            if isfield(dsStruct, 'RelatedPublication') && (isstruct(dsStruct.RelatedPublication) || istable(dsStruct.RelatedPublication)) && ~isempty(dsStruct.RelatedPublication)
                 if istable(dsStruct.RelatedPublication)
                    obj.RelatedPublicationUITable.Data = dsStruct.RelatedPublication;
                 else
                    obj.RelatedPublicationUITable.Data = struct2table(dsStruct.RelatedPublication, 'AsArray',true);
                 end
            else
                obj.RelatedPublicationUITable.Data = table([],[],[],[], 'VariableNames',  {'title','doi','pmid','pmcid'});
            end
        end
        
        function populateLicenseDropdown(obj)
            [names, shortNames] = ndi.database.metadata_app.fun.getCCByLicences();
            obj.LicenseDropDown.Items = ["Select a License"; shortNames];
            obj.LicenseDropDown.ItemsData = [""; names];
            if ~isempty(obj.LicenseDropDown.ItemsData) && strcmp(obj.LicenseDropDown.ItemsData{1},"") && numel(obj.LicenseDropDown.ItemsData) > 1
                obj.LicenseDropDown.Value = obj.LicenseDropDown.ItemsData{2}; % Default to first actual license
            elseif ~isempty(obj.LicenseDropDown.ItemsData)
                 obj.LicenseDropDown.Value = obj.LicenseDropDown.ItemsData{1};
            end
        end

        % --- Callbacks ---
        function releaseDateValueChanged(obj, event)
            obj.ParentApp.DatasetInformationStruct.ReleaseDate = obj.ReleaseDateDatePicker.Value;
            obj.ParentApp.saveDatasetInformationStruct();
        end

        function licenseDropDownValueChanged(obj, event)
            obj.ParentApp.DatasetInformationStruct.License = obj.LicenseDropDown.Value;
            if obj.LicenseDropDown.Value ~= ""
                obj.ParentApp.resetLabelForRequiredField('License'); % Conceptual name
            end
            obj.ParentApp.saveDatasetInformationStruct();
        end

        function licenseHelpButtonPushed(obj, event)
            web("https://creativecommons.org/licenses/");
        end

        function fullDocumentationValueChanged(obj, event)
            value = obj.FullDocumentationEditField.Value;
             if ~isempty(value) && ~(startsWith(value, 'http') || contains(value, 'doi.org'))
                 obj.ParentApp.alert('Full documentation should be a valid URL or DOI.', 'Invalid Input');
             else
                obj.ParentApp.DatasetInformationStruct.FullDocumentation = value;
                obj.ParentApp.saveDatasetInformationStruct();
             end
        end
        
        function versionIdentifierValueChanged(obj, event)
            obj.ParentApp.DatasetInformationStruct.VersionIdentifier = obj.VersionIdentifierEditField.Value;
            if ~isempty(obj.VersionIdentifierEditField.Value)
                 obj.ParentApp.resetLabelForRequiredField('VersionIdentifier'); % Conceptual name
            end
            obj.ParentApp.saveDatasetInformationStruct();
        end

        function versionInnovationValueChanged(obj, event)
            obj.ParentApp.DatasetInformationStruct.VersionInnovation = obj.VersionInnovationEditField.Value;
            obj.ParentApp.saveDatasetInformationStruct();
        end

        function addFundingButtonPushed(obj, event)
            S_funding = obj.ParentApp.openFundingForm(); % ParentApp handles form opening
            if ~isempty(S_funding)
                if ~isfield(obj.ParentApp.DatasetInformationStruct, 'Funding') || isempty(obj.ParentApp.DatasetInformationStruct.Funding)
                    obj.ParentApp.DatasetInformationStruct.Funding = S_funding;
                else
                    obj.ParentApp.DatasetInformationStruct.Funding(end+1) = S_funding;
                end
                obj.FundingUITable.Data = struct2table(obj.ParentApp.DatasetInformationStruct.Funding, 'AsArray', true);
                obj.ParentApp.saveDatasetInformationStruct();
            end
        end
        
        function removeFundingButtonPushed(obj, event)
            selection = obj.FundingUITable.Selection;
            if ~isempty(selection)
                obj.FundingUITable.Data(selection(1),:) = []; % Remove first selected row
                obj.ParentApp.DatasetInformationStruct.Funding = table2struct(obj.FundingUITable.Data);
                if isempty(obj.ParentApp.DatasetInformationStruct.Funding) % Ensure it's 0x1 struct with fields if empty
                    obj.ParentApp.DatasetInformationStruct.Funding = repmat(struct('funder','','awardTitle','','awardNumber',''),0,1);
                end
                obj.ParentApp.saveDatasetInformationStruct();
            else
                obj.ParentApp.inform('Select a funding entry to remove.', 'No Selection');
            end
        end
        
        function addRelatedPublicationButtonPushed(obj, event)
            S_pub = obj.ParentApp.openForm("Publication"); % ParentApp handles form opening
            if ~isempty(S_pub)
                if ~isfield(obj.ParentApp.DatasetInformationStruct, 'RelatedPublication') || isempty(obj.ParentApp.DatasetInformationStruct.RelatedPublication)
                    obj.ParentApp.DatasetInformationStruct.RelatedPublication = S_pub;
                else
                    obj.ParentApp.DatasetInformationStruct.RelatedPublication(end+1) = S_pub;
                end
                obj.RelatedPublicationUITable.Data = struct2table(obj.ParentApp.DatasetInformationStruct.RelatedPublication, 'AsArray', true);
                obj.ParentApp.saveDatasetInformationStruct();
            end
        end

        function removePublicationButtonPushed(obj, event)
            selection = obj.RelatedPublicationUITable.Selection;
            if ~isempty(selection)
                obj.RelatedPublicationUITable.Data(selection(1),:) = [];
                obj.ParentApp.DatasetInformationStruct.RelatedPublication = table2struct(obj.RelatedPublicationUITable.Data);
                 if isempty(obj.ParentApp.DatasetInformationStruct.RelatedPublication) % Ensure it's 0x1 struct with fields if empty
                    obj.ParentApp.DatasetInformationStruct.RelatedPublication = repmat(struct('title','','doi','','pmid','','pmcid',''),0,1);
                 end
                obj.ParentApp.saveDatasetInformationStruct();
            else
                obj.ParentApp.inform('Select a publication to remove.', 'No Selection');
            end
        end

        function moveFundingPushed(obj, tableType, direction)
            % Generic move for Funding or Publication
            uit = obj.FundingUITable;
            fieldName = 'Funding';
            
            selection = uit.Selection;
            if isempty(selection) || numel(selection) > 1, return; end
            
            data = obj.ParentApp.DatasetInformationStruct.(fieldName);
            n = numel(data);
            
            if strcmp(direction,'up') && selection > 1
                swapIdx = [selection-1, selection];
            elseif strcmp(direction,'down') && selection < n
                swapIdx = [selection, selection+1];
            else
                return; % Cannot move further
            end
            
            data(swapIdx([2,1])) = data(swapIdx); % Swap elements
            obj.ParentApp.DatasetInformationStruct.(fieldName) = data;
            obj.drawDatasetDetails(); % Redraw to reflect change
            uit.Selection = swapIdx(1); % Re-select the moved item at its new position
            obj.ParentApp.saveDatasetInformationStruct();
        end
        
         function movePublicationPushed(obj, tableType, direction)
            uit = obj.RelatedPublicationUITable;
            fieldName = 'RelatedPublication';
            
            selection = uit.Selection;
            if isempty(selection) || numel(selection) > 1, return; end
            
            data = obj.ParentApp.DatasetInformationStruct.(fieldName);
            n = numel(data);
            
            if strcmp(direction,'up') && selection > 1
                swapIdx = [selection-1, selection];
            elseif strcmp(direction,'down') && selection < n
                swapIdx = [selection, selection+1];
            else
                return; 
            end
            
            data(swapIdx([2,1])) = data(swapIdx);
            obj.ParentApp.DatasetInformationStruct.(fieldName) = data;
            obj.drawDatasetDetails();
            uit.Selection = swapIdx(1);
            obj.ParentApp.saveDatasetInformationStruct();
        end


        function fundingTableCellEdited(obj, event)
            % If direct table editing for Funding is allowed
            indices = event.Indices;
            row = indices(1);
            col = indices(2);
            newValue = event.NewData;
            
            % Update the DatasetInformationStruct.Funding
            currentFunding = obj.ParentApp.DatasetInformationStruct.Funding;
            columnNames = obj.FundingUITable.ColumnName;
            fieldToUpdate = columnNames{col};
            
            currentFunding(row).(fieldToUpdate) = newValue;
            obj.ParentApp.DatasetInformationStruct.Funding = currentFunding;
            obj.ParentApp.saveDatasetInformationStruct();
            fprintf('DEBUG (DatasetDetailsGUI): Funding table cell [%d, %d] edited to "%s".\n', row, col, string(newValue));
        end
        
        function publicationTableCellEdited(obj, event)
            % If direct table editing for Publications is allowed
            indices = event.Indices;
            row = indices(1);
            col = indices(2);
            newValue = event.NewData;

            currentPubs = obj.ParentApp.DatasetInformationStruct.RelatedPublication;
            columnNames = obj.RelatedPublicationUITable.ColumnName;
            fieldToUpdate = columnNames{col};

            currentPubs(row).(fieldToUpdate) = newValue;
            obj.ParentApp.DatasetInformationStruct.RelatedPublication = currentPubs;
            obj.ParentApp.saveDatasetInformationStruct();
            fprintf('DEBUG (DatasetDetailsGUI): Publication table cell [%d, %d] edited to "%s".\n', row, col, string(newValue));
        end
        
        function tableCellSelected(obj, src, event, tableName)
            % Handle cell selection for enabling/disabling move buttons
            % For now, this is a placeholder. Actual button enabling/disabling
            % would be based on selection and position in list.
            % Example:
            % selection = src.Selection;
            % if ~isempty(selection)
            %    if strcmp(tableName, 'Funding')
            %        % obj.MoveFundingUpButton.Enable = selection(1) > 1;
            %        % obj.MoveFundingDownButton.Enable = selection(1) < size(src.Data,1);
            %    end
            % end
        end


        % --- Getter Methods for buildDatasetInformationStructFromApp ---
        function val = getReleaseDate(obj), val = obj.ReleaseDateDatePicker.Value; end
        function val = getLicense(obj), val = obj.LicenseDropDown.Value; end
        function val = getFullDocumentation(obj), val = obj.FullDocumentationEditField.Value; end
        function val = getVersionIdentifier(obj), val = obj.VersionIdentifierEditField.Value; end
        function val = getVersionInnovation(obj), val = obj.VersionInnovationEditField.Value; end
        function val = getFundingInfo(obj)
            if isempty(obj.FundingUITable.Data)
                 val = repmat(struct('funder','','awardTitle','','awardNumber',''),0,1);
            else
                val = table2struct(obj.FundingUITable.Data);
            end
        end
        function val = getRelatedPublications(obj)
            if isempty(obj.RelatedPublicationUITable.Data)
                val = repmat(struct('title','','doi','','pmid','','pmcid',''),0,1);
            else
                val = table2struct(obj.RelatedPublicationUITable.Data);
            end
        end

        % --- Setter Methods for populateAppFromDatasetInformationStruct ---
        % These are largely handled by drawDatasetDetails, but specific setters can be added if needed.
        % For example, if a field needs special processing before UI update.
        % For now, drawDatasetDetails covers these.
        
        % --- Required Field Checks ---
        function missingFields = checkRequiredFields(obj)
            missingFields = string.empty(0,1);
            if isempty(obj.LicenseDropDown.Value) || strcmp(obj.LicenseDropDown.Value, "")
                missingFields(end+1) = "License";
            end
            if isempty(strtrim(obj.VersionIdentifierEditField.Value))
                missingFields(end+1) = "Version Identifier";
            end
            % Add more checks as needed for this tab
        end

        function markRequiredFields(obj)
            requiredFields = ndi.database.metadata_app.fun.getRequiredFields();
            requiredSymbol = '*';
            
            if isfield(requiredFields, 'License') && requiredFields.License
                if ~contains(obj.LicenseDropDownLabel.Text, requiredSymbol)
                    obj.LicenseDropDownLabel.Text = [obj.LicenseDropDownLabel.Text ' ' requiredSymbol];
                end
                 obj.LicenseDropDownLabel.Tooltip = "Required";
            end
            if isfield(requiredFields, 'VersionIdentifier') && requiredFields.VersionIdentifier
                 if ~contains(obj.VersionIdentifierEditFieldLabel.Text, requiredSymbol)
                    obj.VersionIdentifierEditFieldLabel.Text = [obj.VersionIdentifierEditFieldLabel.Text ' ' requiredSymbol];
                end
                obj.VersionIdentifierEditFieldLabel.Tooltip = "Required";
            end
        end

    end
end

% Helper function for conditional assignment (inline if-else)
function result = ifthenelse(condition, trueval, falseval)
    if condition
        result = trueval;
    else
        result = falseval;
    end
end
