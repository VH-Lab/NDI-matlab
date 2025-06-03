classdef AuthorDataGUI < handle
    %AUTHORDATAGUI Manages the GUI elements, creation, and interactions for Author Data.
    properties (Access = public) 
        ParentApp % Handle to the main MetadataEditorApp instance
        UIBaseContainer % This will now be obj.AuthorMainPanel, created by this class
        UIForm struct

        % Handles to UI Components (created and populated within AuthorMainPanel)
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
        % MoveAffiliationUpButton 
        % MoveAffiliationDownButton

        % Labels (created within AuthorMainPanel)
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

        % NEW PROPERTIES for base layout elements
        AuthorsGridLayout matlab.ui.container.GridLayout
        AuthorDetailsLabel matlab.ui.control.Label
        AuthorMainPanel matlab.ui.container.Panel % This is the panel where detailed UI goes
    end

    properties (Access = private)
        ResourcesPath % Path to resources, specifically icons
    end

    methods
        % MODIFIED CONSTRUCTOR
        function obj = AuthorDataGUI(parentAppHandle, authorsTabHandle) % Accepts AuthorsTab [cite: 1369]
            obj.ParentApp = parentAppHandle; % [cite: 1369]
            % UIBaseContainer is set after creating AuthorMainPanel in createAuthorTabBaseLayout

            guiFilePath = fileparts(mfilename('fullpath')); 
            obj.ResourcesPath = fullfile(guiFilePath, '..', '+Apps', 'resources'); % [cite: 1369]
            obj.UIForm(1).Organization = []; % [cite: 1369]
            
            obj.createAuthorTabBaseLayout(authorsTabHandle); % Create the base structure within AuthorsTab
            obj.createAuthorUIComponents(); % Populate the self-created AuthorMainPanel [cite: 1369]
            obj.loadOrganizations(); % [cite: 1370]
        end

        % NEW METHOD to create the base layout for the Authors tab content
        function createAuthorTabBaseLayout(obj, authorsTabHandle)
            % authorsTabHandle is app.AuthorsTab passed from MetadataEditorApp
            obj.AuthorsGridLayout = uigridlayout(authorsTabHandle, [2 1], 'RowHeight', {60, '1x'}, 'Padding', [10 20 10 10]);
            obj.AuthorDetailsLabel = uilabel(obj.AuthorsGridLayout, 'Text', 'Author Details', ...
                    'HorizontalAlignment', 'center', 'FontSize', 18, 'FontWeight', 'bold');
            obj.AuthorDetailsLabel.Layout.Row = 1; obj.AuthorDetailsLabel.Layout.Column = 1;
            obj.AuthorMainPanel = uipanel(obj.AuthorsGridLayout, 'BorderType', 'none', 'Scrollable','on');
            obj.AuthorMainPanel.Layout.Row = 2; obj.AuthorMainPanel.Layout.Column = 1;
            
            % Set UIBaseContainer to the newly created AuthorMainPanel.
            % createAuthorUIComponents will use this as its parent.
            obj.UIBaseContainer = obj.AuthorMainPanel; 
        end

        function loadOrganizations(obj) % Changed 'app' to 'obj' for consistency
            import ndi.database.metadata_app.fun.loadUserInstances
            obj.ParentApp.Organizations = loadUserInstances('affiliation_organization'); % [cite: 1370]
            obj.populateOrganizationDropdownInternal(); % [cite: 1371]
        end

        function initialize(obj)
            %INITIALIZE Sets up callbacks and initial state for author UI.
            obj.AddAuthorButton.ButtonPushedFcn = @(~,~) obj.addAuthorButtonPushed(); % [cite: 1372]
            obj.RemoveAuthorButton.ButtonPushedFcn = @(~,~) obj.removeAuthorButtonPushed(); % [cite: 1372]
            obj.MoveAuthorUpButton.ButtonPushedFcn = @(~,~) obj.moveAuthorUpButtonPushed(); % [cite: 1372]
            obj.MoveAuthorDownButton.ButtonPushedFcn = @(~,~) obj.moveAuthorDownButtonPushed(); % [cite: 1372]
            obj.AuthorListBox.ValueChangedFcn = @(~,~) obj.authorListBoxValueChanged(); % [cite: 1372]
            obj.GivenNameEditField.ValueChangedFcn = @(~,~) obj.givenNameEditFieldValueChanged(); % [cite: 1373]
            obj.GivenNameEditField.ValueChangingFcn = @(s,e) obj.givenNameEditFieldValueChanging(e); % [cite: 1373]
            obj.FamilyNameEditField.ValueChangedFcn = @(~,~) obj.familyNameEditFieldValueChanged(); % [cite: 1373]
            obj.FamilyNameEditField.ValueChangingFcn = @(s,e) obj.familyNameEditFieldValueChanging(e); % [cite: 1373]
            obj.DigitalIdentifierEditField.ValueChangedFcn = @(~,~) obj.digitalIdentifierEditFieldValueChanged(); % [cite: 1373]
            obj.SearchOrcidButton.ButtonPushedFcn = @(~,~) obj.searchOrcidButtonPushed(); % [cite: 1374]
            obj.AuthorEmailEditField.ValueChangedFcn = @(~,~) obj.authorEmailEditFieldValueChanged(); % [cite: 1374]
            obj.AuthorRoleTree.CheckedNodesChangedFcn = @(s,e) obj.authorRoleTreeCheckedNodesChanged(e); % [cite: 1374]
            
            obj.AddAffiliationButton.ButtonPushedFcn = @(~,~) obj.addAffiliationButtonPushed(); % [cite: 1374]
            obj.RemoveAffiliationButton.ButtonPushedFcn = @(~,~) obj.removeAffiliationButtonPushed(); % [cite: 1374]
            obj.drawAuthorData(); % [cite: 1375]
        end

        function createAuthorUIComponents(obj)
            % This method now uses obj.UIBaseContainer, which is obj.AuthorMainPanel (created by createAuthorTabBaseLayout)
            parentContainer = obj.UIBaseContainer; 
            iconsPath = fullfile(obj.ResourcesPath,'icons'); % [cite: 1376]

            authorMainPanelGridLayout = uigridlayout(parentContainer); % [cite: 1376]
            authorMainPanelGridLayout.ColumnWidth = {250, '1x', '1x'}; 
            authorMainPanelGridLayout.RowHeight = {'1x'}; 
            authorMainPanelGridLayout.ColumnSpacing = 30;
            authorMainPanelGridLayout.Padding = [10 10 10 10]; % [cite: 1377]

            authorContentLeftGridLayout = uigridlayout(authorMainPanelGridLayout); % [cite: 1377]
            authorContentLeftGridLayout.Layout.Row = 1;
            authorContentLeftGridLayout.Layout.Column = 1;
            authorContentLeftGridLayout.ColumnWidth = {'1x'};
            authorContentLeftGridLayout.RowHeight = {23, '1x'}; % [cite: 1378]
            authorContentLeftGridLayout.Padding = [0 0 0 0];
            authorContentLeftGridLayout.RowSpacing = 5;

            obj.AuthorListBoxLabel = uilabel(authorContentLeftGridLayout, 'Text', 'Authors:'); % [cite: 1379]
            obj.AuthorListBoxLabel.Layout.Row = 1;obj.AuthorListBoxLabel.Layout.Column = 1; % [cite: 1379]

            authorListBoxGridLayoutInternal = uigridlayout(authorContentLeftGridLayout); % [cite: 1379]
            authorListBoxGridLayoutInternal.Layout.Row = 2; authorListBoxGridLayoutInternal.Layout.Column = 1;
            authorListBoxGridLayoutInternal.ColumnWidth = {'1x', 30}; % [cite: 1380]
            authorListBoxGridLayoutInternal.RowHeight = {'1x'}; % [cite: 1380]
            authorListBoxGridLayoutInternal.Padding = [0 0 0 0];
            authorListBoxGridLayoutInternal.ColumnSpacing = 5;

            obj.AuthorListBox = uilistbox(authorListBoxGridLayoutInternal); % [cite: 1380]
            obj.AuthorListBox.Layout.Row = 1; % [cite: 1381]
            obj.AuthorListBox.Layout.Column = 1; % [cite: 1381]
            obj.AuthorListBox.Items = {}; obj.AuthorListBox.Value = {}; % [cite: 1381]

            authorListBoxButtonPanel = uigridlayout(authorListBoxGridLayoutInternal); % [cite: 1381]
            authorListBoxButtonPanel.Layout.Row = 1; authorListBoxButtonPanel.Layout.Column = 2; % [cite: 1382]
            authorListBoxButtonPanel.RowHeight = {23, 23, 10, 23, 23, '1x'}; % [cite: 1382]
            authorListBoxButtonPanel.ColumnWidth = {'1x'}; % [cite: 1382]
            authorListBoxButtonPanel.Padding = [0 0 0 0];
            authorListBoxButtonPanel.RowSpacing = 5;
            obj.AddAuthorButton = uibutton(authorListBoxButtonPanel, 'push', 'Text', '', 'Icon', fullfile(iconsPath, 'plus.png')); % [cite: 1383]
            obj.AddAuthorButton.Layout.Row = 1; obj.AddAuthorButton.Layout.Column = 1; % [cite: 1383]
            obj.RemoveAuthorButton = uibutton(authorListBoxButtonPanel, 'push', 'Text', '', 'Icon', fullfile(iconsPath, 'minus.png')); % [cite: 1384]
            obj.RemoveAuthorButton.Layout.Row = 2; obj.RemoveAuthorButton.Layout.Column = 1; % [cite: 1384]
            obj.MoveAuthorUpButton = uibutton(authorListBoxButtonPanel, 'push', 'Text', '', 'Icon', fullfile(iconsPath, 'up.png')); % [cite: 1385]
            obj.MoveAuthorUpButton.Layout.Row = 4; obj.MoveAuthorUpButton.Layout.Column = 1; % [cite: 1385]
            obj.MoveAuthorDownButton = uibutton(authorListBoxButtonPanel, 'push', 'Text', '', 'Icon', fullfile(iconsPath, 'down.png')); % [cite: 1386]
            obj.MoveAuthorDownButton.Layout.Row = 5; obj.MoveAuthorDownButton.Layout.Column = 1; % [cite: 1386]

            authorContentCenterGridLayout = uigridlayout(authorMainPanelGridLayout); % [cite: 1386]
            authorContentCenterGridLayout.Layout.Row = 1; % [cite: 1387]
            authorContentCenterGridLayout.Layout.Column = 2; % [cite: 1387]
            authorContentCenterGridLayout.ColumnWidth = {'1x'};
            authorContentCenterGridLayout.RowHeight = {23, 23, 10, 23, 23, 10, 23, 23, 10, 23, 23, 10, 23, '1x'}; % [cite: 1387]
            authorContentCenterGridLayout.Padding = [0 0 0 0]; % [cite: 1388]
            authorContentCenterGridLayout.RowSpacing = 5;

            obj.GivenNameEditFieldLabel = uilabel(authorContentCenterGridLayout, 'Text', 'Given Name'); % [cite: 1388]
            obj.GivenNameEditFieldLabel.Layout.Row = 1; % [cite: 1389]
            obj.GivenNameEditFieldLabel.Layout.Column = 1; % [cite: 1389]
            obj.GivenNameEditField = uieditfield(authorContentCenterGridLayout, 'text'); % [cite: 1389]
            obj.GivenNameEditField.Layout.Row = 2; obj.GivenNameEditField.Layout.Column = 1; % [cite: 1389]

            obj.FamilyNameEditFieldLabel = uilabel(authorContentCenterGridLayout, 'Text', 'Family Name'); % [cite: 1389]
            obj.FamilyNameEditFieldLabel.Layout.Row = 4; obj.FamilyNameEditFieldLabel.Layout.Column = 1; % [cite: 1390]
            obj.FamilyNameEditField = uieditfield(authorContentCenterGridLayout, 'text'); % [cite: 1390]
            obj.FamilyNameEditField.Layout.Row = 5; obj.FamilyNameEditField.Layout.Column = 1; % [cite: 1390]
            obj.DigitalIdentifierEditFieldLabel = uilabel(authorContentCenterGridLayout, 'Text', 'Digital Identifier (ORCID)'); % [cite: 1391]
            obj.DigitalIdentifierEditFieldLabel.Layout.Row = 7; obj.DigitalIdentifierEditFieldLabel.Layout.Column = 1; % [cite: 1391]
            
            authorOrcidGridLayout = uigridlayout(authorContentCenterGridLayout);  % [cite: 1391]
            authorOrcidGridLayout.Layout.Row = 8; % [cite: 1392]
            authorOrcidGridLayout.Layout.Column = 1; % [cite: 1392]
            authorOrcidGridLayout.ColumnWidth = {'1x', 30}; authorOrcidGridLayout.RowHeight = {'1x'}; % [cite: 1392]
            authorOrcidGridLayout.Padding = [0 0 0 0]; authorOrcidGridLayout.ColumnSpacing = 5; % [cite: 1392]
            obj.DigitalIdentifierEditField = uieditfield(authorOrcidGridLayout, 'text', 'Placeholder', 'Example: 0000-0002-1825-0097'); % [cite: 1393]
            obj.DigitalIdentifierEditField.Layout.Row = 1; obj.DigitalIdentifierEditField.Layout.Column = 1; % [cite: 1393]
            obj.SearchOrcidButton = uibutton(authorOrcidGridLayout, 'push', 'Text', '', 'Icon', fullfile(iconsPath, 'search.png')); % [cite: 1394]
            obj.SearchOrcidButton.Layout.Row = 1; obj.SearchOrcidButton.Layout.Column = 2; % [cite: 1394]
            obj.AuthorEmailEditFieldLabel = uilabel(authorContentCenterGridLayout, 'Text', 'Author Email'); % [cite: 1395]
            obj.AuthorEmailEditFieldLabel.Layout.Row = 10; obj.AuthorEmailEditFieldLabel.Layout.Column = 1; % [cite: 1395]
            obj.AuthorEmailEditField = uieditfield(authorContentCenterGridLayout, 'text'); % [cite: 1395]
            obj.AuthorEmailEditField.Layout.Row = 11; % [cite: 1396]
            obj.AuthorEmailEditField.Layout.Column = 1; % [cite: 1396]
            
            obj.AuthorRoleLabel = uilabel(authorContentCenterGridLayout, 'Text', 'Author Role(s)'); % [cite: 1396]
            obj.AuthorRoleLabel.Layout.Row = 13; obj.AuthorRoleLabel.Layout.Column = 1; % [cite: 1396]
            obj.AuthorRoleTree = uitree(authorContentCenterGridLayout, 'checkbox'); % [cite: 1396]
            obj.AuthorRoleTree.Layout.Row = 14; obj.AuthorRoleTree.Layout.Column = 1; % [cite: 1397]
            obj.FirstAuthorNode = uitreenode(obj.AuthorRoleTree, 'Text', '1st Author', 'NodeData', '1st Author'); % [cite: 1397]
            obj.CustodianNode = uitreenode(obj.AuthorRoleTree, 'Text', 'Custodian', 'NodeData', 'Custodian'); % [cite: 1398]
            obj.CorrespondingNode = uitreenode(obj.AuthorRoleTree, 'Text', 'Corresponding', 'NodeData', 'Corresponding'); % [cite: 1398]

            authorContentRightGridLayout = uigridlayout(authorMainPanelGridLayout); % [cite: 1398]
            authorContentRightGridLayout.Layout.Row = 1; % [cite: 1399]
            authorContentRightGridLayout.Layout.Column = 3; % [cite: 1399]
            authorContentRightGridLayout.ColumnWidth = {'1x'}; % [cite: 1399]
            authorContentRightGridLayout.RowHeight = {23, 23, '1x'}; % [cite: 1399]
            authorContentRightGridLayout.Padding = [0 0 0 0]; % [cite: 1400]
            authorContentRightGridLayout.RowSpacing = 5; % [cite: 1400]
            obj.AffiliationsListBoxLabel = uilabel(authorContentRightGridLayout, 'Text', 'Affiliations/Institutes'); % [cite: 1400]
            obj.AffiliationsListBoxLabel.Layout.Row = 1; obj.AffiliationsListBoxLabel.Layout.Column = 1; % [cite: 1400]

            affiliationSelectionGridLayout = uigridlayout(authorContentRightGridLayout);  % [cite: 1400]
            affiliationSelectionGridLayout.Layout.Row = 2; affiliationSelectionGridLayout.Layout.Column = 1; % [cite: 1401]
            affiliationSelectionGridLayout.ColumnWidth = {'1x', 30}; affiliationSelectionGridLayout.RowHeight = {'1x'}; % [cite: 1401]
            affiliationSelectionGridLayout.Padding = [0 0 0 0]; affiliationSelectionGridLayout.ColumnSpacing = 5; % [cite: 1401]
            obj.OrganizationDropDown = uidropdown(affiliationSelectionGridLayout, 'Editable', 'on', 'Placeholder', 'Select or enter organization'); % [cite: 1402]
            obj.OrganizationDropDown.Layout.Row = 1; obj.OrganizationDropDown.Layout.Column = 1; % [cite: 1402]
            obj.AddAffiliationButton = uibutton(affiliationSelectionGridLayout, 'push', 'Text', '', 'Icon', fullfile(iconsPath, 'plus.png')); % [cite: 1403]
            obj.AddAffiliationButton.Layout.Row = 1; obj.AddAffiliationButton.Layout.Column = 2; % [cite: 1403]
            
            affiliationListBoxGridLayoutInternal = uigridlayout(authorContentRightGridLayout); % [cite: 1403]
            affiliationListBoxGridLayoutInternal.Layout.Row = 3; affiliationListBoxGridLayoutInternal.Layout.Column = 1; % [cite: 1404]
            affiliationListBoxGridLayoutInternal.ColumnWidth = {'1x', 30}; affiliationListBoxGridLayoutInternal.RowHeight = {'1x'}; % [cite: 1404]
            affiliationListBoxGridLayoutInternal.Padding = [0 0 0 0]; % [cite: 1404]
            affiliationListBoxGridLayoutInternal.ColumnSpacing = 5; % [cite: 1405]
            obj.AffiliationListBox = uilistbox(affiliationListBoxGridLayoutInternal); % [cite: 1405]
            obj.AffiliationListBox.Layout.Row = 1; obj.AffiliationListBox.Layout.Column = 1; % [cite: 1405]
            obj.AffiliationListBox.Items = {}; obj.AffiliationListBox.Value = {}; % [cite: 1405]
            affiliationRemoveButtonPanel = uigridlayout(affiliationListBoxGridLayoutInternal); % [cite: 1406]
            affiliationRemoveButtonPanel.Layout.Row = 1; affiliationRemoveButtonPanel.Layout.Column = 2; % [cite: 1406]
            affiliationRemoveButtonPanel.RowHeight = {23, '1x'}; affiliationRemoveButtonPanel.ColumnWidth = {'1x'}; % [cite: 1407]
            affiliationRemoveButtonPanel.Padding = [0 0 0 0]; affiliationRemoveButtonPanel.RowSpacing = 5; % [cite: 1407]
            obj.RemoveAffiliationButton = uibutton(affiliationRemoveButtonPanel, 'push', 'Text', '', 'Icon', fullfile(iconsPath, 'minus.png')); % [cite: 1407]
            obj.RemoveAffiliationButton.Layout.Row = 1; obj.RemoveAffiliationButton.Layout.Column = 1; % [cite: 1408]
        end
        
        function drawAuthorData(obj)
            obj.updateAuthorListbox(); % [cite: 1408]
            if ~isempty(obj.ParentApp.AuthorData.AuthorList) && ~isempty(obj.AuthorListBox.Items) % [cite: 1409]
                try
                    if isempty(obj.AuthorListBox.Value) || ~any(strcmp(obj.AuthorListBox.Value, obj.AuthorListBox.Items)) % [cite: 1410]
                        obj.AuthorListBox.Value = obj.AuthorListBox.Items{1}; % [cite: 1410]
                    end
                    authorIndexToDisplay = obj.getSelectedAuthorIndex(); % [cite: 1411]
                    if isempty(authorIndexToDisplay) && ~isempty(obj.ParentApp.AuthorData.AuthorList) % [cite: 1412]
                        authorIndexToDisplay = 1; % [cite: 1412]
                    end
                    if ~isempty(authorIndexToDisplay)
                        currentAuthorStruct = obj.ParentApp.AuthorData.getItem(authorIndexToDisplay); % [cite: 1413]
                        obj.fillAuthorInputFieldsFromStruct(currentAuthorStruct); % [cite: 1414]
                    else
                         obj.fillAuthorInputFieldsFromStruct(ndi.database.metadata_app.class.AuthorData.getDefaultAuthorItem()); % [cite: 1414]
                    end
                catch ME_authUI
                     fprintf(2, 'Error updating author UI elements in drawAuthorData: %s\n', ME_authUI.message); % [cite: 1415]
                     emptyAuthorStructUI = ndi.database.metadata_app.class.AuthorData.getDefaultAuthorItem(); % [cite: 1416]
                     obj.fillAuthorInputFieldsFromStruct(emptyAuthorStructUI); % [cite: 1416]
                end
            else 
                emptyAuthorStructUI = ndi.database.metadata_app.class.AuthorData.getDefaultAuthorItem(); % [cite: 1416]
                obj.fillAuthorInputFieldsFromStruct(emptyAuthorStructUI); % [cite: 1417]
                obj.AuthorListBox.Items = {}; % [cite: 1417]
                obj.AuthorListBox.Value = {}; % [cite: 1417]
            end
        end

        function updateAuthorListbox(obj)
            authorStructList = obj.ParentApp.AuthorData.toStructs(); % [cite: 1417]
            if isempty(authorStructList) || (isstruct(authorStructList) && numel(authorStructList)==1 && isempty(fieldnames(authorStructList(1)))) % [cite: 1418]
                if isstruct(authorStructList) && numel(authorStructList)==1 && isempty(fieldnames(authorStructList(1))) % [cite: 1418]
                    authorStructList = repmat(ndi.database.metadata_app.class.AuthorData.getDefaultAuthorItem(),0,1); % [cite: 1418]
                end
            end

            if isempty(authorStructList) || (numel(authorStructList)==1 && isempty(authorStructList(1).givenName) && isempty(authorStructList(1).familyName) && numel(obj.ParentApp.AuthorData.AuthorList)==0) % [cite: 1420]
                obj.AuthorListBox.Items = {}; % [cite: 1420]
                obj.AuthorListBox.Value = {}; % [cite: 1421]
                return; % [cite: 1421]
            end
            
            fullNames = cell(numel(authorStructList), 1); % [cite: 1421]
            for i = 1:numel(authorStructList) % [cite: 1422]
                given = char(authorStructList(i).givenName); % [cite: 1422]
                family = char(authorStructList(i).familyName); % [cite: 1423]
                fullName = strtrim(strjoin({given, family}, ' ')); % [cite: 1423]
                if isempty(fullName)
                    fullName = sprintf('Author %d', i); % [cite: 1423]
                end
                fullNames{i} = fullName; % [cite: 1424]
            end
            
            currentSelection = obj.AuthorListBox.Value; % [cite: 1425]
            obj.AuthorListBox.Items = fullNames; % [cite: 1426]

            if ~isempty(fullNames)
                if ~isempty(currentSelection) && any(strcmp(fullNames, currentSelection)) % [cite: 1426]
                    obj.AuthorListBox.Value = currentSelection; % [cite: 1427]
                else
                    obj.AuthorListBox.Value = fullNames{1}; % [cite: 1428]
                end
            else
                obj.AuthorListBox.Value = {}; % [cite: 1429]
            end
        end

        function fillAuthorInputFieldsFromStruct(obj, authorStruct)
            obj.GivenNameEditField.Value = char(authorStruct.givenName); % [cite: 1429]
            obj.FamilyNameEditField.Value = char(authorStruct.familyName); % [cite: 1430]
            obj.AuthorEmailEditField.Value = char(authorStruct.contactInformation.email); % [cite: 1430]
            obj.DigitalIdentifierEditField.Value = char(authorStruct.digitalIdentifier.identifier); % [cite: 1430]
            
            obj.AffiliationListBox.Items = {}; % [cite: 1430]
            if isfield(authorStruct, 'affiliation') && ~isempty(authorStruct.affiliation) && isstruct(authorStruct.affiliation) % [cite: 1431]
                affiliationStructArray = authorStruct.affiliation; % [cite: 1431]
                orgNames = cell(1,0); % [cite: 1432]
                for i=1:numel(affiliationStructArray) % [cite: 1432]
                    if isfield(affiliationStructArray(i),'memberOf') && isstruct(affiliationStructArray(i).memberOf) && isfield(affiliationStructArray(i).memberOf,'fullName') % [cite: 1432]
                        orgNames{end+1} = char(affiliationStructArray(i).memberOf.fullName); % [cite: 1433]
