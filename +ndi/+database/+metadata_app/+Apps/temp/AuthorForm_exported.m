classdef AuthorForm_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                        matlab.ui.Figure
        GridLayout                      matlab.ui.container.GridLayout
        Panel                           matlab.ui.container.Panel
        InstitutesAffiliationsListBox   matlab.ui.control.ListBox
        InstitutesAffiliationsListBoxLabel  matlab.ui.control.Label
        DigitalIdentifierORCIDEditField  matlab.ui.control.EditField
        DigitalIdentifierORCIDEditFieldLabel  matlab.ui.control.Label
        FamilyNameEditField             matlab.ui.control.EditField
        FamilyNameEditFieldLabel        matlab.ui.control.Label
        GivenNameEditField              matlab.ui.control.EditField
        GivenNameEditFieldLabel         matlab.ui.control.Label
        AuthorEmailEditField            matlab.ui.control.EditField
        AuthorEmailEditFieldLabel       matlab.ui.control.Label
        AdditionalDetailsTextArea       matlab.ui.control.TextArea
        AdditionalDetailsTextAreaLabel  matlab.ui.control.Label
        AddAffiliationButton            matlab.ui.control.Button
        Tree                            matlab.ui.container.CheckBoxTree
        stAuthorNode                    matlab.ui.container.TreeNode
        CustodianNode                   matlab.ui.container.TreeNode
        CorrespondingNode               matlab.ui.container.TreeNode
        AuthorRoleLabel                 matlab.ui.control.Label
        GridLayout2                     matlab.ui.container.GridLayout
        CancelButton                    matlab.ui.control.Button
        CreateButton                    matlab.ui.control.Button
    end

    
    properties (Dependent)
        Visible (1,1) matlab.lang.OnOffSwitchState
    end

    properties
        % Whether the user confirms (saves changes) or cancels
        FinishState (1,1) string % "Save" or "Cancel"
    end

    properties (Access = private)
        IsStandalone (1,1) logical = true % If app is opened independently or from another app (i.e NDI Dataset Uploader)
    end

    methods 
        function set.Visible(app, value)
            app.UIFigure.Visible = value;
        end
        function value = get.Visible(app)
            value = app.UIFigure.Visible;
        end
    end
    
    methods (Access = public)
    
        function setAuthorDetails(app, S)
            app.GivenNameEditField.Value = S.GivenName;
            app.FamilyNameEditField.Value = S.FamilyName;
            app.AuthorEmailEditField.Value = S.ContactInformation;
            app.DigitalIdentifierORCIDEditField.Value = S.DigitalIdentifier;
        end

        function S = getAuthorDetails(app)
            S = struct;
            S.GivenName = app.GivenNameEditField.Value;
            S.FamilyName = app.FamilyNameEditField.Value;
            S.ContactInformation = app.AuthorEmailEditField.Value;
            S.DigitalIdentifier = app.DigitalIdentifierORCIDEditField.Value;
        end

        function reset(app)
            app.GivenNameEditField.Value = '';
            app.FamilyNameEditField.Value = '';
            app.AuthorEmailEditField.Value = '';
            app.DigitalIdentifierORCIDEditField.Value = '';
            app.FinishState = "";
        end

        function waitfor(app)
            app.IsStandalone = false;
            uiwait(app.UIFigure)
        end
    end

    methods (Access = private)
                
        function testCreatePerson(app, field, value)
            try
                p = openminds.core.Person(field, value);
            catch ME
                uialert(app.UIFigure, ME.message, 'Invalid input')
            end
        end
    end
    

    % Callbacks that handle component events
    methods (Access = private)

        % Value changed function: AuthorEmailEditField
        function AuthorEmailEditFieldValueChanged(app, event)
            value = app.AuthorEmailEditField.Value;
            
            % Todo: Check that email adress is valid
            try
                %contactInformation = openminds.core.ContactInformation('email', value);
                mustBeValidEmail(value) % Note: This is a function from openMINDS_MATLAB
            catch ME
                uialert(app.UIFigure, ME.message, 'Invalid input')
            end
        end

        % Value changed function: DigitalIdentifierORCIDEditField
        function DigitalIdentifierORCIDEditFieldValueChanged(app, event)
            value = app.DigitalIdentifierORCIDEditField.Value;
            try
                orcid = openminds.core.ORCID('identifier', value);
            catch ME
                errMessage = sprintf('The entered value is not a valid ORCID. For examples of valid ORCID, please see this <a href=https://support.orcid.org/hc/en-us/articles/360006897674-Structure-of-the-ORCID-Identifier#3-some-sample-orcid-ids>link</a>');
                uialert(app.UIFigure, errMessage, 'Invalid ORCID', 'Interpreter', 'html')
                %uialert(app.UIFigure, ME.message, 'Invalid input', 'Interpreter', 'html')
            end
        end

        % Button pushed function: CreateButton
        function CreateButtonPushed(app, event)
            app.FinishState = "Save";
            app.UIFigureCloseRequest()
        end

        % Button pushed function: CancelButton
        function CancelButtonPushed(app, event)
            app.FinishState = "Cancel";
            app.UIFigureCloseRequest()
        end

        % Close request function: UIFigure
        function UIFigureCloseRequest(app, event)
            if app.IsStandalone
                delete(app)
            else
                if app.FinishState == ""
                    app.FinishState = uiconfirm(app.UIFigure, 'Do you want to save the new author?', 'Save changes?', 'Options', {'Save', 'Cancel'} );
                end
                uiresume(app.UIFigure)
            end
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 659 442];
            app.UIFigure.Name = 'Edit Author Details';
            app.UIFigure.CloseRequestFcn = createCallbackFcn(app, @UIFigureCloseRequest, true);

            % Create GridLayout
            app.GridLayout = uigridlayout(app.UIFigure);
            app.GridLayout.ColumnWidth = {'1x'};
            app.GridLayout.RowHeight = {'5x', 50};
            app.GridLayout.Padding = [20 10 20 30];

            % Create GridLayout2
            app.GridLayout2 = uigridlayout(app.GridLayout);
            app.GridLayout2.ColumnWidth = {'1x', 100, 75, 100, '1x'};
            app.GridLayout2.RowHeight = {'1x', 25, '1x'};
            app.GridLayout2.Padding = [0 0 0 0];
            app.GridLayout2.Layout.Row = 2;
            app.GridLayout2.Layout.Column = 1;

            % Create CreateButton
            app.CreateButton = uibutton(app.GridLayout2, 'push');
            app.CreateButton.ButtonPushedFcn = createCallbackFcn(app, @CreateButtonPushed, true);
            app.CreateButton.Layout.Row = 2;
            app.CreateButton.Layout.Column = 2;
            app.CreateButton.Text = 'Create';

            % Create CancelButton
            app.CancelButton = uibutton(app.GridLayout2, 'push');
            app.CancelButton.ButtonPushedFcn = createCallbackFcn(app, @CancelButtonPushed, true);
            app.CancelButton.Layout.Row = 2;
            app.CancelButton.Layout.Column = 4;
            app.CancelButton.Text = 'Cancel';

            % Create Panel
            app.Panel = uipanel(app.GridLayout);
            app.Panel.Layout.Row = 1;
            app.Panel.Layout.Column = 1;

            % Create AuthorRoleLabel
            app.AuthorRoleLabel = uilabel(app.Panel);
            app.AuthorRoleLabel.Position = [347 268 68 22];
            app.AuthorRoleLabel.Text = 'Author Role';

            % Create Tree
            app.Tree = uitree(app.Panel, 'checkbox');
            app.Tree.Tooltip = {'An author can have multiple roles'};
            app.Tree.Position = [428 216 154 74];

            % Create stAuthorNode
            app.stAuthorNode = uitreenode(app.Tree);
            app.stAuthorNode.Text = '1st Author';

            % Create CustodianNode
            app.CustodianNode = uitreenode(app.Tree);
            app.CustodianNode.Text = 'Custodian';

            % Create CorrespondingNode
            app.CorrespondingNode = uitreenode(app.Tree);
            app.CorrespondingNode.Text = 'Corresponding';

            % Create AddAffiliationButton
            app.AddAffiliationButton = uibutton(app.Panel, 'push');
            app.AddAffiliationButton.Position = [482 32 100 23];
            app.AddAffiliationButton.Text = 'Add Affiliation';

            % Create AdditionalDetailsTextAreaLabel
            app.AdditionalDetailsTextAreaLabel = uilabel(app.Panel);
            app.AdditionalDetailsTextAreaLabel.HorizontalAlignment = 'right';
            app.AdditionalDetailsTextAreaLabel.Position = [51 70 59 30];
            app.AdditionalDetailsTextAreaLabel.Text = {'Additional'; 'Details'};

            % Create AdditionalDetailsTextArea
            app.AdditionalDetailsTextArea = uitextarea(app.Panel);
            app.AdditionalDetailsTextArea.Tooltip = {'Anything else you''d like us to know about this author? Note: This field is not public facing.'};
            app.AdditionalDetailsTextArea.Position = [121 32 200 70];

            % Create AuthorEmailEditFieldLabel
            app.AuthorEmailEditFieldLabel = uilabel(app.Panel);
            app.AuthorEmailEditFieldLabel.HorizontalAlignment = 'right';
            app.AuthorEmailEditFieldLabel.Position = [27 188 73 22];
            app.AuthorEmailEditFieldLabel.Text = 'Author Email';

            % Create AuthorEmailEditField
            app.AuthorEmailEditField = uieditfield(app.Panel, 'text');
            app.AuthorEmailEditField.ValueChangedFcn = createCallbackFcn(app, @AuthorEmailEditFieldValueChanged, true);
            app.AuthorEmailEditField.Position = [121 188 200 22];

            % Create GivenNameEditFieldLabel
            app.GivenNameEditFieldLabel = uilabel(app.Panel);
            app.GivenNameEditFieldLabel.HorizontalAlignment = 'right';
            app.GivenNameEditFieldLabel.Position = [29 284 71 22];
            app.GivenNameEditFieldLabel.Text = 'Given Name';

            % Create GivenNameEditField
            app.GivenNameEditField = uieditfield(app.Panel, 'text');
            app.GivenNameEditField.Position = [121 284 200 22];

            % Create FamilyNameEditFieldLabel
            app.FamilyNameEditFieldLabel = uilabel(app.Panel);
            app.FamilyNameEditFieldLabel.HorizontalAlignment = 'right';
            app.FamilyNameEditFieldLabel.Position = [25 236 75 22];
            app.FamilyNameEditFieldLabel.Text = 'Family Name';

            % Create FamilyNameEditField
            app.FamilyNameEditField = uieditfield(app.Panel, 'text');
            app.FamilyNameEditField.Position = [121 236 200 22];

            % Create DigitalIdentifierORCIDEditFieldLabel
            app.DigitalIdentifierORCIDEditFieldLabel = uilabel(app.Panel);
            app.DigitalIdentifierORCIDEditFieldLabel.HorizontalAlignment = 'right';
            app.DigitalIdentifierORCIDEditFieldLabel.Position = [12 132 88 30];
            app.DigitalIdentifierORCIDEditFieldLabel.Text = {'Digital Identifier'; '(ORCID)'};

            % Create DigitalIdentifierORCIDEditField
            app.DigitalIdentifierORCIDEditField = uieditfield(app.Panel, 'text');
            app.DigitalIdentifierORCIDEditField.ValueChangedFcn = createCallbackFcn(app, @DigitalIdentifierORCIDEditFieldValueChanged, true);
            app.DigitalIdentifierORCIDEditField.Position = [121 140 200 22];

            % Create InstitutesAffiliationsListBoxLabel
            app.InstitutesAffiliationsListBoxLabel = uilabel(app.Panel);
            app.InstitutesAffiliationsListBoxLabel.HorizontalAlignment = 'right';
            app.InstitutesAffiliationsListBoxLabel.Position = [349 145 60 30];
            app.InstitutesAffiliationsListBoxLabel.Text = {'Institutes/'; 'Affiliations'};

            % Create InstitutesAffiliationsListBox
            app.InstitutesAffiliationsListBox = uilistbox(app.Panel);
            app.InstitutesAffiliationsListBox.Items = {'Institute 1 ', 'Institute 2'};
            app.InstitutesAffiliationsListBox.Position = [428 72 154 103];
            app.InstitutesAffiliationsListBox.Value = 'Institute 1 ';

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = AuthorForm_exported

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end