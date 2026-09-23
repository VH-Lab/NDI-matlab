classdef ProgressBarWindow < matlab.apps.AppBase
    %ProgressBarWindow Creates and manages a progress bar figure.
    %
    %   This class provides a graphical user interface (GUI) to display
    %   one or more progress bars in a single figure. It allows for adding,
    %   updating, and removing progress bars dynamically. Each bar displays
    %   progress as a percentage, a visual bar, an estimated time remaining,
    %   and provides a button to close it. The window can be configured to 
    %   automatically close bars upon completion or timeout.
    %
    %   Usage Example 1:
    %       app = ndi.gui.component.ProgressBarWindow('Import Dataset'); % Create a window
    %       app.addBar('Label','Create Session(s)','Tag','session'); % Add a bar
    %       app.updateBar('session',0.5); % Update the bar's progress
    %
    %   Usage Example 2 (auto close, uuid):
    %       app = ndi.gui.component.ProgressBarWindow(); % Create a window
    %       uuid = did.ido.unique_id();
    %       app.addBar('Label','Save document(s)','Tag',uuid,'Auto',true); % Add a bar
    %       app.updateBar(uuid,0.5) % Update the bar's progress
    %
    %   Silent (headless) mode:
    %       Creating a uifigure spawns a MATLABWindow (CEF) process. In a
    %       headless context (a `-batch` job, CI, a cluster run) that launch
    %       can fail, and the failure is a silent timeout rather than an
    %       error, so the calling job simply stalls. To avoid depending on a
    %       GUI launch that batch runs have no business needing, the class
    %       runs in a silent mode whenever it detects a headless context:
    %       no uifigure is created and every graphics touchpoint no-ops,
    %       while all of the bookkeeping (the ProgressBars struct, addBar,
    %       updateBar, removeBar, timeout tracking, getBarNum, getState)
    %       behaves exactly as it does with a window. Callers change
    %       nothing; they simply get no window.
    %
    %       The decision is made once per construction by resolveSilentMode,
    %       in this order:
    %           1. the 'Silent' name-value argument, when given;
    %           2. the process-wide default set with silentModeDefault;
    %           3. automatic detection by isHeadless.
    %       Levels 1 and 2 exist so a headless context can be forced (or
    %       refused) without a display, which is also what makes the mode
    %       testable in either direction.
    %
    %   See also: uifigure, uigridlayout, uiaxes, patch, uilabel, uibutton,
    %       ndi.gui.component.ProgressBarWindow.isHeadless,
    %       ndi.gui.component.ProgressBarWindow.silentModeDefault

    properties (Hidden)
        ScreenFrac double = 0.025 % Fraction of screen height used per bar row.
        IconClose char = fullfile(ndi.common.PathConstants.RootFolder,...
            '+ndi','+gui','close_icon.svg') % Path to the close icon. Update if needed
        ProgressFigureListener % Listens for changes to the figure.
        ProgressGridListener % Listens for changes to the grid layout.
        ProgressBarListener % Listens for changes to the progress bar data.
        Timeout duration = minutes(1) % Time after last update before a bar times out.
        AutoDelete logical = true % Flag to automatically delete the ProgressBarWindow if all bars are closed.
        IsDocked logical = false % True when the bars are hosted inside an open navigator's progress pane instead of a standalone window.
        HostPane = [] % Handle to the ndi.gui.nav.progressPane hosting the bars when IsDocked is true.
        WindowTitle char = '' % Title requested for this window, recorded in every mode (there is no figure to read it back from when silent).
    end

    properties (SetAccess=immutable)
        Silent (1,1) logical = false % True when running headless: no figure is created and all graphics touchpoints no-op.
    end

    properties (SetObservable)
        ProgressFigure matlab.ui.Figure  % Handle to the main GUI figure.
        ProgressGrid matlab.ui.container.GridLayout % Handle to the grid managing the layout.
        ProgressBars struct % Array storing data and handles for each progress bar.
    end

    properties (SetAccess=immutable, GetAccess=private)
        Visible (1,1) matlab.lang.OnOffSwitchState = "on"
    end

    methods
        function app = ProgressBarWindow(title,options)
            %ProgressBarWindow Constructor for the progress bar window.
            %
            %   APP = PROGRESSBARWINDOW(TITLE, OPTIONS) creates a new 
            %   progress bar window or returns a handle to an existing one.
            %
            %   Inputs:
            %       title - The title to display on the figure window.
            %                   Defaults to ''.
            %
            %   Optional Name-Value Arguments:
            %       Overwrite - If true, closes any existing progress bar window
            %                   with the same title. If false, returns the handle
            %                   to the existing window. Defaults to false.
            %       GrabMostRecent - If true, will search open figures for the
            %                   most recently created progress bar window. Uses
            %                   this handle if no figure with matching title is
            %                   found or IgnoreTitle is true. Defaults to true.
            %       IgnoreTitle - If true, will return the most recently created
            %                   progress bar window regardless of its title.
            %                   Defaults to false.
            %       AutoDelete - If true, automatically closes the progress bar
            %                   figure and deletes the app handle when there are
            %                   no more progress bars remaining in the window.
            %                   Defaults to true.
            %       Silent - Forces silent (headless) mode on or off for this
            %                   window, bypassing detection. Defaults to []
            %                   (empty), meaning "decide automatically" - see
            %                   resolveSilentMode. In silent mode no uifigure
            %                   is created and the bars exist as bookkeeping
            %                   only.
            %
            %   Outputs:
            %       app - The handle to the created or existing app instance.

            % Input argument validation
            arguments
                title (1,:) char = ''
                options.Overwrite logical = false
                options.GrabMostRecent logical = true
                options.IgnoreTitle logical = false
                options.AutoDelete logical = true
                options.Visible (1,1) matlab.lang.OnOffSwitchState = "on"
                options.Dock logical = true
                options.Silent {mustBeScalarOrEmpty, mustBeNumericOrLogical} = []
            end

            % --- Decide whether to run headless ---------------------------
            %   Made once, here, and stored on the object, so that every
            %   method below asks the object rather than re-detecting. That
            %   is also the injection point the tests use to exercise both
            %   paths without needing (or avoiding) a display.
            silent = ndi.gui.component.ProgressBarWindow.resolveSilentMode(options.Silent);
            app.Silent = silent;

            % --- Dock into an open navigator, if there is one -------------
            %   When a navigator is open its progress pane hosts the bars
            %   (this takes priority over a standalone window). Only when no
            %   navigator is open do we fall through to the standalone
            %   window path below. Callers do not change: the same
            %   constructor they already use routes automatically.
            %   Docking is a graphics path, so it is skipped when headless.
            if options.Dock && ~silent
                dockedApp = app.tryDock(options);
                if ~isempty(dockedApp)
                    app = dockedApp;
                    return
                end
            end


            % Find existing figure with that tag. In silent mode no figure
            % is ever created, so there is nothing to find or reuse and each
            % construction yields its own bookkeeping-only instance.
            if silent
                openFigs = gobjects(0);
            else
                openFigs = findall(groot,'Type','figure','tag','progressbar');
            end
            if ~isempty(openFigs)

                % Check for figure with same title
                ind = strcmpi({openFigs.Name},title);

                % If no title (or ignoring it), try most recent figure 
                if options.GrabMostRecent && (~any(ind) || options.IgnoreTitle)
                    for i = numel(openFigs):-1:1
                        if isa(guidata(openFigs(i)), 'ndi.gui.component.ProgressBarWindow')
                            ind(i) = true;
                            continue
                        end
                    end
                end

                if any(ind)
                    % If overwriting, close matching progress bar
                    if options.Overwrite
                        disp(['Closing existing progress bar window: ', title]);
                        delete(openFigs(ind))

                    % If not overwriting, use guidata from current figure
                    else
                        disp(['Using existing progress bar window: ', title]);
                        appExisting = guidata(openFigs(ind));

                        % Check guidata is a ProgressBarWindow
                        if isa(appExisting, 'ndi.gui.component.ProgressBarWindow')
                            app = appExisting;
                            app.bringToFront()
                            return
                        else
                             warning('ProgressBarWindow:ExistingFigureNotApp', 'Existing figure with title "%s" is not a ProgressBarWindow instance. Creating new.', title);
                             delete(openFigs(ind)); % Delete non-app figure to avoid conflict
                        end
                    end
                end
            end

            % Set visible state from input
            app.Visible = options.Visible;

            % Add auto-delete tag
            app.AutoDelete = options.AutoDelete;

            % Add listeners. Not installed when silent: ProgressFigure and
            % ProgressGrid are never set so those two could not fire anyway,
            % and handleAppChange has nothing to save or redraw, so listening
            % on ProgressBars would only cost a drawnow per bookkeeping
            % update in a batch job.
            if ~silent
                app.ProgressFigureListener = addlistener(app,'ProgressFigure','PostSet',@app.handleAppChange);
                app.ProgressGridListener = addlistener(app,'ProgressGrid','PostSet',@app.handleAppChange);
                app.ProgressBarListener = addlistener(app,'ProgressBars','PostSet',@app.handleAppChange);
            end

            % Initialize progress bar figure and grid. Skipped when silent:
            % this uifigure call is the GUI launch that headless runs must
            % not depend on. Leaving ProgressFigure and ProgressGrid unset
            % is what every graphics touchpoint below tolerates.
            if ~silent
                app.ProgressFigure = uifigure(...
                    'Units', 'normalized',...
                    'NumberTitle', 'off',...
                    'Resize', 'off',...
                    'MenuBar', 'none',...
                    'Tag', 'progressbar', ...
                    'Visible', app.Visible);

                % Initialze progress bar grid
                app.ProgressGrid = uigridlayout(app.ProgressFigure,...
                    'ColumnWidth',{'17.5x','1.5x','1x'},'RowHeight',{},...
                    'RowSpacing',0);
            end

            % Set title and size
            app = app.setFigureTitle(title);
            app = app.setFigureSize(1);
            
            % Initialize progress bar struct
            app.ProgressBars = struct('Tag',{},'Progress',{},'State',{},...
                'Auto',{},'Axes',{},'Patch',{},'Percent',{},'Button',{},...
                'Label',{},'Clock',{},'Timer',{});

        end % PROGRESSBARWINDOW

        function app = addBar(app,options)
            %addBar Adds a new progress bar to the window.
            %
            %   APP = ADDBAR(APP, OPTIONS) adds a new row to the progress
            %   bar window with a new progress bar.
            %
            %   Inputs:
            %       app - The app instance.
            %
            %   Optional Name-Value Arguments:
            %       Label - Text label displayed above the bar. Defaults to ''.
            %       Tag - A unique identifier for this bar. Defaults to the Label if empty.
            %       Color - RGB color for the progress bar. Defaults to a random color.
            %       Auto - If true, automatically removes the bar when complete or timed out.
            %              Defaults to false.
            %
            %   Outputs:
            %       app - The updated app instance.

            % Input argument validation
            arguments
                app
                options.Label {mustBeTextScalar(options.Label)} = ''
                options.Tag {mustBeTextScalar(options.Tag)} = ''
                options.Color (1,3) double {mustBeInRange(options.Color,0,1)} = [1 1 1]
                options.Auto logical = false
            end

            % Bring figure to front
            app.bringToFront()

            % Set tag (if empty)
            if isempty(options.Tag)
                options.Tag = options.Label;
            end

            % Check if tag already exists (if it does, set progress to 0)
            barNum = app.getBarNum(options.Tag);
            if ~isempty(barNum)
                
                % If the existing bar was closed, delete existing        
                if strcmpi(app.ProgressBars(barNum).State,'Closed')
                    app.ProgressBars(barNum) = [];
                else
                    warning('ProgressBarWindow:DuplicateTag',...
                        'BarID "%s" already used. Resetting progress bar.',options.Tag)
                    app.updateBar(options.Tag,0);
                    app.ProgressBars(barNum).Clock(1:2) = {datetime('now')};
                    return
                end
            end

            % Generate color if default (white)
            if all(options.Color == 1)
                while (sum(options.Color) < 1.5) || (sum(options.Color) > 2.8)
                    options.Color = rand(1, 3);
                end
            end

            % Get new barNum (index)
            barNum = numel(app.ProgressBars) + 1;

            % Get state, tag, and auto flag
            app.ProgressBars(barNum).State = 'Open';
            app.ProgressBars(barNum).Tag = options.Tag;
            app.ProgressBars(barNum).Auto = options.Auto;
            app.ProgressBars(barNum).Progress = 0;
            app.ProgressBars(barNum).Clock(1:2) = {datetime('now')};

            % Everything from here on builds this bar's graphics. When
            % silent there is no grid and no figure, so the bar exists as
            % bookkeeping only and its Label/Timer/Axes/Patch/Percent/Button
            % fields stay empty (which the other methods tolerate).
            if app.Silent
                return
            end

            % Add rows to ProgressGrid (one for label/timer, one for bar)
            if isempty(options.Label)
                app.ProgressGrid.RowHeight{end+1} = '0.25x'; % Small gap
                app.ProgressGrid.RowHeight{end+1} = '1x';    % Bar row
            else
                app.ProgressGrid.RowHeight{end+1} = '0.75x'; % Label row
                app.ProgressGrid.RowHeight{end+1} = '1x';    % Bar row
            end
            rowNum = numel(app.ProgressGrid.RowHeight); % Row for the bar

            % Adjust figure size based on total row height
            rowHeight = cellfun(@(rh) str2double(replace(rh,'x','')),...
                app.ProgressGrid.RowHeight);
            app = app.setFigureSize(sum(rowHeight));

            % Add label (above the bar)
            app.ProgressBars(barNum).Label = uilabel(app.ProgressGrid,...
                'Text',options.Label,'FontSize',12,...
                'VerticalAlignment','bottom','HorizontalAlignment','left');
            app.ProgressBars(barNum).Label.Layout.Row = rowNum - 1;
            app.ProgressBars(barNum).Label.Layout.Column = 1;

            % Add countdown timer (above the bar, right-aligned)
            app.ProgressBars(barNum).Timer = uilabel(app.ProgressGrid,...
                'Text','Estimated time: calculating',...
                'FontSize',12,'FontColor',0.7*ones(1,3),...
                'VerticalAlignment','bottom','HorizontalAlignment','right');
            app.ProgressBars(barNum).Timer.Layout.Row = rowNum - 1;
            app.ProgressBars(barNum).Timer.Layout.Column = 1:2;

            % Add bar axes (background)
            app.ProgressBars(barNum).Axes = uiaxes(app.ProgressGrid,...
                'XLim',[0 1],'YLim',[0 1],'XTick',[],'YTick',[],'Box','off',...
                'XColor','none','YColor','none','Color','w','Interactions',[]);
            app.ProgressBars(barNum).Axes.Toolbar.Visible = 'off';
            app.ProgressBars(barNum).Axes.Layout.Row = rowNum;
            app.ProgressBars(barNum).Axes.Layout.Column = 1;

            % Add bar patch (foreground)
            app.ProgressBars(barNum).Patch = patch(app.ProgressBars(barNum).Axes, ...
                [0;0;0;0], [0;0;1;1], options.Color,'EdgeColor','none');

            % Add progress percentage text
            app.ProgressBars(barNum).Percent = uilabel(app.ProgressGrid,...
                'Text','0%','FontSize',10);
            app.ProgressBars(barNum).Percent.Layout.Row = rowNum;
            app.ProgressBars(barNum).Percent.Layout.Column = 2;
            
            % Add close button
            app.ProgressBars(barNum).Button = uibutton(app.ProgressGrid,...
                'Icon',app.IconClose,'IconAlignment','center','text','');
            app.ProgressBars(barNum).Button.Layout.Row = rowNum;
            app.ProgressBars(barNum).Button.Layout.Column = 3;
            app.ProgressBars(barNum).Button.Tag = options.Tag;
            app.ProgressBars(barNum).Button.ButtonPushedFcn = @app.handleButtonPress;

        end % ADDBAR

        function app = updateBar(app,barID,progress)
            %updateBar Updates the progress of a specific bar.
            %
            %   APP = UPDATEBAR(APP, BARID, PROGRESS) updates the visual
            %   state and percentage text of the specified progress bar.
            %
            %   Inputs:
            %       app - The app instance.
            %       barID - The index or Tag of the bar to update.
            %       progress - The new progress value, between 0 and 1.
            %
            %   Outputs:
            %       app - The updated app instance.

            % Input argument validation
            arguments
                app
                barID {mustBeA(barID,{'numeric','char','str'})}
                progress (1,1) {mustBeInRange(progress,0,1)}
            end

            % Get bar number
            [barNum,status] = app.getBarNum(barID);

            % if bar already gone
            if isempty(barNum)
                warning("ProgressBarWindow:NoBarsExist", "Could not find barID " + barID)
                return;
            end

            % If bar does not yet exist, throw warning
            if ~isempty(status.identifier)
                warning(status.identifier,status.message)
                if isempty(barNum)
                    return
                end
            end

            % Catch errors occuring if bar was concurrently deleted via button press
            try
                % Update progress value
                app.ProgressBars(barNum).Progress = progress;

                % Set progress bar width
                app.setGraphics(app.ProgressBars(barNum).Patch,...
                    'XData',[0;progress;progress;0]);

                % Set percent label
                app.setGraphics(app.ProgressBars(barNum).Percent,...
                    'Text',sprintf('%.0f%%', progress * 100));

                % Add current time
                app.ProgressBars(barNum).Clock{2} = datetime('now');

                % Update timer (if not yet complete)
                if progress > 0 && progress < 1
                    timeElapsed = app.ProgressBars(barNum).Clock{2} - ...
                        app.ProgressBars(barNum).Clock{1};
                    timeRemaining = timeElapsed * (1 - progress) / progress;
                    if timeRemaining <= minutes(1)
                        timeString = sprintf('%.0f seconds',seconds(timeRemaining));
                    elseif timeRemaining <= hours(2)
                        timeString = sprintf('%.0f minutes',minutes(timeRemaining));
                    elseif timeRemaining > hours(2)
                        timeString = sprintf('%.0f hours',hours(timeRemaining));
                    end
                    app.setGraphics(app.ProgressBars(barNum).Timer,...
                        'Text',['Estimated time: ',timeString]);
                    app.setGraphics(app.ProgressBars(barNum).Button,'Icon',app.IconClose);
                end

                % Check for bars that timed out or completed
                app.checkTimeout;
                app.checkComplete;

                % Auto close if complete or timeout
                for i = 1:numel(app.ProgressBars)
                    if (strcmpi(app.ProgressBars(i).State,'Timeout') | ...
                            strcmpi(app.ProgressBars(i).State,'Complete')) & ...
                            app.ProgressBars(i).Auto
                        app = app.removeBar(i);
                    end
                end

            % Handle error occuring if removeBar is triggered while updateBar is still running
            catch ME
                if strcmp(ME.identifier,'MATLAB:class:InvalidHandle')
                    warning('Execution of task %s terminated by user.',...
                        app.ProgressBars(barNum).Tag)
                else
                    rethrow(ME)
                end
            end

        end % UPDATEBAR

        function app = removeBar(app,barID)
            %removeBar Removes a specific progress bar from the window.
            %
            %   APP = REMOVEBAR(APP, BARID) removes the specified bar,
            %   deletes its GUI components, updates the layout, and throws
            %   an error if the task was not complete.
            %
            %   Inputs:
            %       app - The app instance.
            %       barID - The index or Tag of the bar to remove.
            %
            %   Outputs:
            %       app - The updated app instance.

            % Input argument validation
            arguments
                app
                barID {mustBeA(barID,{'numeric','char','str'})}
            end

            % Get bar number
            [barNum,status] = app.getBarNum(barID);
            if ~isempty(status.identifier)
                warning(status.identifier, status.message);
                return
            end

            % Check for state at time of removal
            state = app.ProgressBars(barNum).State;

            % Set state to closed
            app.ProgressBars(barNum).State = 'Closed';

            % Tear down this bar's graphics and re-flow the remaining ones.
            % Skipped when silent: there are no components to delete and no
            % grid to re-flow, only the bookkeeping above and the state
            % reporting below.
            if ~app.Silent

                % Get tag and ProgressGrid row numbers
                rowNum = app.ProgressBars(barNum).Label.Layout.Row + [0 1];

                % Remove progress bar
                delete([app.ProgressBars(barNum).Axes,...
                    app.ProgressBars(barNum).Percent,...
                    app.ProgressBars(barNum).Button,...
                    app.ProgressBars(barNum).Label,...
                    app.ProgressBars(barNum).Timer]);

                % Adjust position of other bars
                openBars = find(~strcmpi({app.ProgressBars.State},'Closed'));
                for i = 1:numel(openBars)
                    app.ProgressBars(openBars(i)).Label.Layout.Row = 2*i - 1;
                    app.ProgressBars(openBars(i)).Timer.Layout.Row = 2*i - 1;
                    app.ProgressBars(openBars(i)).Axes.Layout.Row = 2*i;
                    app.ProgressBars(openBars(i)).Percent.Layout.Row = 2*i;
                    app.ProgressBars(openBars(i)).Button.Layout.Row = 2*i;
                end

                % Adjust figure size
                app.ProgressGrid.RowHeight(rowNum) = [];
                rowHeight = cellfun(@(rh) str2double(replace(rh,'x','')),...
                    app.ProgressGrid.RowHeight);
                app = app.setFigureSize(sum(rowHeight));
            end

            % Throw error/warning if terminated in the middle of task
            if app.ProgressBars(barNum).Progress < 1
                if strcmpi(state,'Button')
                    error('ProgressBarWindow:UserTermination',...
                        'Execution of task %s terminated by user.',...
                        app.ProgressBars(barNum).Tag)
                elseif strcmpi(state,'Timeout')
                    warning('ProgressBarWindow:AutoCloseOnTimeout',...
                        'Task %s has been inactive for %.f minutes.',...
                        app.ProgressBars(barNum).Tag,...
                        minutes(datetime('now') - app.ProgressBars(barNum).Clock{2}))
                elseif strcmpi(state,'Open')
                    warning('ProgressBarWindow:BarRemoved',...
                        'BarID %s no longer exists.',...
                        app.ProgressBars(barNum).Tag)
                end
            end

            % Check for auto delete
            if app.AutoDelete
                app.deleteIfNoOpenBars;
            end

        end % REMOVEBAR

        function app = setFigureSize(app,totalRowHeight)
            %setFigureSize Adjusts the figure height based on bar content.
            %
            %   APP = SETFIGURESIZE(APP, TOTALROWHEIGHT) calculates and sets
            %   the figure's position and size.
            %
            %   Inputs:
            %       app - The app instance.
            %       totalRowHeight - The sum of the 'x' values from the 
            %                        grid's RowHeight property.
            %
            %   Outputs:
            %       app - The updated app instance.

            % Input argument validation
            arguments
                app
                totalRowHeight (1,1) {mustBeNumeric}
            end

            % Nothing to resize when running headless: there is no figure
            % and no grid.
            if app.Silent
                return
            end

            % When docked, grow the host pane instead of a figure.
            if app.IsDocked
                if ~isempty(app.HostPane) && isvalid(app.HostPane)
                    app.HostPane.fitToBars(totalRowHeight);
                end
                return
            end

            % Define figure size
            vpad = sum(app.ProgressGrid.Padding([2,4]));
            height = app.ScreenFrac * (totalRowHeight * 25 + vpad)/25;
            width = app.ScreenFrac * 13;
            left = app.ProgressFigure.Position(1);
            hdiff = height - app.ProgressFigure.Position(4);
            bottom = app.ProgressFigure.Position(2) - hdiff;

            % Update figure size
            app.ProgressFigure.Position = [left bottom width height];

        end % SETFIGURESIZE

        function app = setFigureTitle(app,titleName)
            %setFigureTitle Sets the title of the progress bar window.
            %
            %   APP = SETFIGURETITLE(APP, TITLENAME) updates the Name
            %   property of the figure.
            %
            %   Inputs:
            %       app - The app instance.
            %       titleName - The new title.
            %
            %   Outputs:
            %       app - The updated app instance.

            % Input argument validation
            arguments
                app
                titleName (1,:) {mustBeTextScalar}
            end

            % Record the requested title in every mode, so that it stays
            % available when there is no figure to read it back from.
            app.WindowTitle = char(titleName);

            % When silent there is no window at all, and when docked there
            % is no window title (the pane keeps its own 'Progress' header),
            % so in both cases this is a no-op.
            if app.Silent || app.IsDocked
                return
            end

            % Assign figure title
            app.ProgressFigure.Name = titleName;

        end % SETFIGURETITLE

        function barNum = checkTimeout(app)
            %checkTimeout Checks for and flags bars that have timed out.
            %
            %   BARNUM = CHECKTIMEOUT(APP) finds bars that haven't updated
            %   within the 'Timeout' duration and sets their state and
            %   button icon accordingly.
            %
            %   Inputs:
            %       app - The app instance.
            %
            %   Outputs:
            %       barNum - Indices of bars that have timed out.

            % Initialize
            barNum = [];

            for i = 1:numel(app.ProgressBars)
                % Get duration of time since last update
                timeout = datetime('now') - app.ProgressBars(i).Clock{2};

                if timeout >= app.Timeout & ...
                        ~strcmpi(app.ProgressBars(i).State,'Closed') && ...
                        ~strcmpi(app.ProgressBars(i).State,'Complete') && ...
                        app.ProgressBars(i).Progress < 1
                    
                    % Set icon to error and state to 'Timeout'
                    app.setErrorIconForButton(app.ProgressBars(i).Button)
                    app.ProgressBars(i).State = 'Timeout';
                    barNum(end+1) = i;
                end
            end

        end % CHECKTIMEOUT

        function barNum = checkComplete(app)
            %checkComplete Checks for and flags bars that have reached 100%.
            %
            %   BARNUM = CHECKCOMPLETE(APP) finds bars with Progress == 1
            %   and sets their state, timer text, and button icon.
            %
            %   Inputs:
            %       app - The app instance.
            %
            %   Outputs:
            %       barNum - Indices of complete bars.

            % Initialize
            barNum = [];

            % Check for non-closed progress bars that are complete
            for i = 1:numel(app.ProgressBars)
                if ~strcmpi(app.ProgressBars(i).State,'Closed') && ...
                        app.ProgressBars(i).Progress >= 1
                    
                    % Set icon to success and state to 'Complete'
                    app.setGraphics(app.ProgressBars(i).Timer,'Text','Complete');
                    app.setSuccessIconForButton(app.ProgressBars(i).Button)
                    app.ProgressBars(i).State = 'Complete';
                    barNum(end+1) = i;
                end
            end

        end % CHECKCOMPLETE

        function [barNum,status] = getBarNum(app,barID)
            %getBarNum Finds the index of a bar given its ID (index or Tag).
            %
            %   [BARNUM, STATUS] = GETBARNUM(APP, BARID) searches for a 
            %   progress bar.
            %
            %   Inputs:
            %       app - The app instance.
            %       barID - The index or Tag.
            %
            %   Outputs:
            %       barNum - The index of the found bar. Empty if not found.
            %       status - Contains identifier and message fields.
            %                         Empty if bar found and valid.

            % Input argument validation
            arguments
                app
                barID {mustBeA(barID,{'numeric','char','str'})}
            end

            % Initialize
            barNum = [];
            status = struct('identifier', '', 'message', '');
            try           
                % Handle empty progress bars
                if isempty(app.ProgressBars)
                    status.identifier = 'ProgressBarWindow:NoBarsExist';
                    status.message = 'No progress bars have been added yet.';
                    return;
                end
            catch
                return
            end

            if isnumeric(barID) % barID is a numeric index
                if barID > 0 && barID <= numel(app.ProgressBars)
                    barNum = barID;
                else
                    status.identifier = 'ProgressBarWindow:InvalidBarIndex';
                    status.message = sprintf('Numeric BarID %d is out of bounds (1-%d).', barID, numel(app.ProgressBars));
                end
            else % barID is a char or string tag
                tags = {app.ProgressBars.Tag};
                barNum = find(strcmpi(tags,barID));
                if isempty(barNum)
                    status.identifier = 'ProgressBarWindow:InvalidBarTag';
                    status.message = sprintf('BarID Tag "%s" not found.', string(barID));
                elseif numel(barNum) > 1
                    status.identifier = 'ProgressBarWindow:DuplicateBarID';
                    status.message = sprintf('BarID Tag "%s" matches multiple bars.', string(barID));
                    error(status.identifier,status.message);
                end
            end

        end % GETBARNUM

        function state = getState(app,barID)
            %getState Returns the state of a specific bar.
            %
            %   STATE = GETSTATE(APP, BARID) retrieves the 'State' field
            %   for the specified bar.
            %
            %   Inputs:
            %       app - The app instance.
            %       barID - The index or Tag.
            %
            %   Outputs:
            %       state - The current state ('Open', 'Complete',
            %                     'Timeout', 'Closed') or empty if not found.

            % Input argument validation
            arguments
                app
                barID {mustBeA(barID,{'numeric','char','str'})}
            end

            % Get bar index
            [barNum,status] = getBarNum(app,barID);

            % Retrieve state
            if ~isempty(status.identifier)
                warning(status.identifier, status.message);
                state = '';
            else
                state = app.ProgressBars(barNum).State;
            end

        end % GETSTATUS

        function app = setTimeout(app, newTimeout)
            %setTimeout Sets the timeout duration.
            %
            %   APP = SETTIMEMOUT(APP,NEWTIMEOUT) updates the timeout time.
            %
            %   Inputs:
            %       app - The app instance.
            %       newTimeout - The timeout time.
            %
            %   Outputs:
            %       app - The updated app instance.

            % Input argument validation
            arguments
                app
                newTimeout (1,1) duration
            end

            app.Timeout = newTimeout;
        end % SETTIMEOUT

        function handleButtonPress(app,source,~)
            %handleButtonPress Callback for the close button on each bar.
            %
            %   Inputs:
            %       app - The app instance.
            %       source - The handle to the button that was pressed.

            % Input argument validation
            arguments
                app
                source (1,1) matlab.ui.control.Button
                ~ % event data, unused
            end

            % Set state as Button
            barNum = app.getBarNum(source.Tag);
            app.ProgressBars(barNum).State = 'Button';

            % Remove progress bar
            app.removeBar(source.Tag);

        end % HANDLEBUTTONPRESS

        function handleAppChange(app,~,~)
            %handleAppChange Listener callback for property changes.
            %   Ensures guidata is saved and the figure is redrawn.

            % When silent there is no figure to store guidata in and
            % nothing on screen to redraw. The listeners are not installed
            % in that mode, so this is belt and braces.
            if app.Silent
                return
            end

            % When docked there is no owning figure; the pane holds the
            % reference to this app, so just redraw.
            if app.IsDocked
                drawnow
                return
            end

            % Save guidata to figure
            guidata(app.ProgressFigure,app);

            % Update figure
            drawnow

        end % HANDLEAPPCHANGE

        function deleteIfNoOpenBars(app)
            %deleteIfNoOpenBars - delete the app if there are no open bars
            %   Deletes (closes the window) if all bars are 'Closed'

            doDelete = false;
            if numel(app.ProgressBars) == 0
                doDelete = true;
            elseif all(strcmpi({app.ProgressBars.State},'Closed'))
                doDelete = true;
            end

            if doDelete
                if app.Silent
                    % No figure to close; just drop the app.
                    delete(app);
                elseif app.IsDocked
                    % Never delete the navigator; just return the pane to
                    % its idle state and drop this app.
                    if ~isempty(app.HostPane) && isvalid(app.HostPane)
                        app.HostPane.releaseBars();
                    end
                    delete(app);
                else
                    close(app.ProgressFigure);
                    delete(app);
                end
            end
        end
    end

    methods (Access = private)
        function setGraphics(app, handleValue, varargin)
            %setGraphics Apply set() to a bar component, if there is one.
            %
            %   SETGRAPHICS(APP, HANDLEVALUE, ...) forwards to SET when this
            %   window has graphics, and does nothing when it is silent or
            %   the component was never created. Deleted (but non-empty)
            %   handles are deliberately still passed to SET so that callers
            %   relying on the MATLAB:class:InvalidHandle error - updateBar
            %   uses it to detect a bar closed concurrently by its button -
            %   keep seeing it.

            if app.Silent || isempty(handleValue)
                return
            end
            set(handleValue, varargin{:});
        end

        function dockedApp = tryDock(app, options)
            %tryDock Attempt to host the bars in an open navigator's pane.
            %
            %   DOCKEDAPP = TRYDOCK(APP, OPTIONS) returns the app that should
            %   be used when a navigator is open (either APP configured to
            %   render into the navigator's progress pane, or the pane's
            %   already-active docked app when one exists and Overwrite is
            %   false). It returns an empty ProgressBarWindow when no
            %   navigator is open, signalling the caller to fall back to a
            %   standalone window.

            dockedApp = ndi.gui.component.ProgressBarWindow.empty;

            % Any failure here must fall back to a standalone window rather
            % than break the caller, so the whole detection is guarded.
            try
                % Is a navigator open? (Most recent wins if several.)
                nav = ndi.gui.navigator.findOpen();
                if isempty(nav)
                    return
                end
                pane = nav(end).progressPaneHandle();
                if isempty(pane) || ~isvalid(pane)
                    return
                end

                % Reuse the pane's active docked app so that nested/cascading
                % tasks share one pane, unless the caller asked to overwrite.
                existing = pane.ActiveApp;
                haveExisting = ~isempty(existing) && isvalid(existing);
                if haveExisting && ~options.Overwrite
                    dockedApp = existing;
                    dockedApp.bringToFront();
                    return
                end
                if haveExisting && options.Overwrite
                    existing.forceReleaseDocked();
                end

                % Configure THIS app to render into the pane.
                app.IsDocked   = true;
                app.HostPane   = pane;
                app.AutoDelete = options.AutoDelete;

                app.ProgressFigureListener = addlistener(app,'ProgressFigure','PostSet',@app.handleAppChange);
                app.ProgressGridListener   = addlistener(app,'ProgressGrid','PostSet',@app.handleAppChange);
                app.ProgressBarListener    = addlistener(app,'ProgressBars','PostSet',@app.handleAppChange);

                % Adopt the pane's grid as our ProgressGrid; the bar-management
                % code (addBar/updateBar/removeBar) is otherwise unchanged.
                app.ProgressGrid = pane.adoptBarGrid();

                app.ProgressBars = struct('Tag',{},'Progress',{},'State',{},...
                    'Auto',{},'Axes',{},'Patch',{},'Percent',{},'Button',{},...
                    'Label',{},'Clock',{},'Timer',{});

                pane.registerApp(app);
                pane.setEngagedQuietly(true);

                dockedApp = app;
            catch
                % Detection/setup failed: undo any partial docked state and
                % signal the caller to build a standalone window instead.
                app.IsDocked = false;
                app.HostPane = [];
                dockedApp = ndi.gui.component.ProgressBarWindow.empty;
            end
        end

        function forceReleaseDocked(app)
            %forceReleaseDocked Clear the host pane and delete this app.
            %   Used when Overwrite replaces an existing docked app.
            if ~isempty(app.HostPane) && isvalid(app.HostPane)
                app.HostPane.releaseBars();
            end
            delete(app);
        end

        function bringToFront(app)
            if app.Silent
                return
            end
            if app.IsDocked
                if ~isempty(app.HostPane) && isvalid(app.HostPane)
                    app.HostPane.setEngagedQuietly(true);
                end
                return
            end
            if app.Visible
                try
                    figure(app.ProgressFigure);
                catch ME
                    if strcmp(ME.identifier, 'MATLAB:UndefinedFunction') && ...
                            startsWith(ME.message, "Undefined function 'bringToFront'")
                        % Ignore. This error occurs on virtual runners (i.e github actions runner)
                    else
                        rethrow(ME)
                    end
                end
            end
        end
    end

    methods (Static)
        function tf = isHeadless()
            %isHeadless True when this MATLAB has no usable display.
            %
            %   TF = ISHEADLESS() reports whether the current process is
            %   running in a context where creating a uifigure is unwise.
            %   Two signals are used:
            %
            %       * batchStartupOptionUsed - documented, and true when
            %         MATLAB was started with -batch, which is exactly how
            %         matlab-actions/run-command and most scripted or
            %         cluster jobs invoke it.
            %       * an empty DISPLAY on Linux - a second signal, for
            %         non-batch headless sessions.
            %
            %   Outputs:
            %       tf - Scalar logical.
            %
            %   See also: ndi.gui.component.ProgressBarWindow.resolveSilentMode

            % Guarded: batchStartupOptionUsed exists from R2019a onwards.
            try
                tf = logical(batchStartupOptionUsed);
            catch
                tf = false;
            end

            if ~tf && isunix() && ~ismac()
                tf = isempty(getenv('DISPLAY'));
            end
        end % ISHEADLESS

        function value = silentModeDefault(newValue)
            %silentModeDefault Get or set the process-wide silent-mode default.
            %
            %   VALUE = SILENTMODEDEFAULT() returns the current override:
            %   [] when there is none (detection decides), or a scalar
            %   logical that every subsequent construction will use unless
            %   the constructor is given an explicit 'Silent' argument.
            %
            %   VALUE = SILENTMODEDEFAULT(NEWVALUE) sets the override. Pass
            %   [] to clear it and return to automatic detection.
            %
            %   This exists so that silent mode can be forced on outside a
            %   detected headless context and - just as importantly - forced
            %   off, which is how the graphics tests keep exercising the
            %   windowed path while themselves running under -batch.
            %
            %   Example:
            %       import ndi.gui.component.ProgressBarWindow
            %       previous = ProgressBarWindow.silentModeDefault();
            %       c = onCleanup(@() ProgressBarWindow.silentModeDefault(previous));
            %       ProgressBarWindow.silentModeDefault(true);

            arguments
                newValue {mustBeScalarOrEmpty, mustBeNumericOrLogical} = []
            end

            persistent override

            if nargin > 0
                if isempty(newValue)
                    override = [];
                else
                    override = logical(newValue);
                end
            end

            value = override;
        end % SILENTMODEDEFAULT

        function tf = resolveSilentMode(explicitValue)
            %resolveSilentMode Decide whether a new window should be silent.
            %
            %   TF = RESOLVESILENTMODE(EXPLICITVALUE) applies, in order:
            %       1. EXPLICITVALUE, when it is not empty (this is the
            %          constructor's 'Silent' name-value argument);
            %       2. the process-wide default from silentModeDefault, when
            %          one has been set;
            %       3. automatic detection by isHeadless.
            %
            %   Inputs:
            %       explicitValue - [] to defer, or a scalar logical.
            %
            %   Outputs:
            %       tf - Scalar logical.

            arguments
                explicitValue {mustBeScalarOrEmpty, mustBeNumericOrLogical} = []
            end

            if ~isempty(explicitValue)
                tf = logical(explicitValue);
                return
            end

            override = ndi.gui.component.ProgressBarWindow.silentModeDefault();
            if ~isempty(override)
                tf = logical(override);
                return
            end

            tf = ndi.gui.component.ProgressBarWindow.isHeadless();
        end % RESOLVESILENTMODE
    end

    methods (Static, Access = private)
        function setErrorIconForButton(buttonHandle)
            if isempty(buttonHandle) % silent mode: no button was created
                return
            end
            if exist('isMATLABReleaseOlderThan', 'file') && ~isMATLABReleaseOlderThan('R2022b')
                set(buttonHandle,'Icon','error');
            else
                % Todo: need to add custom icon
            end
        end

        function setSuccessIconForButton(buttonHandle)
            if isempty(buttonHandle) % silent mode: no button was created
                return
            end
            if exist('isMATLABReleaseOlderThan', 'file') && ~isMATLABReleaseOlderThan('R2022b')
                set(buttonHandle,'Icon','success');
            else
                % Todo: need to add custom icon
            end
        end
    end
end
