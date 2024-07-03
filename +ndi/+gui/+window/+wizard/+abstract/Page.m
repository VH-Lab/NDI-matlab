classdef Page < handle & matlab.mixin.Heterogeneous

    % Todo
    % [ ] Layout keyword / token. Preconfigure some layouts that can fit in the
    %     wizards grid layout. 
    %  - [ ] On construction: Set up components in layout
    %  - [ ] On switching pages: Hide/show components...

    % [ ] GetPageData / SetPageData
   

    properties (Abstract, Constant)
        Name
        Title
        Description
    end

    properties (Access = {?ndi.gui.window.wizard.WizardApp, ?ndi.gui.window.wizard.abstract.Page})
        ShowNavigationButtons = true
        DoCreatePanel = true
        IsInitialized = false
    end

    properties (Access = protected)
        ParentApp
        UIPanel
    end

    properties
        Visible (1,1) matlab.lang.OnOffSwitchState = "on"
    end
    
    methods
        function obj = Page()
        end
    end

    methods (Access = {?ndi.gui.window.wizard.WizardApp, ?ndi.gui.window.wizard.abstract.Page})
        function initialize(obj, parentApp)
            obj.ParentApp = parentApp;

            %pause(1)
            if obj.DoCreatePanel
                obj.createPanel()
            end
            obj.createComponents()

            obj.IsInitialized = true;
        end
    end

    methods (Access = ?ndi.gui.window.wizard.WizardApp)
        function enterPage(obj)
            obj.show()
            obj.onPageEntered()
        end

        function leavePage(obj)
            obj.hide()
            obj.onPageExited()
        end

        function show(obj)
            obj.Visible = 'on';
        end

        function hide(obj)
            obj.Visible = 'off';
        end
    end

    methods (Access = protected)
        
        function onVisiblePropertyValueSet(obj)
            if ~isempty(obj.UIPanel)
                obj.UIPanel.Visible = obj.Visible;
            end
        end

        function onPageEntered(obj)
            % Subclasses may override
        end

        function onPageExited(obj)
            % Subclasses may override
        end

        function createComponents(obj)
            % descriptionLabel = uilabel( obj.UIPanel );
            % descriptionLabel.Position = [50,30,200,25];
            % descriptionLabel.HorizontalAlignment = 'center';
            % descriptionLabel.VerticalAlignment = 'top';
            % descriptionLabel.FontSize = 16;
            % descriptionLabel.Text = 'Lorem Ipsum';
        end
    end

    methods (Access = private)
        function createPanel(obj)
            obj.UIPanel = uipanel( ...
                obj.ParentApp.BodyGridLayout, ...
                'Visible', 'off', ...
                'BackgroundColor', 'w', ...
                'BorderColor', obj.ParentApp.Theme.HeaderBgColor, ...
                'BorderWidth', 1);
            obj.UIPanel.Tag = sprintf(obj.Title);

            obj.UIPanel.Layout.Row = 3;
            obj.UIPanel.Layout.Column = 1;
        end
    end

    methods 
        function set.Visible(obj, newValue)
            obj.Visible = newValue;
            obj.onVisiblePropertyValueSet()
        end
    end

end