email = "katherine@walthamdatascience.com";
password = "Ndicloud123~";
confirmation_code = "176741";
%% auth
% tested successfully
[status, auth_token, organization_id] = ndi.cloud.api.auth.login(email, password);
[status, output] = ndi.cloud.api.auth.logout();
[status,response] = ndi.cloud.auth.confirmation_resend(email);
[status,response] = ndi.cloud.auth.password_forgot(email);
[status,response] = ndi.cloud.auth.password(oldPassword, newPassword);

% unsucessful
[status,response] = ndi.cloud.auth.verify(email, confirmation_code);
% {
%   "errors": "Unable to authorize user",
%   "code": "CodeMismatchException"
% }

% waited to be tested

%% datasets
prefix = [userpath filesep 'Documents' filesep 'NDI'];
foldername = "/Users/cxy/Documents/NDI/2023-03-08/";
filename = "/Users/cxy/Documents/NDI/2023-03-08/t*";
ls([foldername filesep 't*'])

S = ndi.session.dir("2023-03-08",[foldername]);

type (fullfile(filename,'t00001','stims.tsv'))
