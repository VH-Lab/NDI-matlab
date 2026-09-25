function installRequirements(requirementsFolder, varargin)
% installRequirements - Install matbox requirements, retrying on transient GitHub errors.
%
%   nditools.installRequirements(FOLDER, ...) is a thin wrapper around
%   matbox.installRequirements(FOLDER, ...) that retries with exponential
%   backoff when resolving git dependencies fails with a transient GitHub
%   API error.
%
%   matbox resolves each requirement by calling the GitHub REST API (to read
%   the current commit of the requested branch). In CI this intermittently
%   returns HTTP 429 "Too Many Requests" -- GitHub's *secondary* rate limit,
%   triggered by bursts of requests and not avoided by authentication -- or a
%   network timeout. These clear on their own within a minute or so, so a
%   short retry loop turns a hard CI failure into a brief pause.
%
%   After a successful install it makes sure openMINDS_MATLAB is on the path
%   and calls openminds.startup("latest") so its model classes resolve.
%
%   See also matbox.installRequirements

    maxAttempts = 5;
    baseDelaySeconds = 15; % backoff doubles each retry: 15, 30, 60, 120

    for attempt = 1:maxAttempts
        try
            matbox.installRequirements(requirementsFolder, varargin{:})
            selectOpenMINDSModelVersion()
            return
        catch ME
            if attempt == maxAttempts || ~isTransientGithubError(ME)
                rethrow(ME)
            end
            delaySeconds = baseDelaySeconds * 2^(attempt - 1);
            warning('nditools:installRequirements:retrying', ...
                ['matbox.installRequirements failed (attempt %d of %d): %s\n' ...
                 'Retrying in %d seconds...'], ...
                attempt, maxAttempts, ME.message, delaySeconds);
            pause(delaySeconds)
        end
    end
end

function selectOpenMINDSModelVersion()
% Put the classes of the latest openMINDS model version on the path.
%   Installing the openMINDS_MATLAB FEX package (0.12.0) does not leave the
%   openminds package on the path, so its classes (e.g.
%   openminds.core.research.Strain) do not resolve. If the package is not
%   found, enable the installed add-on or add the folder it was unpacked
%   to, then run openminds.startup, which puts the classes of the selected
%   model version on the path. See VH-Lab/NDI-matlab#1008.
    if ~exist('openminds.startup', 'file')
        addOpenMINDSToPath()
    end
    if exist('openminds.startup', 'file')
        openminds.startup("latest")
    else
        warning('nditools:installRequirements:openMINDSNotFound', ...
            'openMINDS_MATLAB is not on the path after installing requirements.')
    end
end

function addOpenMINDSToPath()
% Enable an installed openMINDS add-on, or add an unpacked copy to the path.
    try
        addons = matlab.addons.installedAddons();
        isOpenMINDS = contains(addons.Name, "openMINDS", 'IgnoreCase', true);
        fprintf('Installed openMINDS add-ons:\n');
        disp(addons(isOpenMINDS, :))
        openMINDSAddons = addons(isOpenMINDS, :);
        for i = 1:height(openMINDSAddons)
            if ~openMINDSAddons.Enabled(i)
                matlab.addons.enableAddon(openMINDSAddons.Identifier(i), ...
                    openMINDSAddons.Version(i));
            end
        end
    catch ME
        fprintf('Could not list or enable add-ons: %s\n', ME.message);
    end
    if exist('openminds.startup', 'file')
        return
    end

    addonFolder = matbox.setup.internal.getDefaultAddonFolder();
    startupFiles = dir(fullfile(addonFolder, '**', '+openminds', 'startup.m'));
    fprintf('openMINDS startup files under %s: %d\n', addonFolder, numel(startupFiles));
    if ~isempty(startupFiles)
        codeFolder = fileparts(startupFiles(1).folder);
        fprintf('Adding %s to the path.\n', codeFolder);
        addpath(codeFolder)
    end
end

function tf = isTransientGithubError(ME)
% Treat GitHub rate-limit (429) and transient network errors as retryable.
    msg = ME.message;
    tf = contains(msg, '429') ...
        || contains(msg, 'Too Many Requests', 'IgnoreCase', true) ...
        || contains(msg, 'rate limit', 'IgnoreCase', true) ...
        || contains(msg, 'timeout', 'IgnoreCase', true) ...
        || contains(msg, 'timed out', 'IgnoreCase', true);
end
