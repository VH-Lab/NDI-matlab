classdef AuthorDataGUI < handle
    %AUTHORDATAGUI Manages the UI elements and interactions for Author Data.

    properties (Access = public)
        ParentApp % Handle to the MetadataEditorApp instance
        UIBaseContainer % The parent uipanel provided by MetadataEditorApp
        
        % UI Components for Author List
        AuthorTable matlab.ui.control.Table
        AddAuthorButton matlab.ui.control.Button
        RemoveAuthorButton matlab.ui.control.Button
        MoveAuthorUpButton matlab.ui.control.Button
        MoveAuthorDownButton matlab.ui.control.Button
        
        % UI Components for Author Details
        GivenNameEditField matlab.ui.control.EditField
        FamilyNameEditField matlab.ui.control.EditField
        EmailEditField matlab.ui.control.EditField
        IdentifierEditField matlab.ui.control.EditField % For ORCID
        LookupIdentifierButton matlab.ui.control.Button % Magnifying glass

        % Author Role Checkboxes
        IsFirstAuthorCheckBox matlab.ui.control.CheckBox
        IsCustodianCheckBox matlab.ui.control.CheckBox
        IsCorrespondingCheckBox matlab.ui.control.CheckBox
        
        % Affiliations
        AffiliationDropDown matlab.ui.control.DropDown
        AddAffiliationButton matlab.ui.control.Button   % '+' button
        RemoveAffiliationButton matlab.ui.control.Button % '-' button
    end

    properties (Access = private)
        ResourcesPath
        AuthorDetailPanel matlab.ui.container.Panel % Not used as property, but created
        AuthorListPanel matlab.ui.container.Panel   % Not used as property, but created
        
        SelectedAuthorIndex          % Index of the currently selected author
        SelectedAffiliationIndex     % Index of selected affiliation (now based on dropdown value)
        SelectedAuthorRoleIndex      % Index of selected role (now managed by checkboxes)
    end

    methods
        function obj = AuthorDataGUI(parentAppHandle, uiParentContainer)
            obj.ParentApp = parentAppHandle;
            obj.UIBaseContainer = uiParentContainer;
            
            if isprop(obj.ParentApp, 'ResourcesPath') && isfolder(obj.ParentApp.ResourcesPath)
                obj.ResourcesPath = obj.ParentApp.ResourcesPath;
            else
                guiFilePath = fileparts(mfilename('fullpath'));
                obj.ResourcesPath = fullfile(guiFilePath, '..', '+Apps', 'resources');
            end
            
            obj.createAuthorUIComponents();
        end

        function initialize(obj)
            % Set up callbacks
            obj.AddAuthorButton.ButtonPushedFcn = @(~,~) obj.addAuthorPushed();
            obj.RemoveAuthorButton.ButtonPushedFcn = @(~,~) obj.removeAuthorPushed();
            obj.MoveAuthorUpButton.ButtonPushedFcn = @(~,~) obj.moveAuthorPushed('up');
            obj.MoveAuthorDownButton.ButtonPushedFcn = @(~,~) obj.moveAuthorPushed('down');
            obj.AuthorTable.CellSelectionCallback = @(src,event) obj.authorTableSelectionChanged(event);
            
            obj.GivenNameEditField.ValueChangedFcn = @(~,event) obj.authorDetailChanged(event, 'givenName');
            obj.FamilyNameEditField.ValueChangedFcn = @(~,event) obj.authorDetailChanged(event, 'familyName');
            obj.EmailEditField.ValueChangedFcn = @(~,event) obj.authorDetailChanged(event, 'email');
            obj.IdentifierEditField.ValueChangedFcn = @(~,event) obj.authorDetailChanged(event, 'identifier');
            % obj.LookupIdentifierButton.ButtonPushedFcn = @(~,~) obj.lookupIdentifierPushed(); % TODO

            obj.IsFirstAuthorCheckBox.ValueChangedFcn = @(~,event) obj.authorRoleCheckboxChanged(event, '1st Author');
            obj.IsCustodianCheckBox.ValueChangedFcn = @(~,event) obj.authorRoleCheckboxChanged(event, 'Custodian');
            obj.IsCorrespondingCheckBox.ValueChangedFcn = @(~,event) obj.authorRoleCheckboxChanged(event, 'Corresponding Author'); 

            obj.AddAffiliationButton.ButtonPushedFcn = @(~,~) obj.addAffiliationPushed();
            obj.RemoveAffiliationButton.ButtonPushedFcn = @(~,~) obj.removeAffiliationPushed();
            obj.AffiliationDropDown.ValueChangedFcn = @(~,event) obj.affiliationDropDownChanged(event); 

            obj.drawAuthorData(); 
        end

        function createAuthorUIComponents(obj)
            iconsPath = fullfile(obj.ResourcesPath, 'icons');

            authorTabGrid = uigridlayout(obj.UIBaseContainer, [1 2], 'ColumnWidth', {'1.2x', '2x'}, 'Padding', [10 10 10 10], 'ColumnSpacing', 15);
            
            authorListOuterPanel = uipanel(authorTabGrid, 'BorderType','none');
            authorListOuterPanel.Layout.Row = 1; authorListOuterPanel.Layout.Column = 1;
            authorListOuterGrid = uigridlayout(authorListOuterPanel, [2 1], 'RowHeight', {'fit', '1x'}, 'Padding', [0 0 0 0], 'RowSpacing', 5);

            authorListLabel = uilabel(authorListOuterGrid, 'Text', 'Create authors and fill out their details', 'FontSize', 10, 'FontWeight', 'bold');
            authorListLabel.Layout.Row = 1;
            authorListLabel.Layout.Column = 1; 
            
            authorListInnerGrid = uigridlayout(authorListOuterGrid, [1 2], 'ColumnWidth', {'1x', 'fit'}, 'RowHeight', {'1x'}, 'Padding', [0 0 0 0], 'ColumnSpacing', 5);
            authorListInnerGrid.Layout.Row = 2;
            
            obj.AuthorTable = uitable(authorListInnerGrid, 'ColumnName', {'Given', 'Family', 'Email', 'ORCID'}, ...
                'RowName', {}, 'ColumnSortable', true, 'SelectionType', 'row', 'Multiselect', 'off');
            obj.AuthorTable.Layout.Row = 1; obj.AuthorTable.Layout.Column = 1;
            
            authorListButtonsGrid = uigridlayout(authorListInnerGrid, [4 1], 'RowHeight', {'fit', 'fit', 'fit', 'fit'}, 'Padding', [10 0 0 0], 'RowSpacing', 10);
            authorListButtonsGrid.Layout.Row = 1; authorListButtonsGrid.Layout.Column = 2;
            obj.AddAuthorButton = uibutton(authorListButtonsGrid, 'push', 'Text', '', 'Icon', fullfile(iconsPath, 'plus.png'), 'Tooltip', 'Add new author');
            obj.RemoveAuthorButton = uibutton(authorListButtonsGrid, 'push', 'Text', '', 'Icon', fullfile(iconsPath, 'minus.png'), 'Tooltip', 'Remove selected author');
            obj.MoveAuthorUpButton = uibutton(authorListButtonsGrid, 'push', 'Text', '', 'Icon', fullfile(iconsPath, 'up.png'), 'Tooltip', 'Move selected author up');
            obj.MoveAuthorDownButton = uibutton(authorListButtonsGrid, 'push', 'Text', '', 'Icon', fullfile(iconsPath, 'down.png'), 'Tooltip', 'Move selected author down');

            detailsMainGrid = uigridlayout(authorTabGrid, [1 2], 'ColumnWidth', {'2x', '1x'}, 'Padding', [0 0 0 0], 'ColumnSpacing', 15);
            detailsMainGrid.Layout.Row = 1; detailsMainGrid.Layout.Column = 2;

            authorInfoSubPanel = uigridlayout(detailsMainGrid);
            authorInfoSubPanel.Layout.Row = 1; authorInfoSubPanel.Layout.Column = 1;
            authorInfoSubPanel.RowHeight = {'fit','fit','fit','fit','fit','fit','fit','1x'}; 
            authorInfoSubPanel.ColumnWidth = {'fit', '1x'};
            authorInfoSubPanel.RowSpacing = 12; 
            authorInfoSubPanel.ColumnSpacing = 8;

            tempLabel1 = uilabel(authorInfoSubPanel, 'Text', 'Given Name', 'HorizontalAlignment', 'right');
            tempLabel1.Layout.Row = 1; tempLabel1.Layout.Column = 1;
            obj.GivenNameEditField = uieditfield(authorInfoSubPanel, 'text');
            obj.GivenNameEditField.Layout.Row = 1; obj.GivenNameEditField.Layout.Column = 2;

            tempLabel2 = uilabel(authorInfoSubPanel, 'Text', 'Family Name', 'HorizontalAlignment', 'right');
            tempLabel2.Layout.Row = 2; tempLabel2.Layout.Column = 1;
            obj.FamilyNameEditField = uieditfield(authorInfoSubPanel, 'text');
            obj.FamilyNameEditField.Layout.Row = 2; obj.FamilyNameEditField.Layout.Column = 2;
            
            tempLabel3 = uilabel(authorInfoSubPanel, 'Text', 'Digital Identifier (ORCID)', 'HorizontalAlignment', 'right');
            tempLabel3.Layout.Row = 3; tempLabel3.Layout.Column = 1;
            identifierWithButtonGrid = uigridlayout(authorInfoSubPanel, [1 2], 'ColumnWidth', {'1x', 30}, 'Padding', [0 0 0 0], 'ColumnSpacing', 5);
            identifierWithButtonGrid.Layout.Row = 3; identifierWithButtonGrid.Layout.Column = 2;
            obj.IdentifierEditField = uieditfield(identifierWithButtonGrid, 'text', 'Placeholder', 'Example: 0000-0002-1825-0097');
            obj.IdentifierEditField.Layout.Column = 1;
            obj.LookupIdentifierButton = uibutton(identifierWithButtonGrid, 'push', 'Text', '', 'Icon', fullfile(iconsPath, 'search.png'), 'Tooltip', 'Lookup ORCID (Not Implemented)'); 
            obj.LookupIdentifierButton.Layout.Column = 2;

            tempLabel4 = uilabel(authorInfoSubPanel, 'Text', 'Author Email', 'HorizontalAlignment', 'right');
            tempLabel4.Layout.Row = 4; tempLabel4.Layout.Column = 1;
            obj.EmailEditField = uieditfield(authorInfoSubPanel, 'text');
            obj.EmailEditField.Layout.Row = 4; obj.EmailEditField.Layout.Column = 2;

            tempLabel5 = uilabel(authorInfoSubPanel, 'Text', 'Author Role', 'HorizontalAlignment', 'right');
            tempLabel5.Layout.Row = 5; tempLabel5.Layout.Column = 1;
            roleCheckGrid = uigridlayout(authorInfoSubPanel, [3 1], 'RowHeight', {'fit','fit','fit'}, 'Padding', [0 0 0 0], 'RowSpacing', 3);
            roleCheckGrid.Layout.Row = 5; roleCheckGrid.Layout.Column = 2;
            obj.IsFirstAuthorCheckBox = uicheckbox(roleCheckGrid, 'Text', '1st Author');
            obj.IsCustodianCheckBox = uicheckbox(roleCheckGrid, 'Text', 'Custodian');
            obj.IsCorrespondingCheckBox = uicheckbox(roleCheckGrid, 'Text', 'Corresponding');

            affiliationSubPanel = uigridlayout(detailsMainGrid);
            affiliationSubPanel.Layout.Row = 1; affiliationSubPanel.Layout.Column = 2;
            affiliationSubPanel.RowHeight = {'fit', 'fit', '1x'}; 
            affiliationSubPanel.ColumnWidth = {'1x', 'fit'};
            affiliationSubPanel.RowSpacing = 5;
            affiliationSubPanel.ColumnSpacing = 5;

            tempLabel6 = uilabel(affiliationSubPanel, 'Text', 'Affiliations/Institutes');
            tempLabel6.Layout.Row = 1; tempLabel6.Layout.Column = 1; 
            obj.AffiliationDropDown = uidropdown(affiliationSubPanel);
            obj.AffiliationDropDown.Layout.Row = 2; obj.AffiliationDropDown.Layout.Column = 1;
            
            affiliationButtonsSubGrid = uigridlayout(affiliationSubPanel, [2 1], 'RowHeight', {'fit', 'fit'}, 'Padding', [0 0 0 0], 'RowSpacing', 5);
            affiliationButtonsSubGrid.Layout.Row = 2; affiliationButtonsSubGrid.Layout.Column = 2;
            obj.AddAffiliationButton = uibutton(affiliationButtonsSubGrid, 'push', 'Text', '', 'Icon', fullfile(iconsPath, 'plus.png'), 'Tooltip', 'Add/Edit Affiliation');
            obj.RemoveAffiliationButton = uibutton(affiliationButtonsSubGrid, 'push', 'Text', '', 'Icon', fullfile(iconsPath, 'minus.png'), 'Tooltip', 'Remove Selected Affiliation');
        end
        
        function drawAuthorData(obj)
            authorList = obj.ParentApp.AuthorData.AuthorList;
            if isempty(authorList)
                obj.AuthorTable.Data = table('Size',[0 4],'VariableTypes',{'string','string','string','string'}, 'VariableNames', {'GivenName', 'FamilyName', 'Email', 'ORCID'});
                obj.clearAuthorDetails();
                return;
            end
            
            numAuthors = numel(authorList);
            data = cell(numAuthors, 4);
            for i = 1:numAuthors
                data{i,1} = char(authorList(i).givenName);
                data{i,2} = char(authorList(i).familyName);
                if isfield(authorList(i).contactInformation, 'email')
                    data{i,3} = authorList(i).contactInformation.email;
                else
                    data{i,3} = "";
                end
                
                orcid_val = ""; 
                if isfield(authorList(i), 'digitalIdentifier') && isstruct(authorList(i).digitalIdentifier)
                    if isfield(authorList(i).digitalIdentifier, 'identifierScheme') && ...
                       isfield(authorList(i).digitalIdentifier, 'identifier') && ...
                       strcmp(authorList(i).digitalIdentifier.identifierScheme,'ORCID')
                        orcid_val = char(authorList(i).digitalIdentifier.identifier);
                    end
                end
                data{i,4} = orcid_val;
            end
            obj.AuthorTable.Data = cell2table(data, 'VariableNames', {'GivenName', 'FamilyName', 'Email', 'ORCID'});
            
            if ~isempty(obj.SelectedAuthorIndex) && obj.SelectedAuthorIndex <= size(obj.AuthorTable.Data,1)
                obj.AuthorTable.Selection = obj.SelectedAuthorIndex;
            elseif ~isempty(obj.AuthorTable.Data)
                obj.AuthorTable.Selection = 1;
                obj.SelectedAuthorIndex = 1;
            else
                obj.SelectedAuthorIndex = [];
            end
            obj.populateAuthorDetails(); 
        end

        function populateAuthorDetails(obj)
            if isempty(obj.SelectedAuthorIndex) || obj.SelectedAuthorIndex > numel(obj.ParentApp.AuthorData.AuthorList)
                obj.clearAuthorDetails();
                return;
            end
            
            author = obj.ParentApp.AuthorData.AuthorList(obj.SelectedAuthorIndex);
            obj.GivenNameEditField.Value = char(author.givenName);
            obj.FamilyNameEditField.Value = char(author.familyName);
            obj.EmailEditField.Value = char(ifthenelse(isfield(author.contactInformation, 'email'), author.contactInformation.email, ""));
            
            if isfield(author, 'digitalIdentifier') && isstruct(author.digitalIdentifier) && ...
               isfield(author.digitalIdentifier, 'identifierScheme') && strcmp(author.digitalIdentifier.identifierScheme, 'ORCID') && ...
               isfield(author.digitalIdentifier, 'identifier')
                obj.IdentifierEditField.Value = char(author.digitalIdentifier.identifier);
            else
                obj.IdentifierEditField.Value = ''; 
            end
            
            currentRoles = author.authorRole;
            if ischar(currentRoles), currentRoles = {currentRoles}; elseif isempty(currentRoles), currentRoles = {}; end
            obj.IsFirstAuthorCheckBox.Value = any(strcmpi(currentRoles, '1st Author')); 
            obj.IsCustodianCheckBox.Value = any(strcmpi(currentRoles, 'Custodian'));
            obj.IsCorrespondingCheckBox.Value = any(strcmpi(currentRoles, 'Corresponding Author')); 

            obj.populateAffiliationDropDown();
        end

        function clearAuthorDetails(obj)
            obj.GivenNameEditField.Value = '';
            obj.FamilyNameEditField.Value = '';
            obj.EmailEditField.Value = '';
            obj.IdentifierEditField.Value = '';
            obj.IsFirstAuthorCheckBox.Value = false;
            obj.IsCustodianCheckBox.Value = false;
            obj.IsCorrespondingCheckBox.Value = false;
            obj.AffiliationDropDown.Items = {'(No affiliations)'};
            obj.AffiliationDropDown.ItemsData = {''};
            obj.AffiliationDropDown.Value = '';
        end

        function populateAffiliationDropDown(obj)
            if isempty(obj.SelectedAuthorIndex) || ~isfield(obj.ParentApp.AuthorData.AuthorList(obj.SelectedAuthorIndex), 'affiliation')
                obj.AffiliationDropDown.Items = {'(No affiliations)'};
                obj.AffiliationDropDown.ItemsData = {''};
                obj.AffiliationDropDown.Value = '';
                return;
            end

            affiliations = obj.ParentApp.AuthorData.AuthorList(obj.SelectedAuthorIndex).affiliation;
            if isempty(affiliations)
                obj.AffiliationDropDown.Items = {'(No affiliations)'};
                obj.AffiliationDropDown.ItemsData = {''};
                obj.AffiliationDropDown.Value = '';
                return;
            end

            orgDisplayNames = cell(1, numel(affiliations));
            orgDataValues = cell(1, numel(affiliations)); 
            for i = 1:numel(affiliations)
                if isfield(affiliations(i).memberOf, 'fullName')
                    orgDisplayNames{i} = char(affiliations(i).memberOf.fullName);
                    orgDataValues{i} = char(affiliations(i).memberOf.fullName); 
                else
                    orgDisplayNames{i} = '(Unnamed Organization)';
                    orgDataValues{i} = '';
                end
            end
            
            if isempty(orgDisplayNames)
                 obj.AffiliationDropDown.Items = {'(No affiliations)'};
                 obj.AffiliationDropDown.ItemsData = {''};
                 obj.AffiliationDropDown.Value = '';
            else
                obj.AffiliationDropDown.Items = orgDisplayNames;
                obj.AffiliationDropDown.ItemsData = orgDataValues;
                obj.AffiliationDropDown.Value = orgDataValues{1}; 
            end
        end
        
        function S_org = promptForOrganizationDetails(obj, organizationInfo, organizationIndexInParentList)
            S_org = struct.empty; 
            formName = 'Organization';
            
            if ~isfield(obj.ParentApp.UIForm, formName) || ~isvalid(obj.ParentApp.UIForm.(formName))
                obj.ParentApp.UIForm.(formName) = ndi.database.metadata_app.Apps.OrganizationForm();
            else
                obj.ParentApp.UIForm.(formName).reset(); 
                obj.ParentApp.UIForm.(formName).Visible = 'on';
            end
            
            formHandle = obj.ParentApp.UIForm.(formName);
            
            if nargin > 1 && ~isempty(organizationInfo)
                formHandle.setOrganizationDetails(organizationInfo);
            end
            
            ndi.gui.utility.centerFigure(formHandle.UIFigure, obj.ParentApp.NDIMetadataEditorUIFigure);
            formHandle.waitfor(); 
            
            if strcmp(formHandle.FinishState, "Save")
                S_org = formHandle.getOrganizationDetails();
                if nargin > 2 && ~isempty(organizationIndexInParentList) 
                    obj.ParentApp.insertOrganization(S_org, organizationIndexInParentList);
                else 
                    obj.ParentApp.insertOrganization(S_org); 
                end
            end
            formHandle.Visible = 'off';
        end

        % --- Callbacks ---
        function addAuthorPushed(obj)
            obj.ParentApp.AuthorData.addDefaultAuthorEntry();
            obj.drawAuthorData();
            if ~isempty(obj.AuthorTable.Data)
                obj.AuthorTable.Selection = size(obj.AuthorTable.Data,1); 
                obj.authorTableSelectionChanged(struct('Selection',obj.AuthorTable.Selection)); 
            end
            obj.ParentApp.saveDatasetInformationStruct();
        end

        function removeAuthorPushed(obj)
            if isempty(obj.SelectedAuthorIndex), return; end
            obj.ParentApp.AuthorData.removeItem(obj.SelectedAuthorIndex);
            obj.SelectedAuthorIndex = []; 
            obj.drawAuthorData();
            obj.ParentApp.saveDatasetInformationStruct();
        end

        function moveAuthorPushed(obj, direction)
            if isempty(obj.SelectedAuthorIndex), return; end
            obj.ParentApp.AuthorData.moveItem(obj.SelectedAuthorIndex, direction);
            if strcmp(direction, 'up') && obj.SelectedAuthorIndex > 1
                obj.SelectedAuthorIndex = obj.SelectedAuthorIndex - 1;
            elseif strcmp(direction, 'down') && obj.SelectedAuthorIndex < numel(obj.ParentApp.AuthorData.AuthorList)
                obj.SelectedAuthorIndex = obj.SelectedAuthorIndex + 1;
            end
            obj.drawAuthorData();
            obj.ParentApp.saveDatasetInformationStruct();
        end

        function authorTableSelectionChanged(obj, event)
            if isempty(event.Selection) || size(event.Selection,1) == 0
                obj.SelectedAuthorIndex = [];
            else
                obj.SelectedAuthorIndex = event.Selection(1); 
            end
            obj.populateAuthorDetails();
        end
        
        function authorDetailChanged(obj, event, fieldName)
            if isempty(obj.SelectedAuthorIndex), return; end
            author = obj.ParentApp.AuthorData.AuthorList(obj.SelectedAuthorIndex);
            newValue = event.Value; 

            switch fieldName
                case 'givenName', author.givenName = string(newValue);
                case 'familyName', author.familyName = string(newValue);
                case 'email', author.contactInformation.email = string(newValue);
                case 'identifier' 
                    author.digitalIdentifier.identifier = string(newValue);
                    author.digitalIdentifier.identifierScheme = "ORCID"; 
            end
            obj.ParentApp.AuthorData.AuthorList(obj.SelectedAuthorIndex) = author; 
            obj.ParentApp.saveDatasetInformationStruct();
            obj.drawAuthorData(); 
        end
        
        function authorRoleCheckboxChanged(obj, event, roleName)
            if isempty(obj.SelectedAuthorIndex), return; end
            isChecked = event.Value; 
            
            if isChecked
                obj.ParentApp.AuthorData.addAuthorRoles(obj.SelectedAuthorIndex, {roleName});
            else
                obj.ParentApp.AuthorData.removeAuthorRoles(obj.SelectedAuthorIndex, {roleName});
            end
            obj.ParentApp.saveDatasetInformationStruct();
        end

        function addAffiliationPushed(obj)
            if isempty(obj.SelectedAuthorIndex), obj.ParentApp.inform('Please select an author first.', 'No Author Selected'); return; end
            
            S_org = obj.promptForOrganizationDetails([], []); 

            if ~isempty(S_org) && isfield(S_org, 'fullName') && ~isempty(S_org.fullName)
                newAffiliation = struct('memberOf', struct('fullName', S_org.fullName));
                
                obj.ParentApp.AuthorData.addAffiliation(obj.SelectedAuthorIndex, newAffiliation);
                obj.populateAffiliationDropDown(); 
                obj.ParentApp.saveDatasetInformationStruct();
            end
        end
        
        function removeAffiliationPushed(obj)
            if isempty(obj.SelectedAuthorIndex), obj.ParentApp.inform('Please select an author first.', 'No Author Selected'); return; end
            
            selectedOrgFullName = obj.AffiliationDropDown.Value;
            if isempty(selectedOrgFullName) || strcmp(selectedOrgFullName, '(No affiliations)')
                obj.ParentApp.inform('Please select an affiliation from the dropdown to remove.', 'No Affiliation Selected');
                return;
            end

            author = obj.ParentApp.AuthorData.AuthorList(obj.SelectedAuthorIndex);
            affiliationIndexToRemove = -1;
            for i=1:numel(author.affiliation)
                if isfield(author.affiliation(i).memberOf, 'fullName') && strcmp(author.affiliation(i).memberOf.fullName, selectedOrgFullName)
                    affiliationIndexToRemove = i;
                    break;
                end
            end

            if affiliationIndexToRemove > 0
                obj.ParentApp.AuthorData.removeAffiliation(obj.SelectedAuthorIndex, affiliationIndexToRemove);
                obj.populateAffiliationDropDown();
                obj.ParentApp.saveDatasetInformationStruct();
            else
                obj.ParentApp.inform('Selected affiliation not found for removal.', 'Error');
            end
        end
        
        function affiliationDropDownChanged(obj, event)
        end
        
        function populateOrganizationDropdownInternal(obj)
            fprintf('DEBUG (AuthorDataGUI): populateOrganizationDropdownInternal called. Refreshing affiliations if author selected.\n');
            if ~isempty(obj.SelectedAuthorIndex)
                obj.populateAffiliationDropDown();
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
