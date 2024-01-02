function token = uilogin()

    token = getenv('NDI_CLOUD_TOKEN');
    
    if isempty(token)
        hApp = ndi.database.app.uilogin.Login();
        hApp.waitfor()
        token = getenv('NDI_CLOUD_TOKEN');
    end
end