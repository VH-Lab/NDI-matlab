classdef TabController < handle & matlab.mixin.Heterogeneous
    % NDI.GUI.COMPONENT.INTERNAL.TABCONTROLLER - A base class for managing a single UI Tab.
    % Inherits from matlab.mixin.Heterogeneous to allow different subclasses
    % to be stored in the same typed array.
    
    properties (SetAccess = private, GetAccess = public)
        Tab         matlab.ui.container.Tab
    end
    
    properties (Access = protected)
        % Subclasses define their UI components here.
    end
    
    methods (Access = public)
        function app = TabController(theTab)
            arguments
                theTab (1,1) matlab.ui.container.Tab
            end
            
            app.Tab = theTab;
            app.createComponents();
            app.redrawTab();
        end
        
        function missingField = checkRequiredFields(app)
            missingField = [];
        end
        
        function alertRequiredFieldsMissing(app, missingFieldName)
            disp(['Alert: Required field is missing: ' missingFieldName]);
        end
        
        function redrawTab(app)
            % (No action in base class)
        end
        
        function tabSelected(app)
            % (No action in base class)
            disp(['Tab "' app.Tab.Title '" was selected.']);
        end
        
        function tabDeSelected(app)
            % (No action in base class)
            disp(['Tab "' app.Tab.Title '" was de-selected.']);
        end
    end
    
    methods (Access = protected)
        function createComponents(app)
            % Base class creates a simple grid layout.
            app.Tab.AutoResizeChildren = 'off';
            uigridlayout(app.Tab, 'ColumnWidth', {'1x'}, 'RowHeight', {'1x'});
        end
    end

    % Allow creation of empty objects for heterogeneous arrays
    methods (Static, Sealed, Access = protected)
        function defaultObject = getDefaultScalarElement
            % This function is required by matlab.mixin.Heterogeneous
            % It should return a default-constructed object of a concrete subclass.
            % Since TabController is abstract-like, we can't create it directly.
            % This part of the design would need a concrete default, or
            % we must ensure we never create an empty array that needs a default.
            % For now, we'll error if this is ever called.
            error('TabController:noDefault', ...
                  'A default TabController cannot be created. Please initialize arrays with a concrete subclass object.');
        end
    end
end
