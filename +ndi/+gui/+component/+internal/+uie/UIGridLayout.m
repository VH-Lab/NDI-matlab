classdef UIGridLayout < ndi.gui.component.internal.uie.mixin.UIContainer & ...
                         ndi.gui.component.internal.uie.UIElement & ...
                         ndi.gui.component.internal.uie.mixin.UIVisualComponent

    % UIGRIDLAYOUT Describes a grid layout manager component.

    properties
        % RowHeight - Defines the height of each row in the grid.
        %
        % A cell array where each element can be a fixed pixel height (e.g., 22),
        % a weight (e.g., '1x'), or 'fit'.
        RowHeight cell = {'1x'}
        
        % ColumnWidth - Defines the width of each column in the grid.
        %
        % A cell array where each element can be a fixed pixel width (e.g., 100),
        % a weight (e.g., '2x'), or 'fit'.
        ColumnWidth cell = {'1x'}

        % Padding - Space between the grid layout boundary and its content.
        %
        % A 1x4 vector [left bottom right top].
        Padding (1,4) {mustBeNumeric} = [10 10 10 10]
        
        % RowSpacing - Vertical space between rows.
        RowSpacing (1,1) {mustBeNumeric, mustBeNonnegative} = 10
        
        % ColumnSpacing - Horizontal space between columns.
        ColumnSpacing (1,1) {mustBeNumeric, mustBeNonnegative} = 10
    end
    
    methods (Static)
        function obj = fromAlphaNumericStruct(className, alphaS_in, options)
            % FROMALPHANUMERICSTRUCT Creates a UIGridLayout from an alphanumeric struct.
            %
            % This override handles the conversion of 'RowHeight' and 'ColumnWidth'
            % from delimited strings back to cell arrays.
            arguments
                className (1,1) string
                alphaS_in (1,1) struct
                options.errorIfFieldNotPresent (1,1) logical = false
                options.dispatch (1,1) logical = true
            end
            
            S_in = alphaS_in;
            
            % Helper function to convert string to cell
            function c = string2cell(str_in)
                if isempty(str_in), c = {}; return; end
                c = strsplit(str_in, ', ');
            end
            
            % Handle RowHeight property
            if isfield(S_in, 'RowHeight') && (ischar(S_in.RowHeight) || isstring(S_in.RowHeight))
                S_in.RowHeight = string2cell(char(S_in.RowHeight));
            end
            
            % Handle ColumnWidth property
            if isfield(S_in, 'ColumnWidth') && (ischar(S_in.ColumnWidth) || isstring(S_in.ColumnWidth))
                S_in.ColumnWidth = string2cell(char(S_in.ColumnWidth));
            end
            
            % Call the base class's method with dispatch turned OFF
            obj = fromAlphaNumericStruct@ndi.util.StructSerializable(className, S_in, ...
                'errorIfFieldNotPresent', options.errorIfFieldNotPresent, ...
                'dispatch', false);
        end
    end
end