function d = saveEditor2Doc(D, datasetInfo)
    %SAVEEDITOR2DOC function to save the editor content to NDI document
    %   D = ndi.database.metadata_app.fun.SAVEEDITOR2DOC(D, DATASETINFO)
    %   Inputs:
    %       D - ndi.dataset object
    %       DATASETINFO - struct containing the dataset information
    %
    %   Outputs:
    %       D - ndi.dataset object
    newid = ndi.ido;
    docName = ['metadata_editor'];
    session_id = D.id();

    metadata_editor_docs = D.database_search(ndi.query('','isa','metadata_editor'));
    if numel(metadata_editor_docs) ~= 0
        D.database_rm(metadata_editor_docs);
    end

    document = ndi.database.metadata_ds_core.convertDatasetInfoToDocument(datasetInfo);

    d = ndi.document(docName,'base.id',newid.identifier,...
        'base.session_id',session_id,...
        'metadata_editor.metadata_structure',document);
    D.database_add(d);
end
