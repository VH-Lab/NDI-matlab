function author = load_author_from_ndidocument(author_doc, otherContribution_docs, custodian_docs, D)
    %UNTITLED Summary of this function goes here
    %   AUTHOR = ndi.database.metadata_ds_core.LOAD_AUTHOR_FROM_NDIDOCUMENT(AUTHOR_DOCS, OTHERCONTRIBUTION_DOCS, CUSTODIAN_DOCS, D)

    author = struct();

    if ~iscell(author_doc)
        author_doc = {author_doc};
    end
    if ~iscell(otherContribution_docs)
        otherContribution_docs = {otherContribution_docs};
    end
    if ~iscell(custodian_docs)
        custodian_docs = {custodian_docs};
    end

    type_ids = cellfun(@(x) x{1}.document_properties.openminds.fields.type{1}(7:end), otherContribution_docs, 'UniformOutput', false);
    type_doc = cellfun(@(x) D.database_search(ndi.query('base.id', 'exact_string', x)), type_ids, 'UniformOutput', false);
    author_openminds_ids = cellfun(@(x) x{1}.document_properties.openminds.openminds_id, author_doc, 'UniformOutput', false);
    author_ids = cellfun(@(x) x{1}.document_properties.base.id, author_doc, 'UniformOutput', false);
    custodian_openminds_ids = cellfun(@(x) x{1}.document_properties.openminds.openminds_id, custodian_docs, 'UniformOutput', false);
    if ~iscell(custodian_openminds_ids)
        custodian_openminds_ids = {custodian_openminds_ids};
    end
    check_if_in_custodian = @(id) any(strcmp(id, custodian_openminds_ids));
    custodian_indices = cellfun(check_if_in_custodian, author_openminds_ids);

    for i = 1:numel(author_doc)
        author(i).familyName = author_doc{i}{1}.document_properties.openminds.fields.familyName;
        author(i).givenName = author_doc{i}{1}.document_properties.openminds.fields.givenName;
        aff_doc = D.database_search(ndi.query('base.id', 'exact_string', author_doc{i}{1}.document_properties.openminds.fields.affiliation{1}(7:end)));
        org_doc = D.database_search(ndi.query('base.id', 'exact_string', aff_doc{1}.document_properties.openminds.fields.memberOf{1}(7:end)));
        author(i).affiliation.memberOf.fullName = org_doc{1}.document_properties.openminds.fields.fullName;
        identifier_doc = D.database_search(ndi.query('base.id', 'exact_string',author_doc{i}{1}.document_properties.openminds.fields.digitalIdentifier{1,1}(7:end)));
        author(i).digitalIdentifier.identifier = identifier_doc{1}.document_properties.openminds.fields.identifier;
        author(i).digitalIdentifier.identifier = author(i).digitalIdentifier.identifier(19:end);
        email_doc = D.database_search(ndi.query('base.id', 'exact_string',author_doc{i}{1}.document_properties.openminds.fields.contactInformation{1,1}(7:end)));
        author(i).contactInformation.email = email_doc{1}.document_properties.openminds.fields.email;
        author_role = {};
        if custodian_indices(i)
            author_role{end+1} = 'Custodian';
        end
        % if any(cellfun(@(x) x == i, {custodian_indices}, 'UniformOutput', false))
        %     author_role{end+1} = 'custodian';
        % end
        author(i).authorRole = author_role;
        author(i).id = author_doc{i}{1}.document_properties.base.id;
    end


    for i = 1:numel(otherContribution_docs)
        otherContribution_docs_p_id = otherContribution_docs{i}{1}.document_properties.openminds.fields.contributor{1};
        for j = 1:numel(author)
            if contains(otherContribution_docs_p_id, author(j).id)
                if strcmp(type_doc{i}{1}.document_properties.openminds.fields.name, 'point of contact')
                    author(j).authorRole{end+1} = 'Corresponding';
                else
                    author(j).authorRole{end+1} = type_doc{i}{1}.document_properties.openminds.fields.name;
                end
            end
        end
    end

    %remove the author.id field
    author = rmfield(author, 'id');

end

