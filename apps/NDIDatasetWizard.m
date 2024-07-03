function app = NDIDatasetWizard()
% NDIDatasetWizard - Launcher for the Dataset Wizard
    app = ndi.dataset.gui.DatasetWizardApp();

    if nargout < 1
        clear app
    end
end