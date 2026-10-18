function checkOnStartup()
% CHECKONSTARTUP - check for an NDI-matlab update, at most once per interval
%
%   ndi.update.checkOnStartup()
%
%   Called when NDI-matlab starts (ndi_Init, ndi_toolbox_setup). If the
%   preference Update.CheckOnStartup is true and at least
%   Update.CheckIntervalDays days have passed since the last check, runs
%   ndi.update.check quietly and prints one line if an update is
%   available. It never errors: a failed check (for example, no network) is
%   silently ignored until the next interval.
%
%   The check is skipped when the environment variable CI is set, so
%   automated test runs are not slowed down.
%
%   To turn the check off:
%       ndi.preferences.set('Update.CheckOnStartup', false)
%
%   See also: ndi.update.check, ndi.preferences

    arguments
    end

    try
        if ~isempty(getenv('CI')) || ~ndi.preferences.get('Update.CheckOnStartup')
            return
        end

        lastCheck = ndi.preferences.get('Update.LastCheckTime');
        intervalDays = ndi.preferences.get('Update.CheckIntervalDays');
        fmt = "yyyy-MM-dd'T'HH:mm:ss";
        nowTime = datetime('now', 'Format', fmt);
        if strlength(lastCheck) > 0
            last = datetime(lastCheck, 'InputFormat', fmt);
            if nowTime - last < days(intervalDays)
                return
            end
        end
        % Record the attempt first, so a failing check is not retried at
        % every start.
        ndi.preferences.set('Update.LastCheckTime', string(nowTime));

        r = ndi.update.check(Verbose = false, Timeout = 5);
        if r.UpdateAvailable
            if usejava('desktop')
                cmd = '<a href="matlab:ndi.update.install">ndi.update.install()</a>';
            else
                cmd = 'ndi.update.install()';
            end
            summary = splitlines(r.Message);
            fprintf('%s Run %s to update, or ndi.update.check() for details.\n', ...
                summary(1), cmd);
        end
    catch
        % never let an update check break startup
    end
end
