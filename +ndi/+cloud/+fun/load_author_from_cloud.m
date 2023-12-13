function author = load_author_from_cloud(author_doc,all_docs)
%UNTITLED Summary of this function goes here
%   AUTHOR = ndi.cloud.fun.LOAD_AUTHOR_FROM_CLOUD(AUTHOR_DOCS,ALL_DOCS)

%%TODO: custodian seems to be missing from the author docs
author = struct();
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
    author(i).authorRole = {};
    author(i).additional = '';
end
end

