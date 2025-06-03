classdef DatasetDetailsGUI < handle
    %DATASETDETAILSGUI Manages UI for the Dataset Details tab.
    properties (Access = public)
        ParentApp % Handle to the MetadataEditorApp instance
        UIBaseContainer % This will now be obj.DatasetDetailsPanel, created by this class
        
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

        % NEW PROPERTIES for base layout elements
        DatasetDetailsGridLayout matlab.ui.container.GridLayout
        DatasetDetailsLabel matlab.ui.control.Label
        DatasetDetailsPanel matlab.ui.container.Panel % Panel where detailed UI is built
    end

    properties (Access = private)
        ResourcesPath % Path to resources, e.g., for icons
    end

    methods
        % MODIFIED CONSTRUCTOR
        function obj = DatasetDetailsGUI(parentAppHandle, datasetDetailsTabHandle) % Accepts DatasetDetailsTab
            obj.ParentApp = parentAppHandle; %

            % Inherit ResourcesPath from ParentApp
            if isprop(obj.ParentApp, 'ResourcesPath') && isfolder(obj.ParentApp.ResourcesPath)
                obj.ResourcesPath = obj.ParentApp.ResourcesPath; %
            else
                % Fallback if ParentApp.ResourcesPath is not defined
                guiFilePath = fileparts(mfilename('fullpath')); %
                % Path to +ndi/+database/+metadata_app/+class/
                obj.ResourcesPath = fullfile(guiFilePath, '..', '+Apps', 'resources'); %
                fprintf(2, 'Warning (DatasetDetailsGUI): ParentApp.ResourcesPath not found. Using fallback: %s\n', obj.ResourcesPath); %
            end
            
            obj.createDatasetDetailsTabBaseLayout(datasetDetailsTabHandle); % Create base structure in DatasetDetailsTab
            obj.createDatasetDetailsUIComponents(); % Populate the self-created DatasetDetailsPanel
        end

        % NEW METHOD to create the base layout for the Dataset Details tab content
        function createDatasetDetailsTabBaseLayout(obj, datasetDetailsTabHandle)
            % datasetDetailsTabHandle is app.DatasetDetailsTab passed from MetadataEditorApp
            obj.DatasetDetailsGridLayout = uigridlayout(datasetDetailsTabHandle, [2 1], 'RowHeight', {60, '1x'}, 'Padding', [10 20 10 10]); %
            obj.DatasetDetailsLabel = uilabel(obj.DatasetDetailsGridLayout, 'Text', 'Dataset Details', 'HorizontalAlignment', 'center', 'FontSize', 18, 'FontWeight', 'bold'); %
            obj.DatasetDetailsLabel.Layout.Row=1; obj.DatasetDetailsLabel.Layout.Column=1; %
            obj.DatasetDetailsPanel = uipanel(obj.DatasetDetailsGridLayout, 'BorderType', 'none'); %
            obj.DatasetDetailsPanel.Layout.Row=2; obj.DatasetDetailsPanel.Layout.Column=1; %
            
            % Set UIBaseContainer to the newly created DatasetDetailsPanel.
            % createDatasetDetailsUIComponents will use this as its parent.
            obj.UIBaseContainer = obj.DatasetDetailsPanel; 
        end

        function initialize(obj)
            % Set up callbacks for all managed UI components
            obj.ReleaseDateDatePicker.ValueChangedFcn = @(~,event) obj.releaseDateValueChanged(event); %
            obj.LicenseDropDown.ValueChangedFcn = @(~,event) obj.licenseDropDownValueChanged(event); %
            obj.LicenseHelpButton.ButtonPushedFcn = @(~,event) obj.licenseHelpButtonPushed(event); %
            obj.FullDocumentationEditField.ValueChangedFcn = @(~,event) obj.fullDocumentationValueChanged(event); %
            obj.VersionIdentifierEditField.ValueChangedFcn = @(~,event) obj.versionIdentifierValueChanged(event); %
            obj.VersionInnovationEditField.ValueChangedFcn = @(~,event) obj.versionInnovationValueChanged(event); %
            obj.AddFundingButton.ButtonPushedFcn = @(~,event) obj.addFundingButtonPushed(event); %
            obj.RemoveFundingButton.ButtonPushedFcn = @(~,event) obj.removeFundingButtonPushed(event); %
            obj.MoveFundingUpButton.ButtonPushedFcn = @(~,event) obj.moveFundingPushed('Funding', 'up'); %
            obj.MoveFundingDownButton.ButtonPushedFcn = @(~,event) obj.moveFundingPushed('Funding', 'down'); %
            obj.FundingUITable.CellEditCallback = @(src,event) obj.fundingTableCellEdited(event); %
            obj.FundingUITable.CellSelectionCallback = @(src,event) obj.tableCellSelected(src,event,'Funding'); %
            obj.FundingUITable.DoubleClickedFcn = @(src,event) obj.fundingUITableDoubleClicked(event); %


            obj.AddRelatedPublicationButton.ButtonPushedFcn = @(~,event) obj.addRelatedPublicationButtonPushed(event); %
            obj.RemovePublicationButton.ButtonPushedFcn = @(~,event) obj.removePublicationButtonPushed(event); %
            obj.MovePublicationUpButton.ButtonPushedFcn = @(~,event) obj.movePublicationPushed('Publication', 'up'); %
            obj.MovePublicationDownButton.ButtonPushedFcn = @(~,event) obj.movePublicationPushed('Publication', 'down'); %
            obj.RelatedPublicationUITable.CellEditCallback = @(src,event) obj.publicationTableCellEdited(event); %
            obj.RelatedPublicationUITable.CellSelectionCallback = @(src,event) obj.tableCellSelected(src,event,'Publication'); %
            obj.RelatedPublicationUITable.DoubleClickedFcn = @(src,event) obj.relatedPublicationUITableDoubleClicked(event); %

            obj.populateLicenseDropdown(); %
            obj.markRequiredFields(); %
            obj.drawDatasetDetails(); %
        end

        function createDatasetDetailsUIComponents(obj)
            % This method now uses obj.UIBaseContainer, which is obj.DatasetDetailsPanel
            parent = obj.UIBaseContainer; 
            iconsPath = fullfile(obj.ResourcesPath, 'icons'); %

            mainGrid = uigridlayout(parent); %
            mainGrid.ColumnWidth = {'1x'}; %
            mainGrid.RowHeight = {'fit', '1x'};  %
            mainGrid.Padding = [10 10 10 10]; %
            mainGrid.RowSpacing = 15; %

            topPartGrid = uigridlayout(mainGrid);  %
            topPartGrid.Layout.Row = 1; topPartGrid.Layout.Column = 1; %
            topPartGrid.ColumnWidth = {'1x', '1x'};  %
            topPartGrid.RowHeight = {'fit'}; %
            topPartGrid.ColumnSpacing = 20; %

            accessibilityGrid = uigridlayout(topPartGrid); %
            accessibilityGrid.Layout.Row = 1; accessibilityGrid.Layout.Column = 1; %
            accessibilityGrid.ColumnWidth = {'fit', '1x'}; %
            accessibilityGrid.RowHeight = {'fit', 23, 23, 23, 23, 23};  %
            accessibilityGrid.RowSpacing = 8; accessibilityGrid.ColumnSpacing = 10; %
            obj.AccessibilityLabel = uilabel(accessibilityGrid, 'Text', 'Accessibility & Versioning', 'FontWeight', 'bold'); %
            obj.AccessibilityLabel.Layout.Row=1; obj.AccessibilityLabel.Layout.Column=[1,2];  %

            obj.ReleaseDateDatePickerLabel = uilabel(accessibilityGrid, 'Text', 'Release Date:', 'HorizontalAlignment', 'right'); %
            obj.ReleaseDateDatePickerLabel.Layout.Row=2; %
            obj.ReleaseDateDatePickerLabel.Layout.Column=1; %
            obj.ReleaseDateDatePicker = uidatepicker(accessibilityGrid); %
            obj.ReleaseDateDatePicker.Layout.Row=2; obj.ReleaseDateDatePicker.Layout.Column=2; %

            obj.LicenseDropDownLabel = uilabel(accessibilityGrid, 'Text', 'License:', 'HorizontalAlignment', 'right'); %
            obj.LicenseDropDownLabel.Layout.Row=3; obj.LicenseDropDownLabel.Layout.Column=1; %
            licenseHelpGrid = uigridlayout(accessibilityGrid);  %
            licenseHelpGrid.Layout.Row=3; licenseHelpGrid.Layout.Column=2; %
            licenseHelpGrid.ColumnWidth = {'1x',25}; licenseHelpGrid.Padding = [0 0 0 0]; licenseHelpGrid.RowHeight = {'fit'}; %
            obj.LicenseDropDown = uidropdown(licenseHelpGrid); %
            obj.LicenseDropDown.Layout.Row=1; obj.LicenseDropDown.Layout.Column=1; %
            obj.LicenseHelpButton = uibutton(licenseHelpGrid, 'push', 'Text', '', 'Icon', fullfile(iconsPath, 'help.png')); %
            obj.LicenseHelpButton.Layout.Row=1; obj.LicenseHelpButton.Layout.Column=2; %

            obj.FullDocumentationEditFieldLabel = uilabel(accessibilityGrid, 'Text', 'Full Documentation URL/DOI:', 'HorizontalAlignment', 'right'); %
            obj.FullDocumentationEditFieldLabel.Layout.Row=4; obj.FullDocumentationEditFieldLabel.Layout.Column=1; %
            obj.FullDocumentationEditField = uieditfield(accessibilityGrid, 'text'); %
            obj.FullDocumentationEditField.Layout.Row=4; obj.FullDocumentationEditField.Layout.Column=2; %

            obj.VersionIdentifierEditFieldLabel = uilabel(accessibilityGrid, 'Text', 'Version Identifier:', 'HorizontalAlignment', 'right'); %
            obj.VersionIdentifierEditFieldLabel.Layout.Row=5; obj.VersionIdentifierEditFieldLabel.Layout.Column=1; %
            obj.VersionIdentifierEditField = uieditfield(accessibilityGrid, 'text'); %
            obj.VersionIdentifierEditField.Layout.Row=5; obj.VersionIdentifierEditField.Layout.Column=2; %

            obj.VersionInnovationEditFieldLabel = uilabel(accessibilityGrid, 'Text', 'Version Innovation:', 'HorizontalAlignment', 'right'); %
            obj.VersionInnovationEditFieldLabel.Layout.Row=6; obj.VersionInnovationEditFieldLabel.Layout.Column=1; %
            obj.VersionInnovationEditField = uieditfield(accessibilityGrid, 'text'); %
            obj.VersionInnovationEditField.Layout.Row=6; obj.VersionInnovationEditField.Layout.Column=2; %

            fundingSectionGrid = uigridlayout(topPartGrid);  %
            fundingSectionGrid.Layout.Row=1; fundingSectionGrid.Layout.Column=2; %
            fundingSectionGrid.ColumnWidth = {'1x', 40};  %
            fundingSectionGrid.RowHeight = {23, '1x'}; %
            fundingSectionGrid.RowSpacing = 5; %
            obj.FundingUITableLabel = uilabel(fundingSectionGrid, 'Text', 'Funding', 'FontWeight', 'bold'); %
            obj.FundingUITableLabel.Layout.Row=1; obj.FundingUITableLabel.Layout.Column=1; %
            obj.FundingUITable = uitable(fundingSectionGrid, 'ColumnName', {'Funder'; 'Award Title'; 'Award ID'}, 'RowName', {}, 'ColumnEditable', true); %
            obj.FundingUITable.Layout.Row=2; obj.FundingUITable.Layout.Column=1; %
            
            fundingButtonsGrid = uigridlayout(fundingSectionGrid); %
            fundingButtonsGrid.Layout.Row=2; fundingButtonsGrid.Layout.Column=2; %
            fundingButtonsGrid.RowHeight={'fit','fit',10,'fit','fit','1x'}; fundingButtonsGrid.ColumnWidth={'1x'}; fundingButtonsGrid.Padding = [0 0 0 0]; fundingButtonsGrid.RowSpacing = 5; %
            obj.AddFundingButton = uibutton(fundingButtonsGrid, 'push', 'Text', '', 'Icon', fullfile(iconsPath, 'plus.png')); %
            obj.AddFundingButton.Layout.Row=1; obj.AddFundingButton.Layout.Column=1; %
            obj.RemoveFundingButton = uibutton(fundingButtonsGrid, 'push', 'Text', '', 'Icon', fullfile(iconsPath, 'minus.png')); %
            obj.RemoveFundingButton.Layout.Row=2; obj.RemoveFundingButton.Layout.Column=1; %
            obj.MoveFundingUpButton = uibutton(fundingButtonsGrid, 'push', 'Text', '', 'Icon', fullfile(iconsPath, 'up.png')); %
            obj.MoveFundingUpButton.Layout.Row=4; obj.MoveFundingUpButton.Layout.Column=1; %
            obj.MoveFundingDownButton = uibutton(fundingButtonsGrid, 'push', 'Text', '', 'Icon', fullfile(iconsPath, 'down.png')); %
            obj.MoveFundingDownButton.Layout.Row=5; obj.MoveFundingDownButton.Layout.Column=1; %

            publicationSectionGrid = uigridlayout(mainGrid);  %
            publicationSectionGrid.Layout.Row=2; publicationSectionGrid.Layout.Column=1; %
            publicationSectionGrid.ColumnWidth = {'1x', 40}; %
            publicationSectionGrid.RowHeight = {23, '1x'}; %
            publicationSectionGrid.RowSpacing = 5; %

            obj.RelatedPublicationUITableLabel = uilabel(publicationSectionGrid, 'Text', 'Related Publications', 'FontWeight', 'bold'); %
            obj.RelatedPublicationUITableLabel.Layout.Row=1; obj.RelatedPublicationUITableLabel.Layout.Column=1; %
            obj.RelatedPublicationUITable = uitable(publicationSectionGrid, 'ColumnName', {'Publication (e.g., Title, Journal)'; 'DOI'; 'PMID'; 'PMCID'}, 'RowName', {}, 'ColumnEditable', true);  %
            obj.RelatedPublicationUITable.Layout.Row=2; obj.RelatedPublicationUITable.Layout.Column=1; %
            
            publicationButtonsGrid = uigridlayout(publicationSectionGrid); %
            publicationButtonsGrid.Layout.Row=2; publicationButtonsGrid.Layout.Column=2; %
            publicationButtonsGrid.RowHeight={'fit','fit',10,'fit','fit','1x'}; publicationButtonsGrid.ColumnWidth={'1x'}; publicationButtonsGrid.Padding = [0 0 0 0]; publicationButtonsGrid.RowSpacing = 5; %
            obj.AddRelatedPublicationButton = uibutton(publicationButtonsGrid, 'push', 'Text', '', 'Icon', fullfile(iconsPath, 'plus.png')); %
            obj.AddRelatedPublicationButton.Layout.Row=1; obj.AddRelatedPublicationButton.Layout.Column=1; %
            obj.RemovePublicationButton = uibutton(publicationButtonsGrid, 'push', 'Text', '', 'Icon', fullfile(iconsPath, 'minus.png')); %
            obj.RemovePublicationButton.Layout.Row=2; obj.RemovePublicationButton.Layout.Column=1; %
            obj.MovePublicationUpButton = uibutton(publicationButtonsGrid, 'push', 'Text', '', 'Icon', fullfile(iconsPath, 'up.png')); %
            obj.MovePublicationUpButton.Layout.Row=4; obj.MovePublicationUpButton.Layout.Column=1; %
            obj.MovePublicationDownButton = uibutton(publicationButtonsGrid, 'push', 'Text', '', 'Icon', fullfile(iconsPath, 'down.png')); %
            obj.MovePublicationDownButton.Layout.Row=5; obj.MovePublicationDownButton.Layout.Column=1; %
        end

        function drawDatasetDetails(obj)
            fprintf('DEBUG (DatasetDetailsGUI): Drawing Dataset Details UI.\n'); %
            if isempty(obj.ParentApp) || ~isvalid(obj.ParentApp) || ~isprop(obj.ParentApp, 'DatasetInformationStruct') %
                fprintf(2, 'ERROR (DatasetDetailsGUI/drawDatasetDetails): ParentApp or DatasetInformationStruct not available.\n'); %
                obj.ReleaseDateDatePicker.Value = NaT; %
                if ~isempty(obj.LicenseDropDown.ItemsData), obj.LicenseDropDown.Value = obj.LicenseDropDown.ItemsData{1}; else, obj.LicenseDropDown.Items = {'(No licenses)'}; obj.LicenseDropDown.ItemsData = {''}; obj.LicenseDropDown.Value = ''; %
                end
                obj.FullDocumentationEditField.Value = ''; %
                obj.VersionIdentifierEditField.Value = '1.0.0'; %
                obj.VersionInnovationEditField.Value = 'This is the first version of the dataset'; %
                obj.FundingUITable.Data = table('Size',[0 3],'VariableTypes',{'string','string','string'},'VariableNames', {'funder','awardTitle','awardNumber'}); %
                obj.RelatedPublicationUITable.Data = table('Size',[0 4],'VariableTypes',{'string','string','string','string'}, 'VariableNames',  {'title','doi','pmid','pmcid'}); %
                return; %
            end
            
            dsStruct = obj.ParentApp.DatasetInformationStruct; %
            fprintf('DEBUG (DatasetDetailsGUI/drawDatasetDetails): dsStruct type: %s, isstruct: %d, isscalar: %d.\n', class(dsStruct), isstruct(dsStruct), isscalar(dsStruct)); %
            if ~(isstruct(dsStruct) && isscalar(dsStruct)) %
                fprintf(2, 'ERROR (DatasetDetailsGUI/drawDatasetDetails): dsStruct is not a scalar struct. Setting defaults.\n'); %
                obj.ReleaseDateDatePicker.Value = NaT; %
                if ~isempty(obj.LicenseDropDown.ItemsData), obj.LicenseDropDown.Value = obj.LicenseDropDown.ItemsData{1}; else, obj.LicenseDropDown.Items = {'(No licenses)'}; obj.LicenseDropDown.ItemsData = {''}; obj.LicenseDropDown.Value = ''; %
                end
                obj.FullDocumentationEditField.Value = ''; %
                obj.VersionIdentifierEditField.Value = '1.0.0'; %
                obj.VersionInnovationEditField.Value = 'This is the first version of the dataset'; %
                obj.FundingUITable.Data = table('Size',[0 3],'VariableTypes',{'string','string','string'},'VariableNames', {'funder','awardTitle','awardNumber'}); %
                obj.RelatedPublicationUITable.Data = table('Size',[0 4],'VariableTypes',{'string','string','string','string'}, 'VariableNames',  {'title','doi','pmid','pmcid'}); %
                return; %
            end

            if isfield(dsStruct, 'ReleaseDate') %
                val = dsStruct.ReleaseDate; %
                if ~isempty(val) && isdatetime(val) && ~isnat(val) %
                    obj.ReleaseDateDatePicker.Value = val; %
                else
                    obj.ReleaseDateDatePicker.Value = NaT; %
                end
            else
                obj.ReleaseDateDatePicker.Value = NaT; %
            end

            defaultLicenseValue = "";  %
            if ~isempty(obj.LicenseDropDown.ItemsData), defaultLicenseValue = obj.LicenseDropDown.ItemsData{1}; %
            end
            if isfield(dsStruct, 'License') && ~isempty(dsStruct.License) %
                if any(strcmp(obj.LicenseDropDown.ItemsData, dsStruct.License)) %
                    obj.LicenseDropDown.Value = dsStruct.License; %
                else
                    obj.LicenseDropDown.Value = defaultLicenseValue; %
                end
            else
                obj.LicenseDropDown.Value = defaultLicenseValue; %
            end
            
            if isfield(dsStruct, 'FullDocumentation') %
                obj.FullDocumentationEditField.Value = dsStruct.FullDocumentation; %
            else
                obj.FullDocumentationEditField.Value = ''; %
            end

            if isfield(dsStruct, 'VersionIdentifier') && ~isempty(dsStruct.VersionIdentifier) %
                obj.VersionIdentifierEditField.Value = dsStruct.VersionIdentifier; %
            else
                obj.VersionIdentifierEditField.Value = '1.0.0'; %
            end

            if isfield(dsStruct, 'VersionInnovation') && ~isempty(dsStruct.VersionInnovation) %
                obj.VersionInnovationEditField.Value = dsStruct.VersionInnovation; %
            else
                obj.VersionInnovationEditField.Value = 'This is the first version of the dataset'; %
            end

            if isfield(dsStruct, 'Funding') && (isstruct(dsStruct.Funding) || istable(dsStruct.Funding)) && (~isempty(dsStruct.Funding) || (isstruct(dsStruct.Funding) && numel(fieldnames(dsStruct.Funding))>0 && numel(dsStruct.Funding) > 0) ) %
                if istable(dsStruct.Funding) %
                    obj.FundingUITable.Data = dsStruct.Funding; %
                else
                    obj.FundingUITable.Data = struct2table(dsStruct.Funding, 'AsArray',true); %
                end
            else
                obj.FundingUITable.Data = table('Size',[0 3],'VariableTypes',{'string','string','string'},'VariableNames', {'funder','awardTitle','awardNumber'}); %
            end

            if isfield(dsStruct, 'RelatedPublication') && (isstruct(dsStruct.RelatedPublication) || istable(dsStruct.RelatedPublication)) && (~isempty(dsStruct.RelatedPublication) || (isstruct(dsStruct.RelatedPublication) && numel(fieldnames(dsStruct.RelatedPublication))>0 && numel(dsStruct.RelatedPublication) > 0) ) %
                 if istable(dsStruct.RelatedPublication) %
                    obj.RelatedPublicationUITable.Data = dsStruct.RelatedPublication; %
                else
                    obj.RelatedPublicationUITable.Data = struct2table(dsStruct.RelatedPublication, 'AsArray',true); %
                end
            else
                obj.RelatedPublicationUITable.Data = table('Size',[0 4],'VariableTypes',{'string','string','string','string'}, 'VariableNames',  {'title','doi','pmid','pmcid'}); %
            end
            fprintf('DEBUG (DatasetDetailsGUI): drawDatasetDetails finished.\n'); %
        end
        
        function populateLicenseDropdown(obj)
            [names, shortNames] = ndi.database.metadata_app.fun.getCCByLicences(); %
            obj.LicenseDropDown.Items = ["Select a License"; shortNames]; %
            obj.LicenseDropDown.ItemsData = [""; names]; %
            if numel(obj.LicenseDropDown.ItemsData) > 1 %
                obj.LicenseDropDown.Value = obj.LicenseDropDown.ItemsData{2}; %
            elseif ~isempty(obj.LicenseDropDown.ItemsData) %
                 obj.LicenseDropDown.Value = obj.LicenseDropDown.ItemsData{1}; %
            end
        end

        % --- Callbacks ---
        function releaseDateValueChanged(obj, event)
            obj.ParentApp.DatasetInformationStruct.ReleaseDate = obj.ReleaseDateDatePicker.Value; %
            obj.ParentApp.saveDatasetInformationStruct(); %
        end

        function licenseDropDownValueChanged(obj, event)
            obj.ParentApp.DatasetInformationStruct.License = obj.LicenseDropDown.Value; %
            if obj.LicenseDropDown.Value ~= "" %
                obj.ParentApp.resetLabelForRequiredField('License'); %
            else
                obj.ParentApp.highlightLabelForRequiredField('License'); %
            end
            obj.ParentApp.saveDatasetInformationStruct(); %
        end

        function licenseHelpButtonPushed(obj, event)
            web("https://creativecommons.org/licenses/"); %
        end

        function fullDocumentationValueChanged(obj, event)
            value = obj.FullDocumentationEditField.Value; %
            if ~isempty(value) && ~(startsWith(value, 'http') || contains(value, 'doi.org')) %
                 obj.ParentApp.alert('Full documentation should be a valid URL or DOI.', 'Invalid Input'); %
            else
                obj.ParentApp.DatasetInformationStruct.FullDocumentation = value; %
                obj.ParentApp.saveDatasetInformationStruct(); %
            end
        end
        
        function versionIdentifierValueChanged(obj, event)
            obj.ParentApp.DatasetInformationStruct.VersionIdentifier = obj.VersionIdentifierEditField.Value; %
            if ~isempty(obj.VersionIdentifierEditField.Value) %
                 obj.ParentApp.resetLabelForRequiredField('VersionIdentifier'); %
            else
                 obj.ParentApp.highlightLabelForRequiredField('VersionIdentifier'); %
            end
            obj.ParentApp.saveDatasetInformationStruct(); %
        end

        function versionInnovationValueChanged(obj, event)
            obj.ParentApp.DatasetInformationStruct.VersionInnovation = obj.VersionInnovationEditField.Value; %
            obj.ParentApp.saveDatasetInformationStruct(); %
        end
        
        function S = openFundingForm(obj, info) % obj is DatasetDetailsGUI instance
            parentApp = obj.ParentApp; % For convenience

            % Ensure ParentApp and its properties are available
            if isempty(parentApp) || ~isvalid(parentApp) || ...
               ~isprop(parentApp, 'NDIMetadataEditorUIFigure') || ~isvalid(parentApp.NDIMetadataEditorUIFigure) || ...
               ~isprop(parentApp, 'UIForm')
                fprintf(2, 'Error (DatasetDetailsGUI/openFundingForm): ParentApp or its required properties (NDIMetadataEditorUIFigure, UIForm) are not available.\n');
                S = struct.empty;
                return;
            end

            progressDialog = uiprogressdlg(parentApp.NDIMetadataEditorUIFigure, ...
                'Message', 'Opening form for entering funder details', ...
                'Title', 'Please wait...', 'Indeterminate', "on"); %
            
            if ~isfield(parentApp.UIForm, 'Funding') || ~isvalid(parentApp.UIForm.Funding) %
                parentApp.UIForm.Funding = ndi.database.metadata_app.Apps.FundingForm(); %
            else
                parentApp.UIForm.Funding.Visible = 'on'; %
            end
            
            if nargin > 1 && ~isempty(info) %
                parentApp.UIForm.Funding.setFunderDetails(info); %
            end
            
            ndi.gui.utility.centerFigure(parentApp.UIForm.Funding.UIFigure, parentApp.NDIMetadataEditorUIFigure); %
            progressDialog.Message = 'Enter funder details:'; %
            parentApp.UIForm.Funding.waitfor(); %
            
            S = parentApp.UIForm.Funding.getFunderDetails(); %
            mode = parentApp.UIForm.Funding.FinishState; %
            if mode ~= "Save", S = struct.empty; end %
            
            parentApp.UIForm.Funding.reset(); %
            parentApp.UIForm.Funding.Visible = 'off'; %
            delete(progressDialog); %
        end

        function addFundingButtonPushed(obj, event)
            S_funding = obj.openFundingForm(); % MODIFIED CALL
            if ~isempty(S_funding) %
                currentFunding = obj.getFundingInfo(); %
                if isempty(currentFunding) || (isstruct(currentFunding) && numel(fieldnames(currentFunding))==0 && numel(currentFunding)==0) %
                    currentFunding = S_funding; %
                else
                    currentFunding(end+1) = S_funding; %
                end
                obj.ParentApp.DatasetInformationStruct.Funding = currentFunding; %
                obj.FundingUITable.Data = struct2table(currentFunding, 'AsArray', true); %
                obj.ParentApp.saveDatasetInformationStruct(); %
            end
        end
        
        function removeFundingButtonPushed(obj, event)
            selection = obj.FundingUITable.Selection; %
            if ~isempty(selection) %
                data = table2struct(obj.FundingUITable.Data); %
                data(selection(1),:) = [];  %
                obj.ParentApp.DatasetInformationStruct.Funding = data; %
                if isempty(data)  %
                    obj.ParentApp.DatasetInformationStruct.Funding = repmat(struct('funder','','awardTitle','','awardNumber',''),0,1); %
                    obj.FundingUITable.Data = table('Size',[0 3],'VariableTypes',{'string','string','string'},'VariableNames', {'funder','awardTitle','awardNumber'}); %
                else
                    obj.FundingUITable.Data = struct2table(data, 'AsArray', true); %
                end
                obj.ParentApp.saveDatasetInformationStruct(); %
            else
                obj.ParentApp.inform('Select a funding entry to remove.', 'No Selection'); %
            end
        end
        
        function addRelatedPublicationButtonPushed(obj, event)
            S_pub = obj.ParentApp.openForm("Publication"); % Uses ParentApp's generic form opener
            if ~isempty(S_pub) %
                currentPubs = obj.getRelatedPublications(); %
                if isempty(currentPubs) || (isstruct(currentPubs) && numel(fieldnames(currentPubs))==0 && numel(currentPubs)==0) %
                    currentPubs = S_pub; %
                else
                    currentPubs(end+1) = S_pub; %
                end
                obj.ParentApp.DatasetInformationStruct.RelatedPublication = currentPubs; %
                obj.RelatedPublicationUITable.Data = struct2table(currentPubs, 'AsArray', true); %
                obj.ParentApp.saveDatasetInformationStruct(); %
            end
        end

        function removePublicationButtonPushed(obj, event)
            selection = obj.RelatedPublicationUITable.Selection; %
            if ~isempty(selection) %
                data = table2struct(obj.RelatedPublicationUITable.Data); %
                data(selection(1),:) = []; %
                obj.ParentApp.DatasetInformationStruct.RelatedPublication = data; %
                 if isempty(data)  %
                    obj.ParentApp.DatasetInformationStruct.RelatedPublication = repmat(struct('title','','doi','','pmid','','pmcid',''),0,1); %
                    obj.RelatedPublicationUITable.Data = table('Size',[0 4],'VariableTypes',{'string','string','string','string'}, 'VariableNames',  {'title','doi','pmid','pmcid'}); %
                 else
                    obj.RelatedPublicationUITable.Data = struct2table(data, 'AsArray', true); %
                 end
                obj.ParentApp.saveDatasetInformationStruct(); %
            else
                obj.ParentApp.inform('Select a publication to remove.', 'No Selection'); %
            end
        end

        function moveTableItem(obj, uit, fieldName, direction)
            selection = uit.Selection; %
            if isempty(selection) || numel(selection) > 1, return; end  %
            
            dataArray = obj.ParentApp.DatasetInformationStruct.(fieldName); %
            if ~isstruct(dataArray) || numel(dataArray) < 2, return; end  %

            n = numel(dataArray); %
            currentIndex = selection(1); %
            newIndex = currentIndex; %

            if strcmp(direction,'up') && currentIndex > 1 %
                newIndex = currentIndex - 1; %
            elseif strcmp(direction,'down') && currentIndex < n %
                newIndex = currentIndex + 1; %
            else
                return; %
            end
            
            temp = dataArray(currentIndex); %
            dataArray(currentIndex) = dataArray(newIndex); %
            dataArray(newIndex) = temp; %
            
            obj.ParentApp.DatasetInformationStruct.(fieldName) = dataArray; %
            obj.drawDatasetDetails();  %
            uit.Selection = newIndex;  %
            obj.ParentApp.saveDatasetInformationStruct(); %
        end

        function moveFundingPushed(obj, ~, direction) 
            obj.moveTableItem(obj.FundingUITable, 'Funding', direction); %
        end

        function movePublicationPushed(obj, ~, direction) 
            obj.moveTableItem(obj.RelatedPublicationUITable, 'RelatedPublication', direction); %
        end
        
        function fundingTableCellEdited(obj, event)
            indices = event.Indices; %
            row = indices(1); col = indices(2); %
            newValue = event.NewData; %
            currentFunding = table2struct(obj.FundingUITable.Data);  %
            columnNames = obj.FundingUITable.ColumnName; %
            fieldToUpdate = columnNames{col}; %
            if isnumeric(newValue) || islogical(newValue), newValue = char(string(newValue));  %
            elseif isstring(newValue), newValue = char(newValue); %
            end

            currentFunding(row).(fieldToUpdate) = newValue; %
            obj.ParentApp.DatasetInformationStruct.Funding = currentFunding; %
            obj.ParentApp.saveDatasetInformationStruct(); %
        end
        
        function publicationTableCellEdited(obj, event)
            indices = event.Indices; %
            row = indices(1); col = indices(2); %
            newValue = event.NewData; %
            currentPubs = table2struct(obj.RelatedPublicationUITable.Data); %
            columnNames = obj.RelatedPublicationUITable.ColumnName; %
            fieldToUpdate = columnNames{col}; %
            if isnumeric(newValue) || islogical(newValue), newValue = char(string(newValue));  %
            elseif isstring(newValue), newValue = char(newValue); %
            end

            currentPubs(row).(fieldToUpdate) = newValue; %
            obj.ParentApp.DatasetInformationStruct.RelatedPublication = currentPubs; %
            obj.ParentApp.saveDatasetInformationStruct(); %
        end
        
        function tableCellSelected(obj, src, event, tableName)
        end
        
        function fundingUITableDoubleClicked(obj, event)
            if isempty(event.InteractionInformation) || ~isfield(event.InteractionInformation, 'Row') || isempty(event.InteractionInformation.Row) %
                return; %
            end
            selectedRow = event.InteractionInformation.Row(1); %
            if selectedRow > 0 && selectedRow <= size(obj.FundingUITable.Data,1) %
                fundingEntry = table2struct(obj.FundingUITable.Data(selectedRow,:)); %
                updatedEntry = obj.openFundingForm(fundingEntry); % MODIFIED CALL
                if ~isempty(updatedEntry) %
                    currentFunding = table2struct(obj.FundingUITable.Data); %
                    currentFunding(selectedRow) = updatedEntry; %
                    obj.ParentApp.DatasetInformationStruct.Funding = currentFunding; %
                    obj.FundingUITable.Data = struct2table(currentFunding, 'AsArray',true); %
                    obj.ParentApp.saveDatasetInformationStruct(); %
                end
            end
        end

        function relatedPublicationUITableDoubleClicked(obj, event)
            if isempty(event.InteractionInformation) || ~isfield(event.InteractionInformation, 'Row') || isempty(event.InteractionInformation.Row) %
                return; %
            end
            selectedRow = event.InteractionInformation.Row(1); %
            if selectedRow > 0 && selectedRow <= size(obj.RelatedPublicationUITable.Data,1) %
                pubEntry = table2struct(obj.RelatedPublicationUITable.Data(selectedRow,:)); %
                updatedEntry = obj.ParentApp.openForm('Publication', pubEntry, true); % Uses ParentApp's generic form opener
                if ~isempty(updatedEntry) %
                    currentPubs = table2struct(obj.RelatedPublicationUITable.Data); %
                    currentPubs(selectedRow) = updatedEntry; %
                    obj.ParentApp.DatasetInformationStruct.RelatedPublication = currentPubs; %
                    obj.RelatedPublicationUITable.Data = struct2table(currentPubs, 'AsArray',true); %
                    obj.ParentApp.saveDatasetInformationStruct(); %
                end
            end
        end


        % --- Getter Methods ---
        function val = getReleaseDate(obj), val = obj.ReleaseDateDatePicker.Value; end %
        function val = getLicense(obj), val = obj.LicenseDropDown.Value; end %
        function val = getFullDocumentation(obj), val = obj.FullDocumentationEditField.Value; end %
        function val = getVersionIdentifier(obj), val = obj.VersionIdentifierEditField.Value; end %
        function val = getVersionInnovation(obj), val = obj.VersionInnovationEditField.Value; end %
        function val = getFundingInfo(obj)
            if isempty(obj.FundingUITable.Data) %
                 val = repmat(struct('funder','','awardTitle','','awardNumber',''),0,1); %
            else
                val = table2struct(obj.FundingUITable.Data); %
            end
        end
        function val = getRelatedPublications(obj)
            if isempty(obj.RelatedPublicationUITable.Data) %
                val = repmat(struct('title','','doi','','pmid','','pmcid',''),0,1); %
            else
                val = table2struct(obj.RelatedPublicationUITable.Data); %
            end
        end
        
        % --- Required Field Checks ---
        function missingFields = checkRequiredFields(obj)
            missingFields = string.empty(0,1); %
            if isempty(obj.LicenseDropDown.Value) || strcmp(obj.LicenseDropDown.Value, "") %
                missingFields(end+1) = obj.ParentApp.getFieldTitle('License'); %
                obj.ParentApp.highlightLabelForRequiredField('License'); %
            else
                obj.ParentApp.resetLabelForRequiredField('License'); %
            end
            if isempty(strtrim(obj.VersionIdentifierEditField.Value)) %
                missingFields(end+1) = obj.ParentApp.getFieldTitle('VersionIdentifier'); %
                obj.ParentApp.highlightLabelForRequiredField('VersionIdentifier'); %
            else
                 obj.ParentApp.resetLabelForRequiredField('VersionIdentifier'); %
            end
        end

        function markRequiredFields(obj)
            requiredFields = ndi.database.metadata_app.fun.getRequiredFields(); %
            requiredSymbol = '*'; %
            
            if isfield(requiredFields, 'License') && requiredFields.License %
                if ~contains(obj.LicenseDropDownLabel.Text, requiredSymbol) %
                    obj.LicenseDropDownLabel.Text = [obj.LicenseDropDownLabel.Text ' ' requiredSymbol]; %
                end
                 obj.LicenseDropDownLabel.Tooltip = "Required"; %
            end
            if isfield(requiredFields, 'VersionIdentifier') && requiredFields.VersionIdentifier %
                 if ~contains(obj.VersionIdentifierEditFieldLabel.Text, requiredSymbol) %
                    obj.VersionIdentifierEditFieldLabel.Text = [obj.VersionIdentifierEditFieldLabel.Text ' ' requiredSymbol]; %
                 end
                obj.VersionIdentifierEditFieldLabel.Tooltip = "Required"; %
            end
        end
    end
end

% Helper function for conditional assignment (inline if-else)
function result = ifthenelse(condition, trueval, falseval)
    if condition
        result = trueval; %
    else
        result = falseval; %
    end
end