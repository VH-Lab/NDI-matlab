function [token, organization_id] = uilogin()

    token = getenv('NDI_CLOUD_TOKEN');
    organization_id = getenv('NDI_CLOUD_ORGANIZATION_ID');
    
    if isempty(token) || isempty(organization_id)
        hApp = ndi.database.app.uilogin.Login();
        hApp.waitfor()
        token = getenv('NDI_CLOUD_TOKEN');
        organization_id = getenv('NDI_CLOUD_ORGANIZATION_ID');
    end
end