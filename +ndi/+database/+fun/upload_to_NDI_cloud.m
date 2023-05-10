function [b, msg] = upload_to_NDI_cloud(S, email, password, database_name)
% UPLOAD_TO_NDI_CLOUD - upload an NDI database to NDI Cloud
%
% [B,MSG] = ndi.database.fun.upload_to_NDI_cloud(S, TOKEN)
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

[authToken, organizationId] = ndi.database.fun.Login(email, password);
databaseId = create_database(organizationId, database_name, authToken);


  % Step 3: loop over all the documents, uploading them to NDI Cloud
 % q: do we do this all together, or one at a time?
 % here is all together

if 0,
    all_json = {};
    for i=1:numel(d),
        all_json{i} = did.datastructures.jsonencodenan(d{i}.document_properties);
    end;
end;

 % or one at a time?
for i=1:numel(d),
   % upload instruction - need to learn
   json_code = did.datastructures.jsonencodenan(d{i}.document_properties);

   file_list_here = [];
   if isfield(d{i}.document_properties.files),
       file_list_here = d{i}.document_properties.files.file_list;
   end;

   for f=1:numel(file_list),
        myfile = S.database_openbinarydoc(d{i},file_list_here{f});
        myfilename = myfile.fullpathfilename;
        cmd = sprintf(['curl -X POST ' ...
            '-H "accept: application/json" ' ...
            '-H "Authorization: Bearer %s" ' ...
            '-d ''%s'' https://rsmz66zk54.execute-api.us-east-1.amazonaws.com/v1/datasets/%s/documents'], ...
            authToken, myfile, databaseId);
        [status, output] = system(cmd);
        S.database_closebinarydoc(myfile);
        % use whatever upload command is necessary
        % or, check to see if the file is already there?
   end;

end;
end;

