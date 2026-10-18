function organizationID = testOrganizationID()
% TESTORGANIZATIONID - The NDI Cloud organization cloud tests create datasets in.
%
%   ORGANIZATIONID = ndi.unittest.cloud.testOrganizationID()
%
%   Returns the id of the first organization the test account belongs to
%   that allows dataset upload (any of its organizations, if the account is
%   an NDI Cloud administrator, as the server allows). Test accounts may belong to several
%   organizations, and tests run without a desktop cannot answer the
%   organization picker, so tests pass this id to
%   ndi.cloud.api.datasets.createDataset explicitly.
%
%   See also: ndi.cloud.internal.getOrganizations,
%             ndi.cloud.internal.chooseOrganization

    organizations = ndi.cloud.internal.getOrganizations();
    uploadable = organizations;
    if ~ndi.cloud.internal.userIsAdmin()
        uploadable = organizations([organizations.canUploadDataset]);
    end
    if isempty(uploadable)
        error('NDI:Cloud:NoUploadableOrganization', ...
            'The NDI Cloud test account does not belong to any organization that allows dataset upload.');
    end
    organizationID = uploadable(1).id;
end
