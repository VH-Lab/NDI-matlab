function [b, msg] = upload_to_NDI_cloud(S, token)
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


  % Step 3: loop over all the documents, uploading them to NDI Cloud

for i=1:numel(d),
   % upload instruction - need to learn

   file_list_here = [];
   if isfield(d{i}.document_properties.files),
       file_list_here = d{i}.document_properties.files.file_list;
   end;

   for f=1:numel(file_list),
        myfile = S.database_openbinarydoc(d{i},file_list_here{f});
        myfilename = myfile.fullpathfilename;
        S.database_closebinarydoc(myfile);
        % use whatever upload command is necessary
        % or, check to see if the file is already there?
   end;

end;
end;

