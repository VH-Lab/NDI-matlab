function size = calculate_size_in_cloud(S)
%UPDATE_SIZE_IN_CLOUD - Adds up the size of the files to be uploaded to cloud
%
%   SIZE = ndi.database.fun.CALCULATE_SIZE_IN_CLOUD(S) returns the size of the files to be
%
%   Inputs:
%       S - An ndi session
%
%   Outputs:
%       SIZE - The size of the files to be uploaded to cloud
d = S.database_search(ndi.query('','isa','base'));
size = 0;
for i=1:numel(d)
    document = did.datastructures.jsonencodenan(d{i}.document_properties);
    info = whos('document');
    size  = size + info.bytes;
    ndi_doc_id = d{i}.document_properties.base.id;

    if isfield(d{i}.document_properties, 'files'),
        for f = 1:numel(d{i}.document_properties.files.file_list)
            file_name = d{i}.document_properties.files.file_list{f};
            file_obj = S.database_openbinarydoc(ndi_doc_id, file_name);
            [~,uid,~] = fileparts(file_obj.fullpathfilename);
            size = size + dir(file_obj.fullpathfilename).bytes;
        end
    end
end
size = size / 1024;

