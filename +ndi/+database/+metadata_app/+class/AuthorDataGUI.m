classdef AuthorDataGUI < handle
    %AUTHORDATAGUI Manages the GUI elements, creation, and interactions for Author Data.

    properties (Access = public) 
        ParentApp % Handle to the main MetadataEditorApp instance
        UIBaseContainer % The parent uipanel provided by MetadataEditorApp
        UIForm struct

        
        % Handles to UI Components (created and owned by this class)
        AuthorListBox
        AddAuthorButton
        RemoveAuthorButton
        MoveAuthorUpButton
        MoveAuthorDownButton
        
        GivenNameEditField
        FamilyNameEditField
        DigitalIdentifierEditField
        SearchOrcidButton
        AuthorEmailEditField
        AuthorRoleTree
        
        OrganizationDropDown
        AddAffiliationButton
        AffiliationListBox
        RemoveAffiliationButton
        % MoveAffiliationUpButton % Keep as comments if functionality remains hidden
        % MoveAffiliationDownButton

        % Labels (created by this class)
        GivenNameEditFieldLabel
        FamilyNameEditFieldLabel
        DigitalIdentifierEditFieldLabel
        AuthorEmailEditFieldLabel
        AuthorRoleLabel
        AffiliationsListBoxLabel
        AuthorListBoxLabel
        
        % Tree Nodes for AuthorRoleTree
        FirstAuthorNode
        CustodianNode
        CorrespondingNode
    end

    properties (Access = private)
        ResourcesPath % Path to resources, specifically icons
    end

    methods
        function obj = AuthorDataGUI(parentAppHandle, uiParentContainerForAuthors)
            %AUTHORDATAGUI Construct an instance of this class.
            %   parentAppHandle: Handle to the main MetadataEditorApp.
            %   uiParentContainerForAuthors: The uicontainer (e.g., uipanel or uigridlayout cell)
            %                                where author UI elements should be built.
            
            obj.ParentApp = parentAppHandle;
            obj.UIBaseContainer = uiParentContainerForAuthors;
            obj.UIForm(1).Organization = [];
            
            guiFilePath = fileparts(mfilename('fullpath')); 
            obj.ResourcesPath = fullfile(guiFilePath, '..', '+Apps', 'resources');
            
            obj.createAuthorUIComponents();
            obj.loadOrganizations();
        end

        function loadOrganizations(app)
            import ndi.database.metadata_app.fun.loadUserInstances
            app.ParentApp.Organizations = loadUserInstances('affiliation_organization');
            app.populateOrganizationDropdownInternal();
        end

        function initialize(obj)
            %INITIALIZE Sets up callbacks and initial state for author UI.
            
            obj.AddAuthorButton.ButtonPushedFcn = @(~,~) obj.addAuthorButtonPushed();
            obj.RemoveAuthorButton.ButtonPushedFcn = @(~,~) obj.removeAuthorButtonPushed();
            obj.MoveAuthorUpButton.ButtonPushedFcn = @(~,~) obj.moveAuthorUpButtonPushed();
            obj.MoveAuthorDownButton.ButtonPushedFcn = @(~,~) obj.moveAuthorDownButtonPushed();
            obj.AuthorListBox.ValueChangedFcn = @(~,~) obj.authorListBoxValueChanged();
            
            obj.GivenNameEditField.ValueChangedFcn = @(~,~) obj.givenNameEditFieldValueChanged();
            obj.GivenNameEditField.ValueChangingFcn = @(s,e) obj.givenNameEditFieldValueChanging(e);
            obj.FamilyNameEditField.ValueChangedFcn = @(~,~) obj.familyNameEditFieldValueChanged();
            obj.FamilyNameEditField.ValueChangingFcn = @(s,e) obj.familyNameEditFieldValueChanging(e);
            obj.DigitalIdentifierEditField.ValueChangedFcn = @(~,~) obj.digitalIdentifierEditFieldValueChanged();
            obj.SearchOrcidButton.ButtonPushedFcn = @(~,~) obj.searchOrcidButtonPushed();
            obj.AuthorEmailEditField.ValueChangedFcn = @(~,~) obj.authorEmailEditFieldValueChanged();
            obj.AuthorRoleTree.CheckedNodesChangedFcn = @(s,e) obj.authorRoleTreeCheckedNodesChanged(e);
            
            obj.AddAffiliationButton.ButtonPushedFcn = @(~,~) obj.addAffiliationButtonPushed();
            obj.RemoveAffiliationButton.ButtonPushedFcn = @(~,~) obj.removeAffiliationButtonPushed();
            
            obj.drawAuthorData();
        end

        function createAuthorUIComponents(obj)
            parentContainer = obj.UIBaseContainer;
            iconsPath = fullfile(obj.ResourcesPath,'icons'); 

            authorMainPanelGridLayout = uigridlayout(parentContainer);
            authorMainPanelGridLayout.ColumnWidth = {250, '1x', '1x'}; 
            authorMainPanelGridLayout.RowHeight = {'1x'}; 
            authorMainPanelGridLayout.ColumnSpacing = 30; 
            authorMainPanelGridLayout.Padding = [10 10 10 10]; 

            authorContentLeftGridLayout = uigridlayout(authorMainPanelGridLayout);
            authorContentLeftGridLayout.Layout.Row = 1;
            authorContentLeftGridLayout.Layout.Column = 1;
            authorContentLeftGridLayout.ColumnWidth = {'1x'};
            authorContentLeftGridLayout.RowHeight = {23, '1x'}; 
            authorContentLeftGridLayout.Padding = [0 0 0 0];
            authorContentLeftGridLayout.RowSpacing = 5;

            obj.AuthorListBoxLabel = uilabel(authorContentLeftGridLayout, 'Text', 'Authors:');
            obj.AuthorListBoxLabel.Layout.Row = 1;obj.AuthorListBoxLabel.Layout.Column = 1;

            authorListBoxGridLayoutInternal = uigridlayout(authorContentLeftGridLayout); 
            authorListBoxGridLayoutInternal.Layout.Row = 2; authorListBoxGridLayoutInternal.Layout.Column = 1;
            authorListBoxGridLayoutInternal.ColumnWidth = {'1x', 30}; 
            authorListBoxGridLayoutInternal.RowHeight = {'1x'};
            authorListBoxGridLayoutInternal.Padding = [0 0 0 0];
            authorListBoxGridLayoutInternal.ColumnSpacing = 5;

            obj.AuthorListBox = uilistbox(authorListBoxGridLayoutInternal);
            obj.AuthorListBox.Layout.Row = 1; obj.AuthorListBox.Layout.Column = 1;
            obj.AuthorListBox.Items = {}; obj.AuthorListBox.Value = {};

            authorListBoxButtonPanel = uigridlayout(authorListBoxGridLayoutInternal); 
            authorListBoxButtonPanel.Layout.Row = 1; authorListBoxButtonPanel.Layout.Column = 2;
            authorListBoxButtonPanel.RowHeight = {23, 23, 10, 23, 23, '1x'}; 
            authorListBoxButtonPanel.ColumnWidth = {'1x'};
            authorListBoxButtonPanel.Padding = [0 0 0 0];
            authorListBoxButtonPanel.RowSpacing = 5;

            obj.AddAuthorButton = uibutton(authorListBoxButtonPanel, 'push', 'Text', '', 'Icon', fullfile(iconsPath, 'plus.png'));
            obj.AddAuthorButton.Layout.Row = 1; obj.AddAuthorButton.Layout.Column = 1;
            obj.RemoveAuthorButton = uibutton(authorListBoxButtonPanel, 'push', 'Text', '', 'Icon', fullfile(iconsPath, 'minus.png'));
            obj.RemoveAuthorButton.Layout.Row = 2; obj.RemoveAuthorButton.Layout.Column = 1;
            obj.MoveAuthorUpButton = uibutton(authorListBoxButtonPanel, 'push', 'Text', '', 'Icon', fullfile(iconsPath, 'up.png'));
            obj.MoveAuthorUpButton.Layout.Row = 4; obj.MoveAuthorUpButton.Layout.Column = 1;
            obj.MoveAuthorDownButton = uibutton(authorListBoxButtonPanel, 'push', 'Text', '', 'Icon', fullfile(iconsPath, 'down.png'));
            obj.MoveAuthorDownButton.Layout.Row = 5; obj.MoveAuthorDownButton.Layout.Column = 1;

            authorContentCenterGridLayout = uigridlayout(authorMainPanelGridLayout);
            authorContentCenterGridLayout.Layout.Row = 1;
            authorContentCenterGridLayout.Layout.Column = 2;
            authorContentCenterGridLayout.ColumnWidth = {'1x'};
            % Adjusted RowHeight: Label, Field, Spacer, Label, Field, Spacer, Label, Field+Button, Spacer, Label, Field, Spacer, Role Label, Role Tree (flexible)
            authorContentCenterGridLayout.RowHeight = {23, 23, 10, 23, 23, 10, 23, 23, 10, 23, 23, 10, 23, '1x'}; 
            authorContentCenterGridLayout.Padding = [0 0 0 0];
            authorContentCenterGridLayout.RowSpacing = 5;

            obj.GivenNameEditFieldLabel = uilabel(authorContentCenterGridLayout, 'Text', 'Given Name');
            obj.GivenNameEditFieldLabel.Layout.Row = 1; obj.GivenNameEditFieldLabel.Layout.Column = 1;
            obj.GivenNameEditField = uieditfield(authorContentCenterGridLayout, 'text');
            obj.GivenNameEditField.Layout.Row = 2; obj.GivenNameEditField.Layout.Column = 1;

            obj.FamilyNameEditFieldLabel = uilabel(authorContentCenterGridLayout, 'Text', 'Family Name');
            obj.FamilyNameEditFieldLabel.Layout.Row = 4; obj.FamilyNameEditFieldLabel.Layout.Column = 1;
            obj.FamilyNameEditField = uieditfield(authorContentCenterGridLayout, 'text');
            obj.FamilyNameEditField.Layout.Row = 5; obj.FamilyNameEditField.Layout.Column = 1;

            obj.DigitalIdentifierEditFieldLabel = uilabel(authorContentCenterGridLayout, 'Text', 'Digital Identifier (ORCID)');
            obj.DigitalIdentifierEditFieldLabel.Layout.Row = 7; obj.DigitalIdentifierEditFieldLabel.Layout.Column = 1;
            
            authorOrcidGridLayout = uigridlayout(authorContentCenterGridLayout); 
            authorOrcidGridLayout.Layout.Row = 8; authorOrcidGridLayout.Layout.Column = 1;
            authorOrcidGridLayout.ColumnWidth = {'1x', 30}; authorOrcidGridLayout.RowHeight = {'1x'};
            authorOrcidGridLayout.Padding = [0 0 0 0]; authorOrcidGridLayout.ColumnSpacing = 5;
            obj.DigitalIdentifierEditField = uieditfield(authorOrcidGridLayout, 'text', 'Placeholder', 'Example: 0000-0002-1825-0097');
            obj.DigitalIdentifierEditField.Layout.Row = 1; obj.DigitalIdentifierEditField.Layout.Column = 1;
            obj.SearchOrcidButton = uibutton(authorOrcidGridLayout, 'push', 'Text', '', 'Icon', fullfile(iconsPath, 'search.png'));
            obj.SearchOrcidButton.Layout.Row = 1; obj.SearchOrcidButton.Layout.Column = 2;

            obj.AuthorEmailEditFieldLabel = uilabel(authorContentCenterGridLayout, 'Text', 'Author Email');
            obj.AuthorEmailEditFieldLabel.Layout.Row = 10; obj.AuthorEmailEditFieldLabel.Layout.Column = 1;
            obj.AuthorEmailEditField = uieditfield(authorContentCenterGridLayout, 'text');
            obj.AuthorEmailEditField.Layout.Row = 11; obj.AuthorEmailEditField.Layout.Column = 1;
            
            obj.AuthorRoleLabel = uilabel(authorContentCenterGridLayout, 'Text', 'Author Role(s)');
            obj.AuthorRoleLabel.Layout.Row = 13; obj.AuthorRoleLabel.Layout.Column = 1;
            obj.AuthorRoleTree = uitree(authorContentCenterGridLayout, 'checkbox');
            obj.AuthorRoleTree.Layout.Row = 14; obj.AuthorRoleTree.Layout.Column = 1; % This row is now '1x'
            obj.FirstAuthorNode = uitreenode(obj.AuthorRoleTree, 'Text', '1st Author', 'NodeData', '1st Author');
            obj.CustodianNode = uitreenode(obj.AuthorRoleTree, 'Text', 'Custodian', 'NodeData', 'Custodian');
            obj.CorrespondingNode = uitreenode(obj.AuthorRoleTree, 'Text', 'Corresponding', 'NodeData', 'Corresponding');

            authorContentRightGridLayout = uigridlayout(authorMainPanelGridLayout);
            authorContentRightGridLayout.Layout.Row = 1;
            authorContentRightGridLayout.Layout.Column = 3;
            authorContentRightGridLayout.ColumnWidth = {'1x'};
            authorContentRightGridLayout.RowHeight = {23, 23, '1x'}; 
            authorContentRightGridLayout.Padding = [0 0 0 0];
            authorContentRightGridLayout.RowSpacing = 5;

            obj.AffiliationsListBoxLabel = uilabel(authorContentRightGridLayout, 'Text', 'Affiliations/Institutes');
            obj.AffiliationsListBoxLabel.Layout.Row = 1; obj.AffiliationsListBoxLabel.Layout.Column = 1;

            affiliationSelectionGridLayout = uigridlayout(authorContentRightGridLayout); 
            affiliationSelectionGridLayout.Layout.Row = 2; affiliationSelectionGridLayout.Layout.Column = 1;
            affiliationSelectionGridLayout.ColumnWidth = {'1x', 30}; affiliationSelectionGridLayout.RowHeight = {'1x'};
            affiliationSelectionGridLayout.Padding = [0 0 0 0]; affiliationSelectionGridLayout.ColumnSpacing = 5;
            obj.OrganizationDropDown = uidropdown(affiliationSelectionGridLayout, 'Editable', 'on', 'Placeholder', 'Select or enter organization');
            obj.OrganizationDropDown.Layout.Row = 1; obj.OrganizationDropDown.Layout.Column = 1;
            obj.AddAffiliationButton = uibutton(affiliationSelectionGridLayout, 'push', 'Text', '', 'Icon', fullfile(iconsPath, 'plus.png'));
            obj.AddAffiliationButton.Layout.Row = 1; obj.AddAffiliationButton.Layout.Column = 2;
            
            affiliationListBoxGridLayoutInternal = uigridlayout(authorContentRightGridLayout); 
            affiliationListBoxGridLayoutInternal.Layout.Row = 3; affiliationListBoxGridLayoutInternal.Layout.Column = 1;
            affiliationListBoxGridLayoutInternal.ColumnWidth = {'1x', 30}; affiliationListBoxGridLayoutInternal.RowHeight = {'1x'};
            affiliationListBoxGridLayoutInternal.Padding = [0 0 0 0]; affiliationListBoxGridLayoutInternal.ColumnSpacing = 5;
            obj.AffiliationListBox = uilistbox(affiliationListBoxGridLayoutInternal);
            obj.AffiliationListBox.Layout.Row = 1; obj.AffiliationListBox.Layout.Column = 1;
            obj.AffiliationListBox.Items = {}; obj.AffiliationListBox.Value = {};
            
            affiliationRemoveButtonPanel = uigridlayout(affiliationListBoxGridLayoutInternal);
            affiliationRemoveButtonPanel.Layout.Row = 1; affiliationRemoveButtonPanel.Layout.Column = 2;
            affiliationRemoveButtonPanel.RowHeight = {23, '1x'}; affiliationRemoveButtonPanel.ColumnWidth = {'1x'};
            affiliationRemoveButtonPanel.Padding = [0 0 0 0]; affiliationRemoveButtonPanel.RowSpacing = 5;
            obj.RemoveAffiliationButton = uibutton(affiliationRemoveButtonPanel, 'push', 'Text', '', 'Icon', fullfile(iconsPath, 'minus.png'));
            obj.RemoveAffiliationButton.Layout.Row = 1; obj.RemoveAffiliationButton.Layout.Column = 1;
        end
        
        function drawAuthorData(obj)
            obj.updateAuthorListbox();
            if ~isempty(obj.ParentApp.AuthorData.AuthorList) && ~isempty(obj.AuthorListBox.Items)
                try
                    if isempty(obj.AuthorListBox.Value) || ~any(strcmp(obj.AuthorListBox.Value, obj.AuthorListBox.Items))
                        obj.AuthorListBox.Value = obj.AuthorListBox.Items{1};
                    end
                    authorIndexToDisplay = obj.getSelectedAuthorIndex();
                    if isempty(authorIndexToDisplay) && ~isempty(obj.ParentApp.AuthorData.AuthorList)
                        authorIndexToDisplay = 1; 
                    end
                    if ~isempty(authorIndexToDisplay)
                        currentAuthorStruct = obj.ParentApp.AuthorData.getItem(authorIndexToDisplay);
                        obj.fillAuthorInputFieldsFromStruct(currentAuthorStruct);
                    else
                         obj.fillAuthorInputFieldsFromStruct(ndi.database.metadata_app.class.AuthorData.getDefaultAuthorItem());
                    end
                catch ME_authUI
                     fprintf(2, 'Error updating author UI elements in drawAuthorData: %s\n', ME_authUI.message);
                     emptyAuthorStructUI = ndi.database.metadata_app.class.AuthorData.getDefaultAuthorItem();
                     obj.fillAuthorInputFieldsFromStruct(emptyAuthorStructUI);
                end
            else 
                emptyAuthorStructUI = ndi.database.metadata_app.class.AuthorData.getDefaultAuthorItem();
                obj.fillAuthorInputFieldsFromStruct(emptyAuthorStructUI);
                obj.AuthorListBox.Items = {};
                obj.AuthorListBox.Value = {};
            end
        end

        function updateAuthorListbox(obj)
            authorStructList = obj.ParentApp.AuthorData.toStructs(); 
            if isempty(authorStructList) || (isstruct(authorStructList) && numel(authorStructList)==1 && isempty(fieldnames(authorStructList(1))))
                if isstruct(authorStructList) && numel(authorStructList)==1 && isempty(fieldnames(authorStructList(1)))
                    authorStructList = repmat(ndi.database.metadata_app.class.AuthorData.getDefaultAuthorItem(),0,1);
                end
            end

            if isempty(authorStructList) || (numel(authorStructList)==1 && isempty(authorStructList(1).givenName) && isempty(authorStructList(1).familyName) && numel(obj.ParentApp.AuthorData.AuthorList)==0)
                obj.AuthorListBox.Items = {};
                obj.AuthorListBox.Value = {};
                return;
            end
            
            fullNames = cell(numel(authorStructList), 1);
            for i = 1:numel(authorStructList)
                given = char(authorStructList(i).givenName);
                family = char(authorStructList(i).familyName);
                fullName = strtrim(strjoin({given, family}, ' '));
                if isempty(fullName)
                    fullName = sprintf('Author %d', i);
                end
                fullNames{i} = fullName;
            end
            
            currentSelection = obj.AuthorListBox.Value;
            obj.AuthorListBox.Items = fullNames;

            if ~isempty(fullNames)
                if ~isempty(currentSelection) && any(strcmp(fullNames, currentSelection))
                    obj.AuthorListBox.Value = currentSelection; 
                else
                    obj.AuthorListBox.Value = fullNames{1}; 
                end
            else
                obj.AuthorListBox.Value = {};
            end
        end

        function fillAuthorInputFieldsFromStruct(obj, authorStruct)
            obj.GivenNameEditField.Value = char(authorStruct.givenName);
            obj.FamilyNameEditField.Value = char(authorStruct.familyName);
            obj.AuthorEmailEditField.Value = char(authorStruct.contactInformation.email);
            obj.DigitalIdentifierEditField.Value = char(authorStruct.digitalIdentifier.identifier);
            
            obj.AffiliationListBox.Items = {}; 
            if isfield(authorStruct, 'affiliation') && ~isempty(authorStruct.affiliation) && isstruct(authorStruct.affiliation)
                affiliationStructArray = authorStruct.affiliation;
                orgNames = cell(1,0); 
                for i=1:numel(affiliationStructArray)
                    if isfield(affiliationStructArray(i),'memberOf') && isstruct(affiliationStructArray(i).memberOf) && isfield(affiliationStructArray(i).memberOf,'fullName')
                        orgNames{end+1} = char(affiliationStructArray(i).memberOf.fullName); %#ok<AGROW>
                    end
                end
                obj.AffiliationListBox.Items = orgNames;
            end
            obj.ParentApp.setCheckedNodesFromData(obj.AuthorRoleTree, authorStruct.authorRole);
        end
        
        function idx = getSelectedAuthorIndex(obj)
            idx = [];
            if ~isempty(obj.AuthorListBox.Value)
                isSelected = strcmp(obj.AuthorListBox.Items, obj.AuthorListBox.Value);
                idx = find(isSelected, 1);
            end
        end
        
        function updateCurrentAuthorProperty(obj, propertyName, propertyValue)
            authorIndex = obj.getSelectedAuthorIndex();
            if isempty(authorIndex)
                if isempty(obj.ParentApp.AuthorData.AuthorList)
                    obj.ParentApp.AuthorData.addDefaultAuthorEntry();
                    obj.updateAuthorListbox(); 
                    authorIndex = 1; 
                    if ~isempty(obj.AuthorListBox.Items)
                        obj.AuthorListBox.Value = obj.AuthorListBox.Items{1};
                    end
                else
                    authorIndex = 1; 
                     if ~isempty(obj.AuthorListBox.Items)
                        obj.AuthorListBox.Value = obj.AuthorListBox.Items{1};
                    end
                end
            end
            
            obj.ParentApp.AuthorData.updateProperty(propertyName, propertyValue, authorIndex);
            obj.ParentApp.saveDatasetInformationStruct(); 
        end

        function populateOrganizationDropdownInternal(obj)
            currentItems = {};
            if isprop(obj.ParentApp, 'Organizations') && ~isempty(obj.ParentApp.Organizations)
                currentItems = {obj.ParentApp.Organizations.fullName};
            end
            
            obj.OrganizationDropDown.Items = currentItems;
            
            if ~isempty(currentItems)
                obj.OrganizationDropDown.Value = ''; 
            else
                obj.OrganizationDropDown.Value = ''; 
            end
        end

        % --- Callbacks ---
        function addAuthorButtonPushed(obj)
            obj.ParentApp.AuthorData.addDefaultAuthorEntry();
            obj.updateAuthorListbox();
            if ~isempty(obj.AuthorListBox.Items)
                obj.AuthorListBox.Value = obj.AuthorListBox.Items{end}; 
                obj.authorListBoxValueChanged(); 
            end
            obj.ParentApp.saveDatasetInformationStruct();
        end

        function removeAuthorButtonPushed(obj)
            idx = obj.getSelectedAuthorIndex();
            if ~isempty(idx)
                obj.ParentApp.AuthorData.removeItem(idx);
                obj.drawAuthorData(); 
                obj.ParentApp.saveDatasetInformationStruct();
            else
                obj.ParentApp.inform('Please select an author to remove.', 'No Author Selected');
            end
        end

        function moveAuthorUpButtonPushed(obj)
            oldIdx = obj.getSelectedAuthorIndex();
            if ~isempty(oldIdx) && oldIdx > 1
                newIdx = oldIdx - 1;
                obj.ParentApp.AuthorData.reorderItems(newIdx, oldIdx);
                obj.updateAuthorListbox(); 
                obj.AuthorListBox.Value = obj.AuthorListBox.Items{newIdx}; 
                obj.ParentApp.saveDatasetInformationStruct();
            end
        end

        function moveAuthorDownButtonPushed(obj)
            oldIdx = obj.getSelectedAuthorIndex();
            if ~isempty(oldIdx) && oldIdx < numel(obj.AuthorListBox.Items)
                newIdx = oldIdx + 1;
                obj.ParentApp.AuthorData.reorderItems(newIdx, oldIdx);
                obj.updateAuthorListbox();
                obj.AuthorListBox.Value = obj.AuthorListBox.Items{newIdx};
                obj.ParentApp.saveDatasetInformationStruct();
            end
        end

        function authorListBoxValueChanged(obj)
            idx = obj.getSelectedAuthorIndex();
            if ~isempty(idx)
                authorStruct = obj.ParentApp.AuthorData.getItem(idx);
                obj.fillAuthorInputFieldsFromStruct(authorStruct);
            else 
                obj.fillAuthorInputFieldsFromStruct(ndi.database.metadata_app.class.AuthorData.getDefaultAuthorItem());
            end
        end
        
        function onAuthorNameChangedInternal(obj, fieldName, fieldValue, isTransient)
            authorIndex = obj.getSelectedAuthorIndex();
            if isempty(authorIndex)
                if isempty(obj.ParentApp.AuthorData.AuthorList)
                    obj.ParentApp.AuthorData.addDefaultAuthorEntry();
                    obj.updateAuthorListbox();
                    if ~isempty(obj.AuthorListBox.Items), obj.AuthorListBox.Value = obj.AuthorListBox.Items{1}; end
                    authorIndex = 1;
                else
                    authorIndex = 1; 
                    if ~isempty(obj.AuthorListBox.Items), obj.AuthorListBox.Value = obj.AuthorListBox.Items{1}; end
                end
            end
            
            obj.ParentApp.AuthorData.updateProperty(fieldName, fieldValue, authorIndex);
            
            currentAuthorStruct = obj.ParentApp.AuthorData.getItem(authorIndex);
            given = currentAuthorStruct.givenName;
            family = currentAuthorStruct.familyName;
            fullName = strtrim(strjoin({given, family},' '));
            if isempty(fullName), fullName = sprintf('Author %d', authorIndex); end
            
            obj.AuthorListBox.Items{authorIndex} = fullName;
            obj.AuthorListBox.Value = fullName; 

            if ~isTransient
                obj.ParentApp.saveDatasetInformationStruct();
            end
        end
        
        function givenNameEditFieldValueChanged(obj)
            obj.onAuthorNameChangedInternal('givenName', obj.GivenNameEditField.Value, false);
            obj.checkOrcidMatchInternal();
        end

        function givenNameEditFieldValueChanging(obj, event)
            obj.onAuthorNameChangedInternal('givenName', event.Value, true);
        end

        function familyNameEditFieldValueChanged(obj)
            obj.onAuthorNameChangedInternal('familyName', obj.FamilyNameEditField.Value, false);
            obj.checkOrcidMatchInternal();
        end

        function familyNameEditFieldValueChanging(obj, event)
            obj.onAuthorNameChangedInternal('familyName', event.Value, true);
        end
        
        function digitalIdentifierEditFieldValueChanged(obj)
            value = obj.DigitalIdentifierEditField.Value;
            if ~isempty(value)
                try
                    orcidIRI = value;
                    if ~startsWith(orcidIRI, 'https://orcid.org/')
                        orcidIRI = ['https://orcid.org/' strrep(value, 'https://orcid.org/','')];
                    end
                    if ~isempty(regexp(orcidIRI, 'https://orcid.org/\d{4}-\d{4}-\d{4}-\d{3}[\dX]', 'once'))
                         obj.DigitalIdentifierEditField.Value = strrep(orcidIRI, 'https://orcid.org/', '');
                    else
                        obj.ParentApp.alert('Invalid ORCID format. Expected XXXX-XXXX-XXXX-XXXX.', 'Invalid ORCID');
                    end
                catch ME
                    obj.ParentApp.alert(['Error processing ORCID: ' ME.message], 'Invalid ORCID');
                end
            end
            obj.updateCurrentAuthorProperty('digitalIdentifier', obj.DigitalIdentifierEditField.Value); 
        end

        function searchOrcidButtonPushed(obj)
            authorIndex = obj.getSelectedAuthorIndex();
            if isempty(authorIndex), obj.ParentApp.inform('Please select or add an author.'); return; end
            
            authorName = obj.ParentApp.AuthorData.getAuthorName(authorIndex);
            if isempty(strtrim(regexprep(authorName, 'Author \d+( \(Invalid\))?', ''))) 
                 obj.ParentApp.inform('Please fill out a name for the selected author to search for ORCID.');
                 return;
            end
            apiQueryUrl = ndi.database.metadata_app.fun.getOrcIdSearchUrl(authorName);
            web(apiQueryUrl, '-browser');
        end

        function authorEmailEditFieldValueChanged(obj)
            value = obj.AuthorEmailEditField.Value;
            if ~isempty(value) && isempty(regexp(value, '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$', 'once'))
                obj.ParentApp.alert('Invalid email format.', 'Invalid Email');
            end
            obj.updateCurrentAuthorProperty('contactInformation', value);
        end

        function authorRoleTreeCheckedNodesChanged(obj, event)
            selectedRoles = obj.ParentApp.getCheckedTreeNodeData(event.CheckedNodes); 
            obj.updateCurrentAuthorProperty('authorRole', selectedRoles);
        end

        function addAffiliationButtonPushed(obj)
            authorIndex = obj.getSelectedAuthorIndex();
            if isempty(authorIndex), obj.ParentApp.inform('Please select an author to add an affiliation.'); return; end
            
            organizationName = char(obj.OrganizationDropDown.Value);
            
            isNewOrg = ~any(strcmp(organizationName, obj.OrganizationDropDown.Items)) && ~isempty(strtrim(organizationName));
            if isNewOrg
                 S_org = struct('fullName', organizationName);
                 S_org_returned = obj.openOrganizationForm(S_org); 
                if ~isempty(S_org_returned) && isfield(S_org_returned, 'fullName')
                    organizationName = S_org_returned.fullName;
                    obj.populateOrganizationDropdownInternal(); 
                    obj.OrganizationDropDown.Value = organizationName; 
                else
                    obj.ParentApp.inform('Organization creation cancelled or failed.');
                    return; 
                end
            elseif isempty(strtrim(organizationName))
                obj.ParentApp.inform('Please select or enter an organization name.');
                return;
            end

            if any(strcmp(obj.AffiliationListBox.Items, organizationName))
                obj.ParentApp.inform(sprintf('Organization "%s" is already an affiliation for this author.', organizationName), 'Duplicate Affiliation');
                return;
            end

            obj.ParentApp.AuthorData.addAffiliation(organizationName, authorIndex);
            obj.ParentApp.saveDatasetInformationStruct();
            
            currentAuthorStruct = obj.ParentApp.AuthorData.getItem(authorIndex);
            obj.fillAuthorInputFieldsFromStruct(currentAuthorStruct); 
        end

        function removeAffiliationButtonPushed(obj)
            authorIndex = obj.getSelectedAuthorIndex();
            if isempty(authorIndex) || isempty(obj.AffiliationListBox.Value)
                obj.ParentApp.inform('Please select an author and an affiliation to remove.');
                return;
            end
            
            selectedAffiliationName = char(obj.AffiliationListBox.Value); 
            
            authorStruct = obj.ParentApp.AuthorData.getItem(authorIndex);
            affiliationIdxToRemove = [];
            if isfield(authorStruct, 'affiliation') && ~isempty(authorStruct.affiliation)
                for affIdx = 1:numel(authorStruct.affiliation)
                    if isfield(authorStruct.affiliation(affIdx),'memberOf') && strcmp(authorStruct.affiliation(affIdx).memberOf.fullName, selectedAffiliationName)
                        affiliationIdxToRemove = affIdx;
                        break;
                    end
                end
            end

            if ~isempty(affiliationIdxToRemove)
                obj.ParentApp.AuthorData.removeAffiliation(authorIndex, affiliationIdxToRemove);
                obj.ParentApp.saveDatasetInformationStruct();
                currentAuthorStruct = obj.ParentApp.AuthorData.getItem(authorIndex);
                obj.fillAuthorInputFieldsFromStruct(currentAuthorStruct);
            else
                obj.ParentApp.inform('Selected affiliation not found for removal.', 'Info');
            end
        end

        function S = openOrganizationForm(app, organizationInfo, organizationIndex)
            if isempty(app.UIForm.Organization) || ~isvalid(app.UIForm.Organization)
                app.UIForm.Organization = ndi.database.metadata_app.Apps.OrganizationForm();
            else
                app.UIForm.Organization.Visible = 'on';
            end
            if nargin > 1 && ~isempty(organizationInfo)
                app.UIForm.Organization.setOrganizationDetails(organizationInfo);
            end
            app.UIForm.Organization.waitfor();
            S = app.UIForm.Organization.getOrganizationDetails();
            mode = app.UIForm.Organization.FinishState;
            if mode == "Save"
                if nargin > 2 && ~isempty(organizationIndex)
                    app.insertOrganization(S, organizationIndex);
                else
                    app.insertOrganization(S);
                end
                app.populateOrganizationDropdownInternal();
            else
                S = struct.empty;
            end
            app.UIForm.Organization.reset();
            app.UIForm.Organization.Visible = 'off';
            if ~nargout, clear S; end
        end
        
        function insertOrganization(app, S_org, insertIndex) 
            if nargin < 3 || isempty(insertIndex)
                insertIndex = numel(app.ParentApp.Organizations) + 1;
            end
            if isempty(app.ParentApp.Organizations)
                app.ParentApp.Organizations = S_org;
            else
                app.ParentApp.Organizations(insertIndex) = S_org;
            end
            app.saveOrganizationInstances();
        end

        function saveOrganizationInstances(app)
            ndi.database.metadata_app.fun.saveUserInstances('affiliation_organization', app.ParentApp.Organizations);
        end        

        function checkOrcidMatchInternal(obj)
            if ~isempty(obj.DigitalIdentifierEditField.Value)
                return;
            end
            if isempty(obj.GivenNameEditField.Value) || isempty(obj.FamilyNameEditField.Value)
                return;
            end
            fullName = strtrim(strjoin({obj.GivenNameEditField.Value, obj.FamilyNameEditField.Value}, ' '));
            if isempty(fullName), return; end

            try
                progressdlg = uiprogressdlg(obj.ParentApp.NDIMetadataEditorUIFigure, ...
                    "Indeterminate", "on", "Message", "Searching for ORCID...", ...
                    "Title", "Please Wait", 'Cancelable','on');
                orcid = ndi.database.metadata_app.fun.getOrcId(fullName);
                
                if isvalid(progressdlg) && progressdlg.CancelRequested
                    if isvalid(progressdlg), delete(progressdlg); end
                    return;
                end
                if isvalid(progressdlg), delete(progressdlg); end
                
                if ~isempty(orcid)
                    orcidLink = sprintf("https://orcid.org/%s", orcid);
                    msg = sprintf('ORCID <a href="%s">%s</a> found for %s. Use this ORCID?', orcidLink, orcid, fullName);
                    answer = uiconfirm(obj.ParentApp.NDIMetadataEditorUIFigure, msg, "Review ORCID", ...
                                       "Options", {'Confirm', 'Reject'}, 'DefaultOption', 'Confirm', ...
                                       'CancelOption', 'Reject', 'Interpreter', 'html');
                    if strcmp(answer, 'Confirm')
                        obj.DigitalIdentifierEditField.Value = strrep(orcid, 'https://orcid.org/', '');
                        obj.digitalIdentifierEditFieldValueChanged(); 
                    end
                else
                    obj.ParentApp.inform(sprintf('No ORCID entry found for "%s".', fullName), 'ORCID Search');
                end
            catch ME_orcid
                if exist('progressdlg','var') && isvalid(progressdlg), delete(progressdlg); end
                obj.ParentApp.alert(sprintf('Error searching ORCID: %s', ME_orcid.message), 'ORCID Search Error');
            end
        end
    end 
end 
