classdef TitleAbstractTabController < ndi.gui.component.internal.TabController
    % TITLEABSTRACTTABCONTROLLER - Manages the Title/Abstract tab UI.
    
    properties (Access = public)
        MainGridLayout      matlab.ui.container.GridLayout
        
        TitleLabel          matlab.ui.control.Label
        TitleEditField      matlab.ui.control.EditField
        
        ShortNameLabel      matlab.ui.control.Label
        ShortNameEditField  matlab.ui.control.EditField
        
        AbstractLabel       matlab.ui.control.Label
        AbstractTextArea    matlab.ui.control.TextArea
        
        CommentsLabel       matlab.ui.control.Label
        CommentsTextArea    matlab.ui.control.TextArea
    end
    
    methods
        function app = TitleAbstractTabController(theTab)
            % Call the base class constructor
            app@ndi.gui.component.internal.TabController(theTab);
        end
        
        function redrawTab(app)
            % This function would be used to populate the fields with data.
            % For now, we can set some default values.
            app.TitleEditField.Value = 'Example: My Visual Cortex Experiment';
            app.ShortNameEditField.Value = 'my-vis-ctx-exp-01';
            app.AbstractTextArea.Value = sprintf(['This is an example abstract.\n\n',...
                'It describes the goals and methods of the experiment. Since its row height is set to ''2x'', ',...
                'it will take up twice as much vertical space as the ''Comments'' field below.']);
            app.CommentsTextArea.Value = 'Initial comments go here.';
        end
    end
    
    methods (Access = protected)
        function createComponents(app)
            % Create the components for this specific tab.
            
            % Define a more complex grid to handle different widths and scaling heights
            app.MainGridLayout = uigridlayout(app.Tab);
            app.MainGridLayout.ColumnWidth = {'fit', 300, '1x'};
            app.MainGridLayout.RowHeight = {'fit', 'fit', 'fit', '2x', 'fit', '1x'};
            app.MainGridLayout.Padding = [20 20 20 20];
            app.MainGridLayout.RowSpacing = 10;
            app.MainGridLayout.ColumnSpacing = 10;

            % --- Row 1: Dataset Title ---
            app.TitleLabel = uilabel(app.MainGridLayout, 'Text', 'Dataset Title:', 'HorizontalAlignment', 'right');
            app.TitleLabel.Layout.Row = 1;
            app.TitleLabel.Layout.Column = 1;
            
            app.TitleEditField = uieditfield(app.MainGridLayout, 'text', 'Tag', 'TitleEditField');
            app.TitleEditField.Layout.Row = 1;
            app.TitleEditField.Layout.Column = [2 3]; % Span remaining columns

            % --- Row 2: Short Name ---
            app.ShortNameLabel = uilabel(app.MainGridLayout, 'Text', 'Short Name:', 'HorizontalAlignment', 'right');
            app.ShortNameLabel.Layout.Row = 2;
            app.ShortNameLabel.Layout.Column = 1;

            app.ShortNameEditField = uieditfield(app.MainGridLayout, 'text', 'Tag', 'ShortNameEditField');
            app.ShortNameEditField.Layout.Row = 2;
            app.ShortNameEditField.Layout.Column = 2; % Fixed width column

            % --- Row 3 & 4: Abstract ---
            app.AbstractLabel = uilabel(app.MainGridLayout, 'Text', 'Abstract:');
            app.AbstractLabel.Layout.Row = 3;
            app.AbstractLabel.Layout.Column = [1 3]; % Span all columns

            app.AbstractTextArea = uitextarea(app.MainGridLayout, 'Tag', 'AbstractTextArea');
            app.AbstractTextArea.Layout.Row = 4;
            app.AbstractTextArea.Layout.Column = [1 3]; % Span all columns

            % --- Row 5 & 6: Comments ---
            app.CommentsLabel = uilabel(app.MainGridLayout, 'Text', 'Comments:');
            app.CommentsLabel.Layout.Row = 5;
            app.CommentsLabel.Layout.Column = [1 3]; % Span all columns
            
            app.CommentsTextArea = uitextarea(app.MainGridLayout, 'Tag', 'CommentsTextArea');
            app.CommentsTextArea.Layout.Row = 6;
            app.CommentsTextArea.Layout.Column = [1 3]; % Span all columns
        end
    end
end