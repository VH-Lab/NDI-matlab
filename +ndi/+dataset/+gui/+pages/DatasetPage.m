classdef DatasetPage < ndi.gui.window.wizard.abstract.Page

    properties (Constant)
        Name = 'Dataset'
        Title = "Create Dataset"
        Description = "Initialize an NDI Dataset"
    end

    properties
        %DataModel ndi.dataset.gui.models.DatasetInfo
    end
    properties (SetAccess = ?ndi.gui.window.wizard.WizardApp)
        PageData ndi.dataset.gui.models.DatasetInfo
    end

    properties (Access = public, Dependent)
        DatasetTitle (1,1) string % Title of dataset
        DatasetRootPath (1,1) string % Root directory of a dataset
        DatasetRootPathLog (1,:) string
    end

    properties (Access = private) % App components
        GridLayout
        DatasetWidgets ndi.dataset.gui.pages.component.DatasetComponent
    end

    
    methods % Constructor
        function obj = DatasetPage(pageData)
            arguments
                pageData ndi.dataset.gui.models.DatasetInfo = ...
                    ndi.dataset.gui.models.DatasetInfo()
            end

            obj.PageData = pageData;
        end
    end

    methods
        function set.DatasetRootPath(obj, newValue)
            obj.setPropertyValue("DatasetRootPath", newValue)
        end
        function value = get.DatasetRootPath(obj)
            value = obj.getPropertyValue("DatasetRootPath");
        end

        function set.DatasetTitle(obj, newValue)
            obj.setPropertyValue("DatasetTitle", newValue)
        end
        function value = get.DatasetTitle(obj)
            value = obj.getPropertyValue("DatasetTitle");
        end

        function set.DatasetRootPathLog(obj, newValue)
            obj.setPropertyValue("DatasetRootPathLog", newValue)
        end
        function value = get.DatasetRootPathLog(obj)
            value = obj.DatasetWidgets.getFolderHistory();
        end
    end

    methods (Access = protected)
        
        function setPropertyValue(obj, propertyName, propertyValue)
            if ~isempty(obj.PageData)
                obj.PageData.(propertyName) = propertyValue;
            end
            if obj.IsInitialized
                obj.DatasetWidgets.(propertyName) = propertyValue;
            end
        end

        function propertyValue = getPropertyValue(obj, propertyName)
            if obj.IsInitialized
                propertyValue = obj.DatasetWidgets.(propertyName);
            else
                if isprop(obj.PageData, propertyName)
                    propertyValue = obj.PageData.(propertyName);
                else
                    propertyValue = "";
                end
            end
        end

        function onPageEntered(obj)
            % Subclasses may override
        end

        function onPageExited(obj)
            % Subclasses may override
        end

        function createComponents(obj)
            obj.GridLayout = uigridlayout(obj.UIPanel);
            obj.GridLayout.ColumnWidth = {'1x'};
            obj.GridLayout.RowHeight = {'1x'};
            obj.GridLayout.Padding = 0;

            obj.DatasetWidgets = ndi.dataset.gui.pages.component.DatasetComponent(obj.GridLayout);
            obj.DatasetWidgets.Layout.Row = 1;
            obj.DatasetWidgets.Layout.Column = 1;

            obj.DatasetWidgets.DatasetTitleValueChangedFcn = @obj.onDatasetTitleValueChanged;
            obj.DatasetWidgets.DatasetRootPathValueChangedFcn = @obj.onDatasetRootPathValueChanged;

            if isprop(obj.PageData, "DatasetTitle")
                obj.DatasetWidgets.DatasetTitle = obj.PageData.DatasetTitle;
            end
            if isprop(obj.PageData, "DatasetRootPath")
                obj.DatasetWidgets.DatasetRootPath = obj.PageData.DatasetRootPath;
            end
            if isprop(obj.PageData, "DatasetRootPathLog")
                obj.DatasetWidgets.setFolderHistory(obj.PageData.DatasetRootPathLog);
            end
        end
    end

    methods (Access = private)
        function onDatasetTitleValueChanged(obj, src, ~)
            obj.DatasetTitle = src.DatasetTitle;
        end
        function onDatasetRootPathValueChanged(obj, src, ~)
            obj.DatasetRootPath = src.DatasetRootPath;
        end
    end
end

