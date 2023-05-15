email = "katherine@walthamdatascience.com";
password = "Ndicloud123~";


%tested successfully 
[authToken, organizationId] = ndi.cloud.auth.login(email, password);
[status, output] = ndi.cloud.auth.logout(authToken);