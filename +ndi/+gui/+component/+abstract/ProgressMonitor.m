classdef ProgressMonitor < handle

    properties
        Title (1,1) string = "In progress..."
        UpdateInterval = 1          % Interval (in seconds) for updating progress.
        ProgressTracker (1,1) ndi.gui.component.internal.ProgressTracker = missing
        DisplayElapsedTime = false
        DisplayRemainingTime = true
    end

    properties
        RemainingTimeFormat (1,1) string = "hh:mm:ss"
    end

    properties (Access = protected)
        StartTime
        ElapsedTime
        RemainingTime
    end

    properties (Access = private)
        ProgressUpdatedListener event.listener
        MessageUpdatedListener event.listener
        TaskCompletedListener event.listener
        IsInitialized = false
    end

    methods % Constructor
        function obj = ProgressMonitor(propertyValues)
            arguments
                propertyValues.?ndi.gui.component.abstract.ProgressMonitor
            end

            % Set this first...
            if isfield(propertyValues, 'UpdateInterval')
                obj.UpdateInterval = propertyValues.UpdateInterval;
            end

            if isfield(propertyValues, 'ProgressTracker')
                obj.ProgressTracker = propertyValues.ProgressTracker;
            else
                obj.ProgressTracker = missing;
            end

            for propertyName = string(fieldnames(propertyValues)')
                obj.(propertyName) = propertyValues.(propertyName);
            end
        end
    end

    methods
        function set.ProgressTracker(obj, value)
            obj.resetListeners()
            obj.ProgressTracker = value;
            obj.onProgressTrackerSet()
        end
    end

    methods
        function reset(obj)
            obj.resetListeners()
            obj.StartTime = [];
            obj.ElapsedTime = [];
            obj.RemainingTime = [];
            obj.IsInitialized = false;
        end

        function markComplete(obj)
            % Note: Using markComplete method to trigger event to run
            % methods of this class. Todo: Can it be simplified?
            obj.ProgressTracker.markComplete()
        end
    end

    methods (Abstract, Access = protected)
        updateProgressDisplay(obj)

        updateMessage(obj, message)

        finish(obj)
    end

    methods (Access = protected)
        function onProgressUpdated(obj, src, evt)
            if ~obj.IsInitialized
                obj.initialize()
            else
                obj.ElapsedTime = seconds( toc(obj.StartTime) );
                obj.RemainingTime = obj.estimateRemainingTime();
            end

            obj.updateProgressDisplay()
        end

        function onMessageUpdated(obj, src, evt)
            obj.updateMessage(evt.Message)
        end

        function onProgressFinished(obj, src, evt)
            obj.finish()
        end

        function onInitalized(obj)
            % Subclass may implement
        end

        function titleMessage = getProgressTitle(obj)
            titleMessage = obj.Title;
        end

        function progressMessage = getProgressMessage(obj)
            if ~ismissing(obj.ProgressTracker.Message)
                msg = obj.ProgressTracker.Message;
            else
                msg = '';
            end

            if obj.DisplayRemainingTime
                remainingTimeStr = obj.formatRemainingTime();
                msg = sprintf('%s Estimated time remaining: %s', msg, remainingTimeStr);
            end

            progressMessage = msg;
        end

        function progressValue = getProgressValue(obj)
            progressValue = obj.ProgressTracker.FractionComplete;
        end
    end

    methods (Access = private)
        function initialize(obj)
            obj.StartTime = tic;
            obj.IsInitialized = true;
            obj.onInitalized()
        end

        function tRemaining = estimateRemainingTime(obj)
            %estimateRemainingTime Get string with estimated time remaining
            fractionFinished = obj.ProgressTracker.FractionComplete;
            % fprintf('\n Elapsed time: %d, fraction; %.4f\n',seconds(obj.ElapsedTime), fractionFinished)
            tRemaining = round( (obj.ElapsedTime ./ fractionFinished) .* (1-fractionFinished) );
        end

        function onProgressTrackerSet(obj)
            obj.initializeListeners()
            obj.ProgressTracker.UpdateInterval = obj.UpdateInterval;
        end

        function initializeListeners(obj)
            obj.ProgressUpdatedListener = listener(obj.ProgressTracker, ...
                'ProgressUpdated', @obj.onProgressUpdated);

            obj.MessageUpdatedListener = listener(obj.ProgressTracker, ...
                'MessageUpdated', @obj.onMessageUpdated);

            obj.TaskCompletedListener = listener(obj.ProgressTracker, ...
                'TaskCompleted', @obj.onProgressFinished);
        end

        function resetListeners(obj)
            if ~isempty(obj.ProgressUpdatedListener)
                delete(obj.ProgressUpdatedListener)
                delete(obj.MessageUpdatedListener)
                delete(obj.TaskCompletedListener)

                obj.ProgressUpdatedListener = event.listener.empty;
                obj.MessageUpdatedListener = event.listener.empty;
                obj.TaskCompletedListener = event.listener.empty;
            end
        end


        function remainingTimeStr = formatRemainingTime(obj)
            %tRemaining.Format = obj.RemainingTimeFormat;

            if isempty(obj.RemainingTime)
                remainingTimeStr = 'N/A'; return
            end

            if hours(obj.RemainingTime) > 1
                nHours = floor(hours(obj.RemainingTime));
                nMinutes = round( minutes( obj.RemainingTime - hours(nHours)) );
                remainingTimeStr = sprintf("%d hours, %d minutes", nHours, nMinutes);

            elseif minutes(obj.RemainingTime) > 1
                nMinutes = floor( minutes(obj.RemainingTime) );
                nSeconds = round( seconds( obj.RemainingTime - minutes(nMinutes)) );
                remainingTimeStr = sprintf("%d minutes, %d seconds", nMinutes, nSeconds);

            else
                remainingTimeStr = sprintf("%d seconds", seconds(obj.RemainingTime));
            end
        end
    end

end
