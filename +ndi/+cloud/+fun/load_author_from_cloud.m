function author = load_author_from_cloud(author_doc, otherContribution_docs, custodian_docs, all_docs)
%UNTITLED Summary of this function goes here
%   AUTHOR = ndi.cloud.fun.LOAD_AUTHOR_FROM_CLOUD(AUTHOR_DOCS, OTHERCONTRIBUTION_DOCS, CUSTODIAN_DOCS, ALL_DOCS)

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
type_ids = cellfun(@(x) x.document_properties.openminds.fields.type{1}, otherContribution_docs, 'UniformOutput', false);
type_doc = cellfun(@(x) ndi.cloud.fun.search_id(x, all_docs), type_ids);
if ~iscell(type_doc)
    type_doc = {type_doc};
end

author_openminds_ids = cellfun(@(x) x.document_properties.openminds.openminds_id, author_doc, 'UniformOutput', false);
author_ids = cellfun(@(x) x.document_properties.base.id, author_doc, 'UniformOutput', false);

custodian_openminds_ids = cellfun(@(x) x.document_properties.openminds.openminds_id, custodian_docs, 'UniformOutput', false);
if ~iscell(custodian_openminds_ids)
    custodian_openminds_ids = {custodian_openminds_ids};
end

check_if_in_custodian = @(id) any(strcmp(id, custodian_openminds_ids));
custodian_indices = cellfun(check_if_in_custodian, author_openminds_ids);

for i = 1:numel(author_doc)
    author(i).familyName = author_doc{1, i}.document_properties.openminds.fields.familyName;
    author(i).givenName = author_doc{1, i}.document_properties.openminds.fields.givenName;
    aff_doc = ndi.cloud.fun.search_id(author_doc{1, i}.document_properties.openminds.fields.affiliation{1}, all_docs);
    org_doc = ndi.cloud.fun.search_id(aff_doc.document_properties.openminds.fields.memberOf{1}, all_docs);
    author(i).affiliation.memberOf.fullName = org_doc.document_properties.openminds.fields.fullName;
    identifier_doc = ndi.cloud.fun.search_id(author_doc{1, i}.document_properties.openminds.fields.digitalIdentifier{1,1}, all_docs);
    author(i).digitalIdentifier.identifier = identifier_doc.document_properties.openminds.fields.identifier;
    author(i).digitalIdentifier.identifier = author(i).digitalIdentifier.identifier(19:end);
    email_doc = ndi.cloud.fun.search_id(author_doc{1, i}.document_properties.openminds.fields.contactInformation{1,1}, all_docs);
    author(i).contactInformation.email = email_doc.document_properties.openminds.fields.email;
    author_role = {};
    for j = 1:numel(custodian_indices)
        if custodian_indices(j) == i
            author_role{end+1} = 'custodian';
        end
    end
    % if any(cellfun(@(x) x == i, {custodian_indices}, 'UniformOutput', false))
    %     author_role{end+1} = 'custodian';
    % end
    author(i).authorRole = author_role;
    author(i).id = author_doc{1, i}.document_properties.base.id;
end


for i = 1:numel(otherContribution_docs)
    otherContribution_docs_p_id = otherContribution_docs{1, i}.document_properties.openminds.fields.contributor{1};
    for j = 1:numel(author)
        if contains(otherContribution_docs_p_id, author(j).id)
            if strcmp(type_doc{1, i}.document_properties.openminds.fields.name, 'point of contact')
                author(j).authorRole{end+1} = 'Corresponding';
            end
            author(j).authorRole{end+1} = type_doc{1, i}.document_properties.openminds.fields.name;
        end
    end
end

%remove the author.id field
author = rmfield(author, 'id');

end

