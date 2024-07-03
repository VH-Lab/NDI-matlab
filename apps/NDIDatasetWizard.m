function app = NDIDatasetWizard(datasetFolder)
% NDIDatasetWizard - Launcher for the Dataset Wizard
    
    arguments
        datasetFolder (1,1) string = missing
    end
    
    app = ndi.dataset.gui.DatasetWizardApp(datasetFolder);

    if nargout < 1
        clear app
    end
end