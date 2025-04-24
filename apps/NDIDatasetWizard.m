function app = NDIDatasetWizard(datasetFolder)
% NDIDatasetWizard - Launcher for the Dataset Wizard
%
%   Syntax:
%       app = NDIDatasetWizard(datasetFolder) Launches the Dataset Wizard
%
% Input Arguments:
%   datasetFolder (string) - Optional
%     The root folder of the dataset to be used in the wizard.

    arguments
        datasetFolder (1,1) string = missing
    end
    
    app = ndi.dataset.gui.DatasetWizardApp(datasetFolder);

    if nargout < 1
        clear app
    end
end
