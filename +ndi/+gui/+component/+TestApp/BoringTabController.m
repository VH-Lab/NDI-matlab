classdef BoringTabController < ndi.gui.component.internal.TabController
    % BORINGTABCONTROLLER - A simple demonstration of a TabController subclass.
    
    properties (Access = public)
        MainGridLayout      matlab.ui.container.GridLayout
        InstructionsLabel   matlab.ui.control.Label
        NameEditField       matlab.ui.control.EditField
    end
    
    methods
        function app = BoringTabController(theTab)
            % The call to the superclass constructor must be the first line.
            app@ndi.gui.component.internal.TabController(theTab);
        end
        
        % --- Override base class methods ---
        
        function missingField = checkRequiredFields(app)
            % Check if the edit field is empty.
            if isempty(strtrim(app.NameEditField.Value))
                missingField = "Name"; % Return the name of the missing field
            else
                missingField = []; % Return empty, indicating success
            end
        end

        function redrawTab(app)
            % Set the initial state of the components.
            app.NameEditField.Value = ['Data for ' app.Tab.Title];
        end

        function tabSelected(app)
            % Override to provide specific feedback.
            disp(['BoringTabController for "' app.Tab.Title '" was selected.']);
            app.MainGridLayout.BackgroundColor = [0.90, 0.95, 1.0]; % Light blue
        end

        function tabDeSelected(app)
            % Override to provide specific feedback.
            disp(['BoringTabController for "' app.Tab.Title '" was de-selected.']);
            app.MainGridLayout.BackgroundColor = [0.94, 0.94, 0.94]; % Default grey
        end
    end
    
    methods (Access = protected)
        function createComponents(app)
            % Create the components for this specific tab.
            
            app.MainGridLayout = uigridlayout(app.Tab, 'ColumnWidth', {150, '1x'}, 'RowHeight', {'fit', 'fit'});
            app.MainGridLayout.Padding = [20 20 20 20];
            app.MainGridLayout.BackgroundColor = [0.94, 0.94, 0.94];

            % Create InstructionsLabel
            app.InstructionsLabel = uilabel(app.MainGridLayout);
            app.InstructionsLabel.Layout.Row = 1;
            app.InstructionsLabel.Layout.Column = [1 2];
            app.InstructionsLabel.Text = 'This is a simple tab. The "Name" field below is required.';
            app.InstructionsLabel.WordWrap = 'on';
            
            % Create NameLabel
            nameLabel = uilabel(app.MainGridLayout);
            nameLabel.Layout.Row = 2;
            nameLabel.Layout.Column = 1;
            nameLabel.HorizontalAlignment = 'right';
            nameLabel.Text = 'Name:';

            % Create NameEditField
            app.NameEditField = uieditfield(app.MainGridLayout, 'text');
            app.NameEditField.Layout.Row = 2;
            app.NameEditField.Layout.Column = 2;
        end
    end
end
