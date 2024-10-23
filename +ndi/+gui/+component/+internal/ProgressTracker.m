classdef ProgressTracker < handle & matlab.mixin.CustomCompactDisplayProvider
    % ProgressTracker - Represent and track progress for a task
    %
    % This class provides properties and methods for representing the progress
    % of a task.

    % Todo:
    %   [ ] Flexibility of formatting when inserting property values in a
    %       string template

    properties (Dependent, SetAccess=private)
        PercentageComplete
        Message
    end

    properties (Hidden) % Preferences / Settings
        % UpdateInterval - Interval in seconds to trigger ProgressUpdated
        % event. Useful in cases where the CurrentStep is updated rapidly
        % but an event update is not needed at the same rate.
        UpdateInterval (1,1) = seconds(0) % In seconds

        % TemplateMessage - A template message that can representing the
        % progress of a task. Template variables are represented in the
        % form {{CurrentStep}} and the following variables are supported:
        % CurrentStep, TotalSteps, PercentageComplete
        TemplateMessage (1,1) string = missing

        CompletedMessage (1,1) string = missing

        % DumpFilePath - Path name for a file to dump the progress related
        % properties of an object
        DumpFilePath (1,1) string = missing
    end

    properties (Hidden, Dependent, SetAccess=private)
        FractionComplete
    end

    properties (SetAccess=protected)
        CurrentStep % Current step
        TotalSteps  % Total number of steps in the task
    end

    properties (Access=protected)
        LastUpdate (1,1) uint64 = 0
        TemplateMessageProperties (1,:) string
        IsFinished = false
    end

    properties (Access = private)
        AsynchListener timer
        AsynchFileCleanup
    end

    properties (Constant, Access = private)
        AllowedTemplateProperties = ["CurrentStep", "TotalSteps", "PercentageComplete"]
    end

    events
        ProgressUpdated
        MessageUpdated
        TaskCompleted
    end

    methods % Constructor
        function obj = ProgressTracker(totalSteps)
            % ProgressTracker - Construct a task progress object

            arguments
                totalSteps (1,1) double = nan
            end

            obj.TotalSteps = totalSteps;
            obj.CurrentStep = 0;
        end

        function delete(obj)
        end
    end

    methods % Set/get methods
        function percentageComplete = get.PercentageComplete(obj)
            percentageComplete = double(round((obj.CurrentStep / obj.TotalSteps) * 100));
        end

        function fractionComplete = get.FractionComplete(obj)
            fractionComplete = (obj.CurrentStep / obj.TotalSteps);
        end

        function message = get.Message(obj)
            message = string(missing);
            if ismissing(obj.TemplateMessage); return; end
            if isnan(obj.TotalSteps); return; end
            if obj.IsFinished && ~ismissing(obj.CompletedMessage)
                message = obj.CompletedMessage;
            else
                message = obj.fillTemplateMessage();
            end
        end

        function set.TemplateMessage(obj, templateMessage)
            obj.TemplateMessage = templateMessage;
            obj.onTemplateMessageSet()
        end

        function set.UpdateInterval(obj, newValue)
            if isnumeric(newValue)
                newValue = seconds(newValue);
            elseif isduration(newValue)
                % pass
            else
                error('Error setting property ''UpdateInterval'' of class ''%s''. Value must be a number or a duration value but was a %s', mfilename('class'), class(newValue))
            end
            obj.UpdateInterval = newValue;

            % Todo: Update asynch listener (timer)
        end
    end

    methods
        function setTotalSteps(obj, newValue)

            % Only allow setting value if TotalSteps is 0. Once TotalSteps
            % is initialized with a value, it should not be settable. The
            % method "reset" can be used if the TotalSteps need to be
            % reinitialized.
            if ~isnan(obj.TotalSteps)
                error(...
                    ['Can not set ''TotalSteps'' of class ''%s'' ', ...
                    'because it has already been initialized. Use ', ...
                    'the ''reset'' method if you need to reinitialize ', ...
                    '''TotalSteps'''], mfilename('class'))
            end
            obj.TotalSteps = newValue;
        end

        function updateProgress(obj, currentStep)
            % Update progress by incrementing the current step

            % Todo: set.CurrentStep instead
            arguments
                obj (1,1) ndi.gui.component.internal.ProgressTracker
                currentStep (1,1) double = nan
            end

            if obj.IsFinished; return; end

            % Update current step
            if isnan(currentStep)
                obj.CurrentStep = obj.CurrentStep + 1;
            else
                obj.CurrentStep = currentStep;
            end

            if obj.CurrentStep >= obj.TotalSteps
                eventData = ndi.gui.component.internal.event.ProgressUpdatedEventData(...
                    obj.PercentageComplete, obj.CurrentStep, obj.TotalSteps);
                obj.notify('TaskCompleted', eventData);
                obj.IsFinished = true;
                return
            end

            if seconds(toc(obj.LastUpdate)) > obj.UpdateInterval
                % Trigger event
                eventData = ndi.gui.component.internal.event.ProgressUpdatedEventData(...
                    obj.PercentageComplete, obj.CurrentStep, obj.TotalSteps);

                obj.notify('ProgressUpdated', eventData);
                obj.LastUpdate = tic();
            end
        end

        function updateMessage(obj, newMessage)
            eventData = ndi.gui.component.internal.event.MessageUpdatedEventData(newMessage);
            obj.notify('MessageUpdated', eventData);
        end

        function setCompleted(obj, message)
            obj.updateProgress(obj.TotalSteps)
            if nargin > 1
                obj.updateMessage(message)
            end
        end

        function resetProgress(obj)
            % Reset progress to start
            obj.CurrentStep = 0;
        end

        function reset(obj)
            obj.CurrentStep = 0;
            obj.TotalSteps = nan;

            if isprop(obj, 'AsynchFileCleanup')
                if ~isempty(obj.AsynchFileCleanup)
                    delete(obj.AsynchFileCleanup)
                    obj.AsynchFileCleanup = [];
                end
            end
            if isprop(obj, 'AsynchListener')
                if ~isempty(obj.AsynchListener)
                    if isvalid(obj.AsynchListener)
                        stop(obj.AsynchListener)
                        delete(obj.AsynchListener)
                    end
                    obj.AsynchListener = timer.empty;
                end
            end
        end

        function isComplete = isComplete(obj)
            % Check if task is complete
            isComplete = (obj.CurrentStep >= obj.TotalSteps);
        end
    end

    methods
        function asynchProgressTracker = getAsynchTaskProgress(obj)

            % Get a temporary file
            obj.DumpFilePath = sprintf('%s_task_progress.json', tempname);

            % Create a file cleanup object
            obj.AsynchFileCleanup = onCleanup(@(fp) ...
                ndi.gui.component.internal.ProgressTracker.deleteDumpFile(obj.DumpFilePath));

            % Create an asynch task object
            asynchProgressTracker = ndi.gui.component.internal.AsynchProgressTracker();
            if ~isnan(obj.TotalSteps)
                asynchProgressTracker.setTotalSteps(obj.TotalSteps)
            end
            asynchProgressTracker.CurrentStep = obj.CurrentStep;
            asynchProgressTracker.TemplateMessage = obj.TemplateMessage;
            asynchProgressTracker.DumpFilePath = obj.DumpFilePath;
            obj.initializeAsynchListener()
        end
    end

    methods (Hidden)
        function rep = compactRepresentationForSingleLine(obj,displayConfiguration,width)
            % Fit as many array elements in the available space as possible
            if isnan(obj.TotalSteps)
                rep = matlab.display.PlainTextRepresentation(obj, '<unavailable>', displayConfiguration);
            else
                rep = compactRepresentationForSingleLine@matlab.mixin.CustomCompactDisplayProvider(obj,displayConfiguration,width);
            end
        end
    end

    methods (Access = protected)
        function onTemplateMessageSet(obj)

            expression = '{{(.*?)}}';
            matchedTokens = regexp(obj.TemplateMessage, expression, 'tokens');
            matchedTokens = string(matchedTokens);

            assert(all(ismember(matchedTokens, obj.AllowedTemplateProperties)), ...
                "Template message variables must be members of the class' template properties:\n%s", ...
                strjoin("   " + obj.AllowedTemplateProperties, newline))

            obj.TemplateMessageProperties = matchedTokens;
        end

        function updatedMessage = fillTemplateMessage(obj)

            updatedMessage = obj.TemplateMessage;

            for propName = obj.TemplateMessageProperties
                propValue = obj.(propName);
                updatedMessage = obj.replacePropertyValue(...
                    updatedMessage, propName, propValue);
            end
        end

    end

    methods (Access = private)

        function initializeAsynchListener(obj)
            obj.AsynchListener = timer(...
                'Name', 'TaskProgressListener', ...
                'ExecutionMode', 'fixedRate', ...
                'Period', max( [seconds(obj.UpdateInterval), 1]) );

            obj.AsynchListener.TimerFcn = @(myTimerObj, thisEvent) obj.readFromFile();
            start(obj.AsynchListener)
        end

        function readFromFile(obj)
            if isfile( obj.DumpFilePath )
                try
                    S = jsondecode(fileread(obj.DumpFilePath));
                catch ME
                    % Might attempt to read file while its being written to.
                    return
                end
                if ~isempty(S.TemplateMessage)
                    if ~strcmp(obj.TemplateMessage, S.TemplateMessage)
                        obj.TemplateMessage = S.TemplateMessage;
                    end
                end

                if obj.TotalSteps ~= S.TotalSteps
                    obj.TotalSteps = S.TotalSteps;
                end

                obj.updateProgress(S.CurrentStep)
            end
        end
    end

    methods (Static, Access = protected)
        function updatedMessage = replacePropertyValue(templateMessage, propertyName, propertyValue)
            % Replace a class property value in a template message

            % Format placeholder string
            placeholder = sprintf('{{%s}}', propertyName);

            % Replace placeholder with property value in the template message
            if round(propertyValue) == propertyValue
                valueAsStr = num2str(propertyValue);
            else
                valueAsStr = num2str(propertyValue, '%.2f');
            end

            updatedMessage = strrep(templateMessage, placeholder, valueAsStr);
        end

        function deleteDumpFile(filePath)
            if isfile(filePath)
                delete(filePath)
            end
        end
    end
end
