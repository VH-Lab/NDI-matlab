function documentStructsOut = dropDuplicateDocsFromStruct(documentStructsIn)
% DROPDUPLICATEDOCSFROMSTRUCT - examine a document struct for duplicates
%
% DOCSTRUCTOUT = ndi.cloud.internal.dropDuplicateDocsFromStruct(DOCSTRUCTIN);
% 
% Given a DOCSTRUCTIN that is computed internally from 
%   ndi.cloud.download.downloadDocumentCollection, remove duplicates
%
%

arguments
    documentStructsIn struct
end

ids = cell(numel(documentStructsIn),1);

for i=1:numel(documentStructsIn)
    ids{i} = documentStructsIn(i).base.id;
end

[~,indexes] = unique(ids);

documentStructsOut = documentStructsIn(indexes);