%#ok<AGROW> % [cite: 1433]
                    end
                end
                obj.AffiliationListBox.Items = orgNames; % [cite: 1434]
            end
            obj.ParentApp.setCheckedNodesFromData(obj.AuthorRoleTree, authorStruct.authorRole); % [cite: 1434]
        end
        
        function idx = getSelectedAuthorIndex(obj)
            idx = []; % [cite: 1435]
            if ~isempty(obj.AuthorListBox.Value) % [cite: 1436]
                isSelected = strcmp(obj.AuthorListBox.Items, obj.AuthorListBox.Value); % [cite: 1436]
                idx = find(isSelected, 1); % [cite: 1437]
            end
        end
        
        function updateCurrentAuthorProperty(obj, propertyName, propertyValue)
            authorIndex = obj.getSelectedAuthorIndex(); % [cite: 1437]
            if isempty(authorIndex) % [cite: 1438]
                if isempty(obj.ParentApp.AuthorData.AuthorList) % [cite: 1438]
                    obj.ParentApp.AuthorData.addDefaultAuthorEntry(); % [cite: 1438]
                    obj.updateAuthorListbox();  % [cite: 1439]
                    authorIndex = 1; % [cite: 1439]
                    if ~isempty(obj.AuthorListBox.Items) % [cite: 1439]
                        obj.AuthorListBox.Value = obj.AuthorListBox.Items{1}; % [cite: 1440]
                    end
                else
                    authorIndex = 1; % [cite: 1440]
                    if ~isempty(obj.AuthorListBox.Items) % [cite: 1441]
                        obj.AuthorListBox.Value = obj.AuthorListBox.Items{1}; % [cite: 1441]
                    end
                end
            end
            
            obj.ParentApp.AuthorData.updateProperty(propertyName, propertyValue, authorIndex); % [cite: 1442]
            obj.ParentApp.saveDatasetInformationStruct(); % [cite: 1443]
        end

        function populateOrganizationDropdownInternal(obj)
            currentItems = {}; % [cite: 1443]
            if isprop(obj.ParentApp, 'Organizations') && ~isempty(obj.ParentApp.Organizations) % [cite: 1444]
                currentItems = {obj.ParentApp.Organizations.fullName}; % [cite: 1444]
            end
            
            obj.OrganizationDropDown.Items = currentItems; % [cite: 1445]
            if ~isempty(currentItems) % [cite: 1446]
                obj.OrganizationDropDown.Value = ''; % [cite: 1446]
            else
                obj.OrganizationDropDown.Value = ''; % [cite: 1447]
            end
        end

        % --- Callbacks ---
        function addAuthorButtonPushed(obj)
            obj.ParentApp.AuthorData.addDefaultAuthorEntry(); % [cite: 1448]
            obj.updateAuthorListbox(); % [cite: 1449]
            if ~isempty(obj.AuthorListBox.Items) % [cite: 1449]
                obj.AuthorListBox.Value = obj.AuthorListBox.Items{end}; % [cite: 1449]
                obj.authorListBoxValueChanged(); % [cite: 1450]
            end
            obj.ParentApp.saveDatasetInformationStruct(); % [cite: 1450]
        end

        function removeAuthorButtonPushed(obj)
            idx = obj.getSelectedAuthorIndex(); % [cite: 1451]
            if ~isempty(idx) % [cite: 1452]
                obj.ParentApp.AuthorData.removeItem(idx); % [cite: 1452]
                obj.drawAuthorData(); % [cite: 1452]
                obj.ParentApp.saveDatasetInformationStruct(); % [cite: 1452]
            else
                obj.ParentApp.inform('Please select an author to remove.', 'No Author Selected'); % [cite: 1453]
            end
        end

        function moveAuthorUpButtonPushed(obj)
            oldIdx = obj.getSelectedAuthorIndex(); % [cite: 1454]
            if ~isempty(oldIdx) && oldIdx > 1 % [cite: 1455]
                newIdx = oldIdx - 1; % [cite: 1455]
                obj.ParentApp.AuthorData.reorderItems(newIdx, oldIdx); % [cite: 1456]
                obj.updateAuthorListbox(); % [cite: 1456]
                obj.AuthorListBox.Value = obj.AuthorListBox.Items{newIdx}; % [cite: 1456]
                obj.ParentApp.saveDatasetInformationStruct(); % [cite: 1456]
            end
        end

        function moveAuthorDownButtonPushed(obj)
            oldIdx = obj.getSelectedAuthorIndex(); % [cite: 1456]
            if ~isempty(oldIdx) && oldIdx < numel(obj.AuthorListBox.Items) % [cite: 1457]
                newIdx = oldIdx + 1; % [cite: 1457]
                obj.ParentApp.AuthorData.reorderItems(newIdx, oldIdx); % [cite: 1458]
                obj.updateAuthorListbox(); % [cite: 1458]
                obj.AuthorListBox.Value = obj.AuthorListBox.Items{newIdx}; % [cite: 1458]
                obj.ParentApp.saveDatasetInformationStruct(); % [cite: 1458]
            end
        end

        function authorListBoxValueChanged(obj)
            idx = obj.getSelectedAuthorIndex(); % [cite: 1459]
            if ~isempty(idx) % [cite: 1459]
                authorStruct = obj.ParentApp.AuthorData.getItem(idx); % [cite: 1459]
                obj.fillAuthorInputFieldsFromStruct(authorStruct); % [cite: 1460]
            else 
                obj.fillAuthorInputFieldsFromStruct(ndi.database.metadata_app.class.AuthorData.getDefaultAuthorItem()); % [cite: 1460]
            end
        end
        
        function onAuthorNameChangedInternal(obj, fieldName, fieldValue, isTransient)
            authorIndex = obj.getSelectedAuthorIndex(); % [cite: 1461]
            if isempty(authorIndex) % [cite: 1462]
                if isempty(obj.ParentApp.AuthorData.AuthorList) % [cite: 1462]
                    obj.ParentApp.AuthorData.addDefaultAuthorEntry(); % [cite: 1462]
                    obj.updateAuthorListbox(); % [cite: 1463]
                    if ~isempty(obj.AuthorListBox.Items), obj.AuthorListBox.Value = obj.AuthorListBox.Items{1}; end % [cite: 1463]
                    authorIndex = 1; % [cite: 1463]
                else
                    authorIndex = 1; % [cite: 1464]
                    if ~isempty(obj.AuthorListBox.Items), obj.AuthorListBox.Value = obj.AuthorListBox.Items{1}; end % [cite: 1465]
                end
            end
            
            obj.ParentApp.AuthorData.updateProperty(fieldName, fieldValue, authorIndex); % [cite: 1465]
            currentAuthorStruct = obj.ParentApp.AuthorData.getItem(authorIndex); % [cite: 1466]
            given = currentAuthorStruct.givenName; % [cite: 1466]
            family = currentAuthorStruct.familyName; % [cite: 1466]
            fullName = strtrim(strjoin({given, family},' ')); % [cite: 1466]
            if isempty(fullName), fullName = sprintf('Author %d', authorIndex); end % [cite: 1467]
            
            obj.AuthorListBox.Items{authorIndex} = fullName; % [cite: 1467]
            obj.AuthorListBox.Value = fullName; % [cite: 1468]

            if ~isTransient % [cite: 1468]
                obj.ParentApp.saveDatasetInformationStruct(); % [cite: 1469]
            end
        end
        
        function givenNameEditFieldValueChanged(obj)
            obj.onAuthorNameChangedInternal('givenName', obj.GivenNameEditField.Value, false); % [cite: 1470]
            obj.checkOrcidMatchInternal(); % [cite: 1470]
        end

        function givenNameEditFieldValueChanging(obj, event)
            obj.onAuthorNameChangedInternal('givenName', event.Value, true); % [cite: 1470]
        end

        function familyNameEditFieldValueChanged(obj)
            obj.onAuthorNameChangedInternal('familyName', obj.FamilyNameEditField.Value, false); % [cite: 1471]
            obj.checkOrcidMatchInternal(); % [cite: 1472]
        end

        function familyNameEditFieldValueChanging(obj, event)
            obj.onAuthorNameChangedInternal('familyName', event.Value, true); % [cite: 1472]
        end
        
        function digitalIdentifierEditFieldValueChanged(obj)
            value = obj.DigitalIdentifierEditField.Value; % [cite: 1473]
            if ~isempty(value) % [cite: 1474]
                try
                    orcidIRI = value; % [cite: 1474]
                    if ~startsWith(orcidIRI, 'https://orcid.org/') % [cite: 1475]
                        orcidIRI = ['https://orcid.org/' strrep(value, 'https://orcid.org/','')]; % [cite: 1475]
                    end
                    if ~isempty(regexp(orcidIRI, 'https://orcid.org/\d{4}-\d{4}-\d{4}-\d{3}[\dX]', 'once')) % [cite: 1476]
                         obj.DigitalIdentifierEditField.Value = strrep(orcidIRI, 'https://orcid.org/', ''); % [cite: 1476]
                    else
                        obj.ParentApp.alert('Invalid ORCID format. Expected XXXX-XXXX-XXXX-XXXX.', 'Invalid ORCID'); % [cite: 1477]
                    end
                catch ME
                    obj.ParentApp.alert(['Error processing ORCID: ' ME.message], 'Invalid ORCID'); % [cite: 1478]
                end
            end
            obj.updateCurrentAuthorProperty('digitalIdentifier', obj.DigitalIdentifierEditField.Value); % [cite: 1479]
        end

        function searchOrcidButtonPushed(obj)
            authorIndex = obj.getSelectedAuthorIndex(); % [cite: 1480]
            if isempty(authorIndex), obj.ParentApp.inform('Please select or add an author.'); return; end % [cite: 1481]
            
            authorName = obj.ParentApp.AuthorData.getAuthorName(authorIndex); % [cite: 1481]
            if isempty(strtrim(regexprep(authorName, 'Author \d+( \(Invalid\))?', '')))  % [cite: 1482]
                 obj.ParentApp.inform('Please fill out a name for the selected author to search for ORCID.'); % [cite: 1482]
                 return; % [cite: 1483]
            end
            apiQueryUrl = ndi.database.metadata_app.fun.getOrcIdSearchUrl(authorName); % [cite: 1483]
            web(apiQueryUrl, '-browser'); % [cite: 1483]
        end

        function authorEmailEditFieldValueChanged(obj)
            value = obj.AuthorEmailEditField.Value; % [cite: 1484]
            if ~isempty(value) && isempty(regexp(value, '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$', 'once')) % [cite: 1485]
                obj.ParentApp.alert('Invalid email format.', 'Invalid Email'); % [cite: 1485]
            end
            obj.updateCurrentAuthorProperty('contactInformation', value); % [cite: 1486]
        end

        function authorRoleTreeCheckedNodesChanged(obj, event)
            selectedRoles = obj.ParentApp.getCheckedTreeNodeData(event.CheckedNodes); % [cite: 1487]
            obj.updateCurrentAuthorProperty('authorRole', selectedRoles); % [cite: 1488]
        end

        function addAffiliationButtonPushed(obj)
            authorIndex = obj.getSelectedAuthorIndex(); % [cite: 1488]
            if isempty(authorIndex), obj.ParentApp.inform('Please select an author to add an affiliation.'); return; end % [cite: 1489]
            
            organizationName = char(obj.OrganizationDropDown.Value); % [cite: 1490]
            isNewOrg = ~any(strcmp(organizationName, obj.OrganizationDropDown.Items)) && ~isempty(strtrim(organizationName)); % [cite: 1491]
            if isNewOrg % [cite: 1491]
                 S_org = struct('fullName', organizationName); % [cite: 1491]
                 S_org_returned = obj.openOrganizationForm(S_org); % [cite: 1492]
                if ~isempty(S_org_returned) && isfield(S_org_returned, 'fullName') % [cite: 1492]
                    organizationName = S_org_returned.fullName; % [cite: 1492]
                    obj.populateOrganizationDropdownInternal();  % [cite: 1493]
                    obj.OrganizationDropDown.Value = organizationName; % [cite: 1493]
                else
                    obj.ParentApp.inform('Organization creation cancelled or failed.'); % [cite: 1493]
                    return; % [cite: 1494]
                end
            elseif isempty(strtrim(organizationName)) % [cite: 1494]
                obj.ParentApp.inform('Please select or enter an organization name.'); % [cite: 1494]
                return; % [cite: 1495]
            end

            if any(strcmp(obj.AffiliationListBox.Items, organizationName)) % [cite: 1495]
                obj.ParentApp.inform(sprintf('Organization "%s" is already an affiliation for this author.', organizationName), 'Duplicate Affiliation'); % [cite: 1495]
                return; % [cite: 1496]
            end

            obj.ParentApp.AuthorData.addAffiliation(organizationName, authorIndex); % [cite: 1496]
            obj.ParentApp.saveDatasetInformationStruct(); % [cite: 1496]
            
            currentAuthorStruct = obj.ParentApp.AuthorData.getItem(authorIndex); % [cite: 1496]
            obj.fillAuthorInputFieldsFromStruct(currentAuthorStruct); % [cite: 1497]
        end

        function removeAffiliationButtonPushed(obj)
            authorIndex = obj.getSelectedAuthorIndex(); % [cite: 1497]
            if isempty(authorIndex) || isempty(obj.AffiliationListBox.Value) % [cite: 1498]
                obj.ParentApp.inform('Please select an author and an affiliation to remove.'); % [cite: 1498]
                return; % [cite: 1499]
            end
            
            selectedAffiliationName = char(obj.AffiliationListBox.Value); % [cite: 1499]
            authorStruct = obj.ParentApp.AuthorData.getItem(authorIndex); % [cite: 1500]
            affiliationIdxToRemove = []; % [cite: 1500]
            if isfield(authorStruct, 'affiliation') && ~isempty(authorStruct.affiliation) % [cite: 1500]
                for affIdx = 1:numel(authorStruct.affiliation) % [cite: 1500]
                    if isfield(authorStruct.affiliation(affIdx),'memberOf') && strcmp(authorStruct.affiliation(affIdx).memberOf.fullName, selectedAffiliationName) % [cite: 1501]
                        affiliationIdxToRemove = affIdx; % [cite: 1501]
                        break; % [cite: 1501]
                    end
                end
            end

            if ~isempty(affiliationIdxToRemove) % [cite: 1501]
                obj.ParentApp.AuthorData.removeAffiliation(authorIndex, affiliationIdxToRemove); % [cite: 1502]
                obj.ParentApp.saveDatasetInformationStruct(); % [cite: 1502]
                currentAuthorStruct = obj.ParentApp.AuthorData.getItem(authorIndex); % [cite: 1502]
                obj.fillAuthorInputFieldsFromStruct(currentAuthorStruct); % [cite: 1502]
            else
                obj.ParentApp.inform('Selected affiliation not found for removal.', 'Info'); % [cite: 1503]
            end
        end

        function S = openOrganizationForm(obj, organizationInfo, organizationIndex) % Changed app to obj
            if isempty(obj.UIForm.Organization) || ~isvalid(obj.UIForm.Organization) % [cite: 1504]
                obj.UIForm.Organization = ndi.database.metadata_app.Apps.OrganizationForm(); % [cite: 1504]
            else
                obj.UIForm.Organization.Visible = 'on'; % [cite: 1505]
            end
            if nargin > 1 && ~isempty(organizationInfo) % [cite: 1506]
                obj.UIForm.Organization.setOrganizationDetails(organizationInfo); % [cite: 1506]
            end
            obj.UIForm.Organization.waitfor(); % [cite: 1507]
            S = obj.UIForm.Organization.getOrganizationDetails(); % [cite: 1507]
            mode = obj.UIForm.Organization.FinishState; % [cite: 1507]
            if mode == "Save" % [cite: 1508]
                if nargin > 2 && ~isempty(organizationIndex) % [cite: 1508]
                    obj.insertOrganization(S, organizationIndex); % [cite: 1508] Changed app to obj
                else
                    obj.insertOrganization(S); % [cite: 1509] Changed app to obj
                end
                obj.populateOrganizationDropdownInternal(); % [cite: 1510]
            else
                S = struct.empty; % [cite: 1511]
            end
            obj.UIForm.Organization.reset(); % [cite: 1512]
            obj.UIForm.Organization.Visible = 'off'; % [cite: 1512]
            if ~nargout, clear S; end % [cite: 1513]
        end
        
        function insertOrganization(obj, S_org, insertIndex) % Changed app to obj [cite: 1513]
            if nargin < 3 || isempty(insertIndex) % [cite: 1514]
                insertIndex = numel(obj.ParentApp.Organizations) + 1; % [cite: 1514]
            end
            if isempty(obj.ParentApp.Organizations) % [cite: 1515]
                obj.ParentApp.Organizations = S_org; % [cite: 1515]
            else
                obj.ParentApp.Organizations(insertIndex) = S_org; % [cite: 1516]
            end
            obj.saveOrganizationInstances(); % [cite: 1517]
        end

        function saveOrganizationInstances(obj) % Changed app to obj
            ndi.database.metadata_app.fun.saveUserInstances('affiliation_organization', obj.ParentApp.Organizations); % [cite: 1518]
        end        

        function checkOrcidMatchInternal(obj)
            if ~isempty(obj.DigitalIdentifierEditField.Value) % [cite: 1519]
                return; % [cite: 1520]
            end
            if isempty(obj.GivenNameEditField.Value) || isempty(obj.FamilyNameEditField.Value) % [cite: 1520]
                return; % [cite: 1521]
            end
            fullName = strtrim(strjoin({obj.GivenNameEditField.Value, obj.FamilyNameEditField.Value}, ' ')); % [cite: 1522]
            if isempty(fullName), return; end % [cite: 1523]

            try
                progressdlg = uiprogressdlg(obj.ParentApp.NDIMetadataEditorUIFigure, ...
                    "Indeterminate", "on", "Message", "Searching for ORCID...", ...
                    "Title", "Please Wait", 'Cancelable','on'); % [cite: 1523]
                orcid = ndi.database.metadata_app.fun.getOrcId(fullName); % [cite: 1524]
                
                if isvalid(progressdlg) && progressdlg.CancelRequested % [cite: 1524]
                    if isvalid(progressdlg), delete(progressdlg); end % [cite: 1525]
                    return; % [cite: 1525]
                end
                if isvalid(progressdlg), delete(progressdlg); end % [cite: 1526]
                
                if ~isempty(orcid) % [cite: 1527]
                    orcidLink = sprintf("https://orcid.org/%s", orcid); % [cite: 1527]
                    msg = sprintf('ORCID <a href="%s">%s</a> found for %s. Use this ORCID?', orcidLink, orcid, fullName); % [cite: 1528]
                    answer = uiconfirm(obj.ParentApp.NDIMetadataEditorUIFigure, msg, "Review ORCID", ...
                                       "Options", {'Confirm', 'Reject'}, 'DefaultOption', 'Confirm', ...
                                       'CancelOption', 'Reject', 'Interpreter', 'html'); % [cite: 1529]
                    if strcmp(answer, 'Confirm') % [cite: 1529]
                        obj.DigitalIdentifierEditField.Value = strrep(orcid, 'https://orcid.org/', ''); % [cite: 1530]
                        obj.digitalIdentifierEditFieldValueChanged();  % [cite: 1531]
                    end
                else
                    obj.ParentApp.inform(sprintf('No ORCID entry found for "%s".', fullName), 'ORCID Search'); % [cite: 1531]
                end
            catch ME_orcid % [cite: 1532]
                if exist('progressdlg','var') && isvalid(progressdlg), delete(progressdlg); end % [cite: 1532]
                obj.ParentApp.alert(sprintf('Error searching ORCID: %s', ME_orcid.message), 'ORCID Search Error'); % [cite: 1533]
            end
        end
    end 
end