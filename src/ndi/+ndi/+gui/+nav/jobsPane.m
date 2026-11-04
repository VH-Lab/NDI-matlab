classdef jobsPane < ndi.gui.nav.pane
%NDI.GUI.NAV.JOBSPANE Collapsible "Jobs" pane: long tasks, paused, resumed, restarted.
%
%   Lists the jobs on this computer (ndi.job.Job.list) with their state
%   and progress, and controls the selected one:
%
%       Pause    - ask it to stop at its next heartbeat (it saves its place)
%       Resume   - run it again from where it stopped
%       Restart  - forget its progress and run it from the beginning
%       Remove   - delete its record from this computer
%
%   Columns: the job's name (the start of it; hover for the rest), its
%   state, how much is done, an estimate of the time left while it runs
%   (from this run's pace so far), and when it last updated.
%
%   A job runs in this MATLAB, so while one runs, MATLAB is busy; the job
%   lets the window redraw at every heartbeat, which is when Pause and the
%   progress column respond. The list is refreshed by the jobs themselves
%   and on every navigator refresh.
%
%   See also: ndi.job.Job, ndi.gui.navigator

    properties (SetAccess = protected)
        Table       % uitable of jobs
        Jobs = {}   % the ndi.job.Job objects shown, in table order
        PauseButton
        ResumeButton
        RestartButton
        RemoveButton
    end

    properties (Constant, Access = private)
        BodyPx = 150
    end

    methods
        function obj = jobsPane(navigator)
            h = ndi.gui.nav.pane.HeaderHeight + ndi.gui.nav.jobsPane.BodyPx;
            % Open only when there is something to show.
            obj@ndi.gui.nav.pane(navigator, ...
                'Title',       'Jobs', ...
                'Collapsible', true, ...
                'Engaged',     ~isempty(ndi.job.Job.list()), ...
                'MinHeight',   h, ...
                'Height',      h);
        end

        function tf = HasBody(~)
            tf = true;
        end

        function refresh(obj)
        % REFRESH - re-read the jobs; open the pane if one has appeared
            if isempty(obj.Table) || ~isvalid(obj.Table)
                return
            end
            selectedId = '';
            r = obj.selectedJob();
            if ~isempty(r), selectedId = r.id; end
            obj.Jobs = ndi.job.Job.list();
            obj.Table.Data = ndi.gui.nav.jobsPane.rowsFor(obj.Jobs);
            k = find(cellfun(@(j) strcmp(j.id, selectedId), obj.Jobs), 1);
            if ~isempty(k)
                obj.Table.Selection = k;
            end
            obj.updateButtons();
            if ~isempty(obj.Jobs) && ~obj.Engaged
                obj.setEngagedQuietly(true);
            end
        end
    end

    methods (Static)
        function rows = rowsFor(jobs)
        % ROWSFOR - the table rows for JOBS: title, state, progress, time
        % left (an estimate, while running) and when it last updated
            rows = cell(numel(jobs), 5);
            for k = 1:numel(jobs)
                j = jobs{k};
                rows(k, :) = {j.title, j.effectiveState(), ...
                    sprintf('%.0f%%', 100 * j.progress), ...
                    ndi.gui.nav.jobsPane.durationText(j.remainingSeconds()), ...
                    ndi.gui.nav.jobsPane.shortTime(j.updated)};
            end
        end

        function t = durationText(s)
        % DURATIONTEXT - seconds as '3h 05m', '12m', '<1m'; '' if NaN
            if isempty(s) || isnan(s)
                t = '';
            elseif s < 60
                t = '<1m';
            elseif s < 3600
                t = sprintf('%dm', round(s / 60));
            elseif s < 86400
                m = round(s / 60);
                t = sprintf('%dh %02dm', floor(m / 60), mod(m, 60));
            else
                h = round(s / 3600);
                t = sprintf('%dd %dh', floor(h / 24), mod(h, 24));
            end
        end

        function t = shortTime(utc)
        % SHORTTIME - a stored UTC time, local: 'HH:mm:ss' today, else 'MMM d HH:mm'
            t = '';
            if isempty(utc), return; end
            d = ndi.job.Job.fromUtc(utc);
            if isnat(d)
                t = char(utc);
                return
            end
            d.TimeZone = 'local';
            if isequal(dateshift(d, 'start', 'day'), ...
                    dateshift(datetime('now', 'TimeZone', 'local'), 'start', 'day'))
                d.Format = 'HH:mm:ss';
            else
                d.Format = 'MMM d HH:mm';
            end
            t = char(d);
        end
    end

    methods (Access = protected)
        function buildBody(obj, container)
            container.RowHeight = {'1x', 26};
            container.ColumnWidth = {'1x'};
            container.Padding = [4 4 4 4];
            obj.Table = uitable(container, ...
                'ColumnName', {'Job', 'State', 'Done', 'Left', 'Updated'}, ...
                'ColumnWidth', {80, 70, 50, 60, 'auto'}, ...
                'RowName', {}, ...
                'SelectionType', 'row', 'Multiselect', 'off', ...
                'SelectionChangedFcn', @(~,~) obj.updateButtons());
            obj.Table.Layout.Row = 1;
            obj.Table.Layout.Column = 1;

            g = uigridlayout(container, [1 4]);
            g.Layout.Row = 2;
            g.Layout.Column = 1;
            g.Padding = [0 0 0 0];
            g.ColumnSpacing = 4;
            g.ColumnWidth = {'1x', '1x', '1x', '1x'};
            obj.PauseButton = uibutton(g, 'Text', 'Pause', ...
                'Tooltip', 'Stop the selected job at its next step; Resume carries on from there', ...
                'ButtonPushedFcn', @(~,~) obj.onPause());
            obj.ResumeButton = uibutton(g, 'Text', 'Resume', ...
                'Tooltip', 'Run the selected job from where it stopped', ...
                'ButtonPushedFcn', @(~,~) obj.onResume());
            obj.RestartButton = uibutton(g, 'Text', 'Restart', ...
                'Tooltip', 'Forget the selected job''s progress and run it from the beginning', ...
                'ButtonPushedFcn', @(~,~) obj.onRestart());
            obj.RemoveButton = uibutton(g, 'Text', 'Remove', ...
                'Tooltip', 'Delete the selected job''s record from this computer', ...
                'ButtonPushedFcn', @(~,~) obj.onRemove());
            for b = {obj.PauseButton, obj.ResumeButton, obj.RestartButton, obj.RemoveButton}
                obj.accentButton(b{1});
            end
            obj.refresh();
        end
    end

    methods (Access = private)
        function j = selectedJob(obj)
            j = [];
            if isempty(obj.Table) || ~isvalid(obj.Table), return; end
            sel = obj.Table.Selection;
            if isempty(sel) || sel(1) > numel(obj.Jobs), return; end
            j = obj.Jobs{sel(1)};
        end

        function updateButtons(obj)
            j = obj.selectedJob();
            st = '';
            if ~isempty(j), st = j.effectiveState(); end
            obj.PauseButton.Enable = onOff(strcmp(st, 'running'));
            obj.ResumeButton.Enable = onOff(~isempty(j) && j.canResume());
            obj.RestartButton.Enable = onOff(~isempty(j) && ~strcmp(st, 'running'));
            obj.RemoveButton.Enable = onOff(~isempty(j) && ~strcmp(st, 'running'));
        end

        function fig = figureOf(obj)
            fig = ancestor(obj.Panel, 'figure');
        end

        function onPause(obj)
            j = obj.selectedJob();
            if isempty(j), return; end
            j.requestPause();
            obj.Table.Data{obj.Table.Selection(1), 2} = 'pausing';
        end

        function onResume(obj)
            j = obj.selectedJob();
            if isempty(j), return; end
            obj.runJob(j);
        end

        function onRestart(obj)
            j = obj.selectedJob();
            if isempty(j), return; end
            ok = uiconfirm(obj.figureOf(), sprintf(['Start "%s" over from the ' ...
                'beginning? What it has done so far is not reused.'], j.title), ...
                'Restart job', 'Options', {'Restart', 'Cancel'}, ...
                'DefaultOption', 2, 'CancelOption', 2);
            if ~strcmp(ok, 'Restart'), return; end
            j.restart();
            obj.runJob(j);
        end

        function onRemove(obj)
            j = obj.selectedJob();
            if isempty(j), return; end
            msg = sprintf('Remove the job "%s" from this computer?', j.title);
            if ~strcmp(j.effectiveState(), 'done')
                msg = sprintf(['%s\n\nIt has not finished, and cannot be resumed ' ...
                    'once removed.'], msg);
            end
            ok = uiconfirm(obj.figureOf(), msg, 'Remove job', ...
                'Options', {'Remove', 'Cancel'}, 'DefaultOption', 2, 'CancelOption', 2);
            if ~strcmp(ok, 'Remove'), return; end
            j.remove();
            obj.refresh();
        end

        function runJob(obj, j)
            try
                j.run();
            catch ME
                uialert(obj.figureOf(), ME.message, 'Could not run the job');
            end
            obj.refresh();
            if strcmp(j.state, 'failed')
                uialert(obj.figureOf(), j.message, sprintf('Job "%s" failed', j.title));
            end
        end
    end
end

function s = onOff(tf)
    if tf, s = 'on'; else, s = 'off'; end
end
