classdef SubjectPage < ndi.gui.window.wizard.abstract.Page

    properties (Constant)
        Name = 'Subject'
        Title = "Edit Subjects"
        Description = "Enter subject details"
    end

    properties (SetAccess = ?ndi.gui.window.wizard.WizardApp)
        PageData % ndi.dataset.gui.models.DatasetInfo
    end

    properties % UI Data % TODO: move to model?
        RootDirectory
    end
 

    properties (Access = public, Dependent)
        DatasetRootPath (1,1) string % Root directory of a dataset
    end

    properties (Access = private) % App components
        GridLayout
        DatasetWidgets %ndi.dataset.gui.pages.component.DatasetComponent
    end

    
    methods % Constructor
        function obj = SubjectPage()
            %obj.PageData = ndi.dataset.gui.models.DatasetInfo();
        end
    end

    methods
        function set.DatasetRootPath(obj, newValue)
            obj.setPropertyValue("DatasetRootPath", newValue)
        end
        function value = get.DatasetRootPath(obj)
            value = obj.getPropertyValue("DatasetRootPath");
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
            obj.GridLayout.BackgroundColor = 'w';
            obj.GridLayout.Padding = 10;

            datasetFolder = obj.DatasetRootPath;
            app.Dataset = ndi.dataset.dir('test', char(datasetFolder));
            
            subjectData = ndi.database.metadata_app.fun.loadSubjects(app.Dataset);
            subjectTableData = subjectData.formatTable();

            instanceTable = openminds.internal.listControlledInstances('BiologicalSex');
            options = instanceTable.InstanceName;

            % Todo: Do subjects have sex from before?
            subjectTableData(1).BiologicalSex = categorical({'male'}, options);
            subjectTableData(2).BiologicalSex = categorical({'female'}, options);
            
            
            % Create the WidgetTable component
            widgetTable = WidgetTable(obj.GridLayout, ...
                HeaderBackgroundColor="#FFFFFF", ...
                HeaderForegroundColor = "#002054", ...
                BackgroundColor = 'white', ...
                TableBorderType='none');
            

            allStrains = ndi.database.metadata_ds_core.conversion.getAllStrains();
            allInstancesCell = allStrains.values();
            metadataCollection = openminds.Collection(allInstancesCell{:});
            
            subjectTableData(1).Species = openminds.controlledterms.Species.empty;
            subjectTableData(2).Species = openminds.controlledterms.Species();

            subjectTableData(1).Strain = allStrains('aqp4ko');
            subjectTableData(1).Species = subjectTableData(1).Strain.species;
            subjectTableData(2).Strain = openminds.core.Strain();
            subjectTableData(2).Species = subjectTableData(2).Strain.species;

            
            strainDrodownFcn = @(h, varargin) om.internal.control.InstanceDropDown(h, ...
                "MetadataType", 'openminds.core.research.Strain', ...
                "MetadataTypeConstraint", om.internal.InstanceFilter, ...
                "MetadataCollection", metadataCollection, ...
                "ActionButtonType", "InstanceEditorButton");
            speciesDropdownFcn = @(h, varargin) om.internal.control.InstanceDropDown(h, ...
                "MetadataType", 'openminds.controlledterms.Species', ...
                "MetadataCollection", metadataCollection, ...
                "ActionButtonType", "InstanceEditorButton", ...
                "CustomActions", om.internal.control.action.NCBITaxonSearch);

            widgetTable.ColumnWidget = {'', '', speciesDropdownFcn, strainDrodownFcn};
            widgetTable.Data = subjectTableData;
            widgetTable.CellEditedFcn = @obj.onCellEdited;
        end

        function onCellEdited(obj, src, evt)
            varNames = src.VariableNames;
        
            switch varNames{ evt.Indices(2) }
                case 'Species'
                    dependentColumnIndex = find(strcmp(varNames, 'Strain'));
                    %rowIdx = evt.Indices(1);

                    hControl = src.getRowControl(evt.DisplayIndices(1), dependentColumnIndex);
                    newConstraint = hControl.MetadataTypeConstraints;
                    newConstraint.FilterCondition = char(evt.NewData);
                    hControl.MetadataTypeConstraints = newConstraint;
            end
        end

        function updateStrainInstances(obj)
        %function populateStrainList(app)
            if isempty(app.SpeciesListBox.Value) || ismissing(app.SpeciesListBox.Value)
                items = "Select a Species";
            else
                species = app.SpeciesListBox.Value;
                strainCatalog = getStrainInstances(app);
                if strainCatalog.NumItems == 0
                    items = "No Strains Available";
                else
                    allStrains = string( {strainCatalog(:).species} );
                    %[~, allStrains] = fileparts(allStrains);
    
                    keep = allStrains == species;
    
                    if ~any(keep)
                        items = "No Strains Available";
                    else
                        items = string( {strainCatalog(keep).name} );
                    end
                end       
            end
            app.StrainListBox.Items = items;
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

