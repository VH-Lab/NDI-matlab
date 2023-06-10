function [b, msg] = upload_to_NDI_cloud(S, email, password, dataset_id)
% UPLOAD_TO_NDI_CLOUD - upload an NDI database to NDI Cloud
%
% [B,MSG] = ndi.database.fun.upload_to_NDI_cloud(S, EMAIL, PASSWORD)
%
% Inputs:
%   S - an ndi.session object
%   TOKEN - an upload token for NDI Cloud
%
% Outputs:
%   B - did the upload work? 0 for no, 1 for yes
%   MSG - An error message if the upload failed; otherwise ''
%

% Step 1: find all the documents


d = S.database_search(ndi.query('','isa','base'));

% Step 2: make a connection to the NDI Cloud server
% we will learn this from Tonic
% function name
% c = uicontrol('Style','edit');
% c.Callback = @userInput;
%     function userInput(src, event)
%         val = c.Value;
%         disp(['input: ' val]);
%     end
% end
[auth_token, organization_id] = ndi.cloud.auth.login(email, password);
% 
% while true
%     x = input("Do you need to create a new dataset? y/n: ");
%     if x == 'y'
%         dataset_obj = input("Please enter the file path of the dataset information: ");
%         str_dataset = fileread(dataset_obj);
%         dataset_id = ndi.cloud.datasets.post_organization(organization_id, str_dataset, auth_token);
%         break;
%     elseif x == 'n'
%         dataset_id = input("Please enter the dataset id: ");
%         break;
%     end
% end

% Step 3: loop over all the documents, uploading them to NDI Cloud
% q: do we do this all together, or one at a time?
msg = '';
b = 1;
for i=20:numel(d),
    % upload instruction - need to learn
    document = did.datastructures.jsonencodenan(d{i}.document_properties);
    global ndi_globals;
    temp_dir = ndi_globals.path.temppath;
    ido_ = ndi.ido;
    rand_num = ido_.identifier;
    temp_filename = sprintf("file_%s.json", rand_num);
    path = fullfile(temp_dir,temp_filename);
    [status, response] = ndi.cloud.documents.post_documents(path, dataset_id, document, auth_token);
    disp(i)
    if status ~= 0
        b = 0;
        msg = response;
        error(msg);
    end

    ndi_doc_id = d{i}.document_properties.base.id;

    if isfield(d{i}.document_properties, 'files'),
        for f = 1:numel(d{i}.document_properties.files.file_list)
            file_name = d{i}.document_properties.files.file_list{f};
            file_obj = S.database_openbinarydoc(ndi_doc_id, file_name);
            [~,uid,~] = fileparts(file_obj.fullpathfilename);
            [status, response, upload_url] = ndi.cloud.files.get_files(dataset_id, uid, auth_token);
            if status ~= 0
                b = 0;
                msg = response;
                error(msg);
            end
            [status, response] = ndi.cloud.files.put_files(upload_url, file_obj.fullpathfilename, auth_token);
            if status ~= 0
                b = 0;
                msg = response;
                error(msg);
            end
            S.database_closebinarydoc(file_obj);
        end
    end

   
        % use whatever upload command is necessary
        % or, check to see if the file is already there?
end
end

