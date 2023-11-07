function res = dataset_metadata(S, new, varargin)
% DATASET_METADATA - opens a MATLAB app for users to enter metadata
% information
%
% RES = ndi.database.fun.dataset_metadata(S, NEW)
%
% Inputs:
%   S - an ndi.session object
%   NEW - create a new metadata form enter 1. Otherwise enter 0.
%   
%


disp("dataset_metadata is being called");

if nargin == 2
    disp("opening app");
    if (new)
        savePath = S.path + "/.ndi/NDIDatasetUpload";
        if ~isfolder(savePath); mkdir(savePath); end
        ido_ = ndi.ido;
        rand_num = ido_.identifier;
        temp_filename = sprintf("metadata_%s.mat", rand_num);
        path = fullfile(savePath, temp_filename);
        a = ndi.database.metadata_app.Apps.DatasetUploadApp(S,path);
    else
        savePath = S.path + "/.ndi/NDIDatasetUpload";
        file_list = dir(fullfile(savePath, 'metadata_*.mat'));
        for i = 1:numel(file_list)
            full_file_path = fullfile(savePath, file_list(i).name);
            a = ndi.database.metadata_app.Apps.DatasetUploadApp(S,full_file_path);
        end
    end
 
else
    vlt.data.assign(varargin{:});
    switch (action)
        case 'load'
            [status] = ndi.database.fun.load_metadata_to_GUI(app, s);
        case 'save'
            save(metadata_file_name, 'data');
        case 'check'
            [submit, errorStep] = ndi.database.fun.check_metadata_inputs(app);
            res.submit = submit;
            res.errorStep = errorStep;
        case 'submit'
            [status, auth_token, organization_id] = ndi.cloud.auth.login(login.email, login.password);
            appUserData = load(path);
            documentList = ndi.database.metadata_app.convertFormDataToDocuments(appUserData, S.identifier);
            
    end
end
end

