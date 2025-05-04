classdef DatasetWizardApp < ndi.gui.window.wizard.WizardApp
% DatasetWizardApp - Class providing an app for configuring an NDI Dataset

% This is a multi-page wizard app. Each page connects a data model with a
% gui / page object for manipulating / modifying the model.
%
% This app holds the AppData. The AppData contains all the configurations
% necessary for a dataset. It has subfields that represents specific
% models, and these models are assigned to pages.
%
% AppData is a class. It loads everything to/from jsons. Ideally, it would
% initialize the .ndi database and already work with ndi-documents, but for
% now we load and save to non-ndi json documents.


% Questions:
% Daq Systems are added to sessions. Can we add a daq system configuration
% to the dataset's database?

    % Responsibility
    % Keep cross-page dependencies synched
    % Export data from gui
    % Import data to gui


    properties (SetAccess = private)
        DatasetRootDirectory (1,1) string = missing
        AppData ndi.dataset.gui.NDIDatasetConfiguration
        Preferences ndi.dataset.gui.Preferences
    end

    properties (Access = protected)
        Title = "NDI Dataset Wizard"
        PageNames = [...
            "ndi.dataset.gui.pages.IntroPage", ...
            "ndi.dataset.gui.pages.DatasetPage", ...
            "ndi.dataset.gui.folderorganization.FolderOrganizationPage", ...
            "ndi.dataset.gui.pages.SubjectPage", ...
            "ndi.dataset.gui.pages.DaqSystemsPage" ...
            ] %"ndi.dataset.gui.pages.MetadataPage", ...
                    %"ndi.dataset.gui.pages.FolderOrganizationPage", ...

    end

    properties (Constant, Access = protected)
        AppPath = fileparts( mfilename('fullpath') )
        LogoFilePath = ndi.gui.utility.internal.getLogoPath('ndi_cloud', 'dark')
        % LoadingComponent % Todo
        MinimumSize = [750, 550]
    end

    properties (Access = private)
        RootDirectoryListener event.listener
    end

    methods
        function app = DatasetWizardApp( datasetFolder )

            arguments
                datasetFolder (1,1) string = missing
            end
            
            if exist('wt.FileSelector', 'class') ~= 8
                ndi.internal.setup.installWidgetsToolbox()
            end
        
            if ~ismissing(datasetFolder)
                app.DatasetRootDirectory = datasetFolder;
            end

            app.loadPreferences()

            if ~nargout; clear app; end
        end
    end

    methods % Property set method
        function set.DatasetRootDirectory(app, newValue)
            app.DatasetRootDirectory = newValue;
            app.onDatasetRootDirectorySet()
        end
    end

    methods (Access = protected) % Implement superclass (WizardApp) methods
        function onPageCreated(app, pageObject)
            switch class(pageObject)
                case "ndi.dataset.gui.pages.DatasetPage"
                    app.onDatasetPageCreated( pageObject )
                case "ndi.dataset.gui.pages.FolderOrganizationPage"
                    app.onFolderOrganizationPageCreated( pageObject )
                case "ndi.dataset.gui.pages.DaqSystemsPage"
                    app.onDaqSystemsPageCreated( pageObject )
            end
        end
    
        function doAbort = onFigureCloseRequest(app, event)
            
            app.promptSaveCurrentChanges()
            app.savePreferences()
            doAbort = false;
        end
    
        function loadTheme(app)
            app.Theme = ndi.dataset.gui.WizardTheme();
        end
    end

    methods (Access = private) % Page created callbacks
        
        % Dataset Page: Page created callback
        function onDatasetPageCreated(app, pageObject)
            if ~ismissing(app.DatasetRootDirectory)
                pageObject.DatasetRootPath = app.DatasetRootDirectory;
            end
            app.RootDirectoryListener = listener(pageObject.PageData, ...
                'DatasetRootPath', 'PostSet', @app.onRootDirectoryChanged);
        end

        function onFolderOrganizationPageCreated(app, pageObject)
            referencePage = app.getPage("Create Dataset");
            pageObject.RootDirectory = referencePage.DatasetRootPath;
            %pageObject.PresetFolderModels = app.PresetFolderModels.keys();
        end

        function onDaqSystemsPageCreated(app, pageObject)
            pageObject.EditDaqSystemFcn = @app.uiEditDaqSystem;
        end
    end

    methods (Access = private) % Property changed callbacks
        function onRootDirectoryChanged(app, ~, evt)
            app.DatasetRootDirectory = evt.AffectedObject.(evt.Source.Name);
        end

        function onDatasetRootDirectorySet(app)

            if ~isempty(app.AppData)
                app.promptSaveCurrentChanges()
            end

            app.AppData = ndi.dataset.gui.NDIDatasetConfiguration(app.DatasetRootDirectory);

            % Assign to all page modules...
            page = app.getPage("Create Dataset");
            page.PageData = app.AppData.DatasetInformation;

            page = app.getPage("Folder Organization");
            page.RootDirectory = app.DatasetRootDirectory;
            page.DataModel = app.AppData.FolderModel;

            % Assign daq systems
            page = app.getPage("DAQ Systems");
            page.PageData = app.AppData.DaqSystemsCollection;

            page = app.getPage("Edit Subjects");
            page.RootDirectory = app.DatasetRootDirectory;
        end
    end
    
    methods (Access = private) % Callbacks
        function updatedDaqSystem = uiEditDaqSystem(app, daqSystem)
            epochFolder = app.AppData.FolderModel.getExampleFolder();
            if strcmp( app.AppData.FolderModel.FolderLevels(end).Type, "Epoch" )
                epochOrganization = "nested";
            else
                epochOrganization = "flat";
            end

            hWaitbar = uiprogressdlg(app.UIFigure, "Indeterminate", "on", ...
                "Message", "Please wait while opening DAQ System Configurator");
            waitbarCleanupObj = onCleanup(@() delete(hWaitbar));

            h = NDIDaqSystemConfig(app.DatasetRootDirectory, epochFolder, epochOrganization, daqSystem);
            appCleanupObj = onCleanup(@() delete(h));
            clear waitbarCleanupObj
            
            % Wait for user to finish editing
            uiwait(h);
            
            % % Get updated data.
            updatedDaqSystem = h.DaqSystemConfiguration;

            clear appCleanupObj
        end
    end

    methods (Access = private) 
        function promptSaveCurrentChanges(app)
            % Todo: Check if there are changes...
            if isempty(app.AppData) || app.AppData.isClean()
                return
            end

            answer = uiconfirm(app.UIFigure, ...
                "Do you want to save changes for current dataset?", ...
                "Save Changes?", ...
                "Options", ["Yes", "No"], ...
                "DefaultOption", "Yes", ...
                "CancelOption", "No");
            switch answer
                case "Yes"
                    app.AppData.save()
                case "No"
                    % pass
            end
        end
    end

    methods % Save/load preferences
        
        function loadPreferences(app)
            app.Preferences = ndi.dataset.gui.Preferences.load( class(app), fullfile('ndi', 'dataset_wizard'));
            app.UIFigure.Position = app.Preferences.Position;

            referencePage = app.getPage("Create Dataset");
            referencePage.DatasetRootPathLog = app.Preferences.DatasetFolderHistory;
        end %loadPreferences
        
        function savePreferences(app)
            app.Preferences.Position = app.UIFigure.Position;
            
            referencePage = app.getPage("Create Dataset");
            if referencePage.IsInitialized
                app.Preferences.DatasetFolderHistory = referencePage.DatasetRootPathLog;
            end

            app.Preferences.save(class(app), fullfile('ndi', 'dataset_wizard'));
        end %savePreferences
    end

end
