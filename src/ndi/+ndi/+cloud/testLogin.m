function isGood = testLogin(options)
% TESTLOGIN - Test whether the user has a good NDI Cloud login.
%
%   ISGOOD = ndi.cloud.testLogin()
%
%   Tests the current login by attempting to list datasets. If the first
%   attempt fails, logs out and retries. If the second attempt also fails
%   and UseUILogin is true, logs out and opens the UI login dialog before
%   a final check.
%
%   Optional Inputs (Name-Value Pairs):
%       UseUILogin - If true (default), prompt the user to log in via the
%           UI dialog when the initial attempts fail. If false, skip the
%           UI login step.
%
%   Outputs:
%       isGood - True if the user has a valid login, false otherwise.
%
%   Example:
%       isGood = ndi.cloud.testLogin();
%       isGood = ndi.cloud.testLogin('UseUILogin', false);
%
%   See also: ndi.cloud.logout, ndi.cloud.uilogin, ndi.cloud.api.datasets.listDatasets

    arguments
        options.UseUILogin (1,1) logical = true
    end

    isGood = false;

    [a, ~] = ndi.cloud.api.datasets.listDatasets();

    if a
        isGood = true;
        return;
    end

    % First attempt failed; logout and retry
    ndi.cloud.logout();

    [a, ~] = ndi.cloud.api.datasets.listDatasets();

    if a
        isGood = true;
        return;
    end

    % Second attempt failed; try UI login if allowed
    if options.UseUILogin
        ndi.cloud.logout();
        ndi.cloud.uilogin();

        [a, ~] = ndi.cloud.api.datasets.listDatasets();

        if a
            isGood = true;
        end
    end

end
