classdef AuthorDataGUI < handle
    %AUTHORDATAGUI Manages the UI elements and interactions for Author Data.

    properties (Access = public)
        ParentApp % Handle to the MetadataEditorApp instance
        UIBaseContainer % The parent uipanel provided by MetadataEditorApp
        
        % UI Components
        AuthorTable matlab.ui.control.Table
        AddAuthorButton matlab.ui.control.Button
        RemoveAuthorButton matlab.ui.control.Button
        MoveAuthorUpButton matlab.ui.control.Button
        MoveAuthorDownButton matlab.ui.control.Button
        
        % Detail fields for selected author
        GivenNameEditField matlab.ui.control.EditField
        FamilyNameEditField matlab.ui.control.EditField
        EmailEditField matlab.ui.control.EditField
        IdentifierEditField matlab.ui.control.EditField
        IdentifierTypeDropDown matlab.ui.control.DropDown 
        
        AffiliationTable matlab.ui.control.Table 
        AddAffiliationButton matlab.ui.control.Button
        RemoveAffiliationButton matlab.ui.control.Button
        EditAffiliationButton matlab.ui.control.Button 
        
        AuthorRoleListBox matlab.ui.control.ListBox 
        AddAuthorRoleButton matlab.ui.control.Button
        RemoveAuthorRoleButton matlab.ui.control.Button
        AvailableRolesListBox matlab.ui.control.ListBox 
    end

    properties (Access = private)
        ResourcesPath % Should point to 'resources' directory
        AuthorDetailPanel matlab.ui.container.Panel
        AuthorListPanel matlab.ui.container.Panel
        AuthorRolePanel matlab.ui.container.Panel
        AffiliationPanel matlab.ui.container.Panel
        
        SelectedAuthorIndex 
        SelectedAffiliationIndex 
        SelectedAuthorRoleIndex 
    end

    methods
        function obj = AuthorDataGUI(parentAppHandle, uiParentContainer)
            obj.ParentApp = parentAppHandle;
            obj.UIBaseContainer = uiParentContainer;
            
            % Corrected ResourcesPath: should point to 'resources'
            if isprop(obj.ParentApp, 'ResourcesPath') && isfolder(obj.ParentApp.ResourcesPath)
                obj.ResourcesPath = obj.ParentApp.ResourcesPath;
                fprintf('DEBUG (AuthorDataGUI): Using ResourcesPath from ParentApp: %s\n', obj.ResourcesPath);
            else
                guiFilePath = fileparts(mfilename('fullpath')); % Path to +ndi/+database/+metadata_app/+class/
                % Go up two levels from +class to get to +metadata_app, then to resources
                obj.ResourcesPath = fullfile(guiFilePath, '..', '+Apps', 'resources'); 
                fprintf('DEBUG (AuthorDataGUI): ParentApp.ResourcesPath not found or invalid. Using calculated path: %s\n', obj.ResourcesPath);
                if ~isfolder(obj.ResourcesPath)
                    fprintf(2, 'Warning (AuthorDataGUI): Calculated ResourcesPath does not exist: %s\n', obj.ResourcesPath);
                    projectRootGuess = fullfile(guiFilePath, '..', '..', '..', '..'); 
                    fallbackPath = fullfile(projectRootGuess, 'resources');
                    if isfolder(fallbackPath)
                        obj.ResourcesPath = fallbackPath;
                        fprintf(1, 'Info (AuthorDataGUI): Using fallback project-level ResourcesPath: %s\n', obj.ResourcesPath);
                    else
                         fprintf(2, 'Warning (AuthorDataGUI): Fallback project-level ResourcesPath also does not exist: %s. Icons may not load.\n', fallbackPath);
                    end
                end
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
            obj.IdentifierTypeDropDown.ValueChangedFcn = @(~,event) obj.authorDetailChanged(event, 'identifierType');

            obj.AddAffiliationButton.ButtonPushedFcn = @(~,~) obj.addAffiliationPushed();
            obj.RemoveAffiliationButton.ButtonPushedFcn = @(~,~) obj.removeAffiliationPushed();
            obj.EditAffiliationButton.ButtonPushedFcn = @(~,~) obj.editAffiliationPushed();
            obj.AffiliationTable.CellSelectionCallback = @(src,event) obj.affiliationTableSelectionChanged(event);
            
            obj.AddAuthorRoleButton.ButtonPushedFcn = @(~,~) obj.addAuthorRolePushed();
            obj.RemoveAuthorRoleButton.ButtonPushedFcn = @(~,~) obj.removeAuthorRolePushed();
            obj.AuthorRoleListBox.ValueChangedFcn = @(~,event) obj.authorRoleSelectionChanged(event);

            obj.populateAvailableRolesListBox();
            obj.populateIdentifierTypeDropdown();
            obj.drawAuthorData(); 
        end

        function createAuthorUIComponents(obj)
            % Main grid for the Author Tab content
            authorTabGrid = uigridlayout(obj.UIBaseContainer, [1 2], 'ColumnWidth', {'1.5x', '2x'}, 'Padding', [5 5 5 5]);
            
            % --- Left Panel: Author List and Controls ---
            obj.AuthorListPanel = uipanel(authorTabGrid, 'Title', 'Authors', 'FontSize', 12);
            obj.AuthorListPanel.Layout.Row = 1; obj.AuthorListPanel.Layout.Column = 1;
            authorListGrid = uigridlayout(obj.AuthorListPanel, [2 1], 'RowHeight', {'1x', 'fit'}, 'Padding', [5 5 5 5]);
            
            obj.AuthorTable = uitable(authorListGrid, 'ColumnName', {'Given Name', 'Family Name', 'Email', 'ORCID'}, ...
                'RowName', {}, 'ColumnSortable', [true true true true], 'SelectionType', 'row', 'Multiselect', 'off');
            obj.AuthorTable.Layout.Row = 1; obj.AuthorTable.Layout.Column = 1;
            
            authorListButtonsGrid = uigridlayout(authorListGrid, [1 4], 'ColumnWidth', {'fit', 'fit', 'fit', 'fit'}, 'Padding', [0 0 0 0]);
            authorListButtonsGrid.Layout.Row = 2; authorListButtonsGrid.Layout.Column = 1;
            % Corrected icon paths
            obj.AddAuthorButton = uibutton(authorListButtonsGrid, 'push', 'Text', 'Add', 'Icon', fullfile(obj.ResourcesPath, 'icons', 'plus.png'));
            obj.RemoveAuthorButton = uibutton(authorListButtonsGrid, 'push', 'Text', 'Remove', 'Icon', fullfile(obj.ResourcesPath, 'icons', 'minus.png'));
            obj.MoveAuthorUpButton = uibutton(authorListButtonsGrid, 'push', 'Text', 'Up', 'Icon', fullfile(obj.ResourcesPath, 'icons', 'up.png'));
            obj.MoveAuthorDownButton = uibutton(authorListButtonsGrid, 'push', 'Text', 'Down', 'Icon', fullfile(obj.ResourcesPath, 'icons', 'down.png'));

            % --- Right Panel: Details of Selected Author ---
            obj.AuthorDetailPanel = uipanel(authorTabGrid, 'Title', 'Selected Author Details', 'FontSize', 12);
            obj.AuthorDetailPanel.Layout.Row = 1; obj.AuthorDetailPanel.Layout.Column = 2;
            detailsMainGrid = uigridlayout(obj.AuthorDetailPanel, [3 1], 'RowHeight', {'fit', '1x', '1x'}, 'Padding', [5 5 5 5]);

            % Basic Info Grid
            basicInfoGrid = uigridlayout(detailsMainGrid, [3 2], 'RowHeight', {'fit', 'fit', 'fit'}, 'ColumnWidth', {'fit', '1x'});
            basicInfoGrid.Layout.Row = 1; basicInfoGrid.Layout.Column = 1;
            
            uilabel(basicInfoGrid, 'Text', 'Given Name(s):', 'HorizontalAlignment', 'right');
            obj.GivenNameEditField = uieditfield(basicInfoGrid, 'text');
            uilabel(basicInfoGrid, 'Text', 'Family Name:', 'HorizontalAlignment', 'right');
            obj.FamilyNameEditField = uieditfield(basicInfoGrid, 'text');
            uilabel(basicInfoGrid, 'Text', 'Email:', 'HorizontalAlignment', 'right');
            obj.EmailEditField = uieditfield(basicInfoGrid, 'text');
            
            identifierGrid = uigridlayout(basicInfoGrid, [1 2], 'ColumnWidth', {'1x', '0.5x'}, 'Padding', [0 0 0 0]);
            identifierGrid.Layout.Row = 3; identifierGrid.Layout.Column = 2;
            obj.IdentifierEditField = uieditfield(identifierGrid, 'text');
            obj.IdentifierEditField.Layout.Column = 1;
            obj.IdentifierTypeDropDown = uidropdown(identifierGrid);
            obj.IdentifierTypeDropDown.Layout.Column = 2;
            
            identifierLabel = uilabel(basicInfoGrid, 'Text', 'Identifier:', 'HorizontalAlignment', 'right');
            identifierLabel.Layout.Row = 3;
            identifierLabel.Layout.Column = 1;

            % Affiliations Panel
            obj.AffiliationPanel = uipanel(detailsMainGrid, 'Title', 'Affiliations', 'FontSize', 10);
            obj.AffiliationPanel.Layout.Row = 2; obj.AffiliationPanel.Layout.Column = 1;
            affiliationGrid = uigridlayout(obj.AffiliationPanel, [1 2], 'ColumnWidth', {'1x', 'fit'}, 'Padding', [5 5 5 5]);
            obj.AffiliationTable = uitable(affiliationGrid, 'ColumnName', {'Organization'}, 'RowName', {}, 'SelectionType', 'row', 'Multiselect', 'off');
            obj.AffiliationTable.Layout.Column = 1;
            affiliationButtonsGrid = uigridlayout(affiliationGrid, [3 1], 'RowHeight', {'fit', 'fit', 'fit'}, 'Padding', [0 0 0 0]);
            affiliationButtonsGrid.Layout.Column = 2;
            obj.AddAffiliationButton = uibutton(affiliationButtonsGrid, 'push', 'Text', 'Add', 'Icon', fullfile(obj.ResourcesPath, 'icons', 'plus.png'));
            obj.EditAffiliationButton = uibutton(affiliationButtonsGrid, 'push', 'Text', 'Edit', 'Icon', fullfile(obj.ResourcesPath, 'icons', 'edit.png'));
            obj.RemoveAffiliationButton = uibutton(affiliationButtonsGrid, 'push', 'Text', 'Remove', 'Icon', fullfile(obj.ResourcesPath, 'icons', 'minus.png'));
            
            % Author Roles Panel
            obj.AuthorRolePanel = uipanel(detailsMainGrid, 'Title', 'Author Roles', 'FontSize', 10);
            obj.AuthorRolePanel.Layout.Row = 3; obj.AuthorRolePanel.Layout.Column = 1;
            authorRoleGrid = uigridlayout(obj.AuthorRolePanel, [1 3], 'ColumnWidth', {'1x', 'fit', '1x'}, 'Padding', [5 5 5 5]);
            
            obj.AuthorRoleListBox = uilistbox(authorRoleGrid, 'Multiselect', 'on');
            obj.AuthorRoleListBox.Layout.Column = 1;
            
            authorRoleButtonsGrid = uigridlayout(authorRoleGrid, [2 1], 'RowHeight', {'fit', 'fit'}, 'Padding', [0 10 0 10]); 
            authorRoleButtonsGrid.Layout.Column = 2;
            obj.AddAuthorRoleButton = uibutton(authorRoleButtonsGrid, 'push', 'Text', '< Add');
            obj.RemoveAuthorRoleButton = uibutton(authorRoleButtonsGrid, 'push', 'Text', 'Remove >');
            
            obj.AvailableRolesListBox = uilistbox(authorRoleGrid, 'Multiselect', 'on');
            obj.AvailableRolesListBox.Layout.Column = 3;
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
                data{i,1} = authorList(i).givenName;
                data{i,2} = authorList(i).familyName;
                if isfield(authorList(i).contactInformation, 'email')
                    data{i,3} = authorList(i).contactInformation.email;
                else
                    data{i,3} = "";
                end
                if isfield(authorList(i).digitalIdentifier, 'identifier')
                    data{i,4} = authorList(i).digitalIdentifier.identifier;
                else
                    data{i,4} = "";
                end
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
            
            if isfield(author.digitalIdentifier, 'identifierScheme') && ~isempty(author.digitalIdentifier.identifierScheme)
                obj.IdentifierTypeDropDown.Value = char(author.digitalIdentifier.identifierScheme);
            else
                obj.IdentifierTypeDropDown.Value = obj.IdentifierTypeDropDown.ItemsData{1}; 
            end
            obj.IdentifierEditField.Value = char(ifthenelse(isfield(author.digitalIdentifier, 'identifier'), author.digitalIdentifier.identifier, ""));
            
            obj.populateAffiliationTable();
            obj.populateAuthorRoleListBox();
        end

        function clearAuthorDetails(obj)
            obj.GivenNameEditField.Value = '';
            obj.FamilyNameEditField.Value = '';
            obj.EmailEditField.Value = '';
            obj.IdentifierEditField.Value = '';
            if ~isempty(obj.IdentifierTypeDropDown.ItemsData)
                obj.IdentifierTypeDropDown.Value = obj.IdentifierTypeDropDown.ItemsData{1};
            end
            obj.AffiliationTable.Data = table('Size',[0 1],'VariableTypes',{'string'},'VariableNames',{'Organization'});
            obj.AuthorRoleListBox.Items = {};
            obj.SelectedAffiliationIndex = [];
            obj.SelectedAuthorRoleIndex = [];
        end

        function populateAffiliationTable(obj)
            if isempty(obj.SelectedAuthorIndex) || ~isfield(obj.ParentApp.AuthorData.AuthorList(obj.SelectedAuthorIndex), 'affiliation')
                obj.AffiliationTable.Data = table('Size',[0 1],'VariableTypes',{'string'},'VariableNames',{'Organization'});
                return;
            end
            affiliations = obj.ParentApp.AuthorData.AuthorList(obj.SelectedAuthorIndex).affiliation;
            if isempty(affiliations)
                obj.AffiliationTable.Data = table('Size',[0 1],'VariableTypes',{'string'},'VariableNames',{'Organization'});
                return;
            end
            orgNames = cell(numel(affiliations), 1);
            for i = 1:numel(affiliations)
                if isfield(affiliations(i).memberOf, 'fullName')
                    orgNames{i} = char(affiliations(i).memberOf.fullName);
                else
                    orgNames{i} = '';
                end
            end
            obj.AffiliationTable.Data = table(orgNames, 'VariableNames', {'Organization'});
            obj.SelectedAffiliationIndex = []; 
        end

        function populateAuthorRoleListBox(obj)
            if isempty(obj.SelectedAuthorIndex) || ~isfield(obj.ParentApp.AuthorData.AuthorList(obj.SelectedAuthorIndex), 'authorRole')
                obj.AuthorRoleListBox.Items = {};
                return;
            end
            roles = obj.ParentApp.AuthorData.AuthorList(obj.SelectedAuthorIndex).authorRole;
            if isempty(roles), roles = {}; end
            if ischar(roles), roles = {roles}; end 
            obj.AuthorRoleListBox.Items = roles;
            obj.AuthorRoleListBox.Value = {}; 
            obj.SelectedAuthorRoleIndex = [];
        end

        function populateAvailableRolesListBox(obj)
            availableRoles = {'Conceptualization', 'Data curation', 'Formal Analysis', ...
                              'Funding acquisition', 'Investigation', 'Methodology', ...
                              'Project administration', 'Resources', 'Software', ...
                              'Supervision', 'Validation', 'Visualization', ...
                              'Writing – original draft', 'Writing – review & editing'};
            obj.AvailableRolesListBox.Items = availableRoles;
        end
        
        function populateIdentifierTypeDropdown(obj)
            obj.IdentifierTypeDropDown.Items = {'ORCID', 'ResearcherID', 'ScopusID', 'Other'};
            obj.IdentifierTypeDropDown.ItemsData = {'ORCID', 'ResearcherID', 'ScopusID', 'Other'};
            obj.IdentifierTypeDropDown.Value = 'ORCID'; 
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
            obj.AuthorTable.Selection = size(obj.AuthorTable.Data,1); 
            obj.authorTableSelectionChanged(struct('Selection',obj.AuthorTable.Selection)); 
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
                case 'identifier', author.digitalIdentifier.identifier = string(newValue);
                case 'identifierType', author.digitalIdentifier.identifierScheme = string(newValue);
            end
            obj.ParentApp.AuthorData.AuthorList(obj.SelectedAuthorIndex) = author; 
            obj.ParentApp.saveDatasetInformationStruct();
            obj.drawAuthorData(); 
        end

        function addAffiliationPushed(obj)
            if isempty(obj.SelectedAuthorIndex), obj.ParentApp.inform('Please select an author first.', 'No Author Selected'); return; end
            
            S_org = obj.promptForOrganizationDetails([], []); 

            if ~isempty(S_org) && isfield(S_org, 'fullName') && ~isempty(S_org.fullName)
                newAffiliation = struct('memberOf', struct('fullName', S_org.fullName));
                
                obj.ParentApp.AuthorData.addAffiliation(obj.SelectedAuthorIndex, newAffiliation);
                obj.populateAffiliationTable();
                obj.ParentApp.saveDatasetInformationStruct();
            end
        end
        
        function editAffiliationPushed(obj)
            if isempty(obj.SelectedAuthorIndex) || isempty(obj.SelectedAffiliationIndex)
                obj.ParentApp.inform('Please select an author and an affiliation to edit.', 'Selection Missing');
                return;
            end
            
            author = obj.ParentApp.AuthorData.AuthorList(obj.SelectedAuthorIndex);
            if obj.SelectedAffiliationIndex > numel(author.affiliation)
                obj.ParentApp.alert('Selected affiliation index is out of bounds.','Error'); return;
            end
            
            currentAffiliationMemberOfStruct = author.affiliation(obj.SelectedAffiliationIndex).memberOf; 
            
            orgToEdit = struct('fullName', currentAffiliationMemberOfStruct.fullName); 
            orgIdxInParentList = []; 
            if isprop(obj.ParentApp, 'Organizations') && ~isempty(obj.ParentApp.Organizations)
                orgIndices = find(arrayfun(@(x) strcmp(x.fullName, currentAffiliationMemberOfStruct.fullName), obj.ParentApp.Organizations));
                if ~isempty(orgIndices)
                    orgIdxInParentList = orgIndices(1);
                    orgToEdit = obj.ParentApp.Organizations(orgIdxInParentList);
                end
            end
            
            S_org = obj.promptForOrganizationDetails(orgToEdit, orgIdxInParentList); 

            if ~isempty(S_org) && isfield(S_org, 'fullName') && ~isempty(S_org.fullName)
                updatedAffiliation = struct('memberOf', struct('fullName', S_org.fullName));
                
                obj.ParentApp.AuthorData.updateAffiliation(obj.SelectedAuthorIndex, obj.SelectedAffiliationIndex, updatedAffiliation);
                obj.populateAffiliationTable();
                obj.ParentApp.saveDatasetInformationStruct();
            end
        end

        function removeAffiliationPushed(obj)
            if isempty(obj.SelectedAuthorIndex) || isempty(obj.SelectedAffiliationIndex)
                obj.ParentApp.inform('Please select an affiliation to remove.', 'No Affiliation Selected');
                return;
            end
            obj.ParentApp.AuthorData.removeAffiliation(obj.SelectedAuthorIndex, obj.SelectedAffiliationIndex);
            obj.populateAffiliationTable();
            obj.ParentApp.saveDatasetInformationStruct();
        end
        
        function affiliationTableSelectionChanged(obj, event)
            if isempty(event.Selection) || size(event.Selection,1) == 0
                obj.SelectedAffiliationIndex = [];
            else
                obj.SelectedAffiliationIndex = event.Selection(1);
            end
        end

        function addAuthorRolePushed(obj)
            if isempty(obj.SelectedAuthorIndex), obj.ParentApp.inform('Please select an author first.', 'No Author Selected'); return; end
            selectedRolesToAdd = obj.AvailableRolesListBox.Value;
            if isempty(selectedRolesToAdd), obj.ParentApp.inform('Please select a role to add from the available roles.', 'No Role Selected'); return; end
            
            if ~iscell(selectedRolesToAdd), selectedRolesToAdd = {selectedRolesToAdd}; end 
            
            obj.ParentApp.AuthorData.addAuthorRoles(obj.SelectedAuthorIndex, selectedRolesToAdd);
            obj.populateAuthorRoleListBox(); 
            obj.ParentApp.saveDatasetInformationStruct();
        end

        function removeAuthorRolePushed(obj)
            if isempty(obj.SelectedAuthorIndex) || isempty(obj.AuthorRoleListBox.Value)
                obj.ParentApp.inform('Please select an author and a role to remove.', 'Selection Missing');
                return;
            end
            rolesToRemove = obj.AuthorRoleListBox.Value;
            if ~iscell(rolesToRemove), rolesToRemove = {rolesToRemove}; end
            
            obj.ParentApp.AuthorData.removeAuthorRoles(obj.SelectedAuthorIndex, rolesToRemove);
            obj.populateAuthorRoleListBox(); 
            obj.ParentApp.saveDatasetInformationStruct();
        end
        
        function authorRoleSelectionChanged(obj, event)
        end
        
        function populateOrganizationDropdownInternal(obj)
            fprintf('DEBUG (AuthorDataGUI): populateOrganizationDropdownInternal called (currently a placeholder).\n');
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
