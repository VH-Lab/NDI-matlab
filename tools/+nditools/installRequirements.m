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
%   See also matbox.installRequirements

    maxAttempts = 5;
    baseDelaySeconds = 15; % backoff doubles each retry: 15, 30, 60, 120

    for attempt = 1:maxAttempts
        try
            matbox.installRequirements(requirementsFolder, varargin{:})
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

function tf = isTransientGithubError(ME)
% Treat GitHub rate-limit (429) and transient network errors as retryable.
    msg = ME.message;
    tf = contains(msg, '429') ...
        || contains(msg, 'Too Many Requests', 'IgnoreCase', true) ...
        || contains(msg, 'rate limit', 'IgnoreCase', true) ...
        || contains(msg, 'timeout', 'IgnoreCase', true) ...
        || contains(msg, 'timed out', 'IgnoreCase', true);
end
