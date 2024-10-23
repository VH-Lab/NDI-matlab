classdef CommandWindowProgressMonitor < ndi.gui.component.abstract.ProgressMonitor

    properties
        IndentSize = 0              % Size of indentation (number of spaces) if displaying progress in command window.
        ShowTimeStamp = true
        TimeStampFormat = "[yyyy-MM-dd HH:mm:ss]"
        UpdateInplace = true
    end

    properties (Access = private)
        PreviousMessage
    end

    methods
        % function obj = CommandWindowProgressMonitor(options)
        %     % arguments
        %     %     options.?CommandWindowProgressMonitor
        %     % end
        % end
    end

    methods
        function reset(obj)
            reset@ndi.gui.component.abstract.ProgressMonitor(obj)
            obj.PreviousMessage = [];
        end
    end

    methods (Access = protected)

        function updateProgressDisplay(obj)

            if isempty(obj.PreviousMessage)
                obj.printTitleMessage()
            end

            msg = obj.ProgressTracker.Message;
            if ~ismissing(msg)
                obj.updateProgressMessage(msg)
            end
        end

        function updateMessage(obj, message)
            message = obj.formatMessage(message);
            obj.PreviousMessage = '';
            obj.printMessage(message)
        end

        function finish(obj)
            obj.updateProgressDisplay()

            % % fprintf(newline)
            % % fprintf( obj.formatMessage('Completed') )
            % % fprintf(newline)
        end
    end

    methods (Access = private)

        function printTitleMessage(obj)
            % printTitleMessage - Print title / opening message
            message = obj.formatMessage( obj.getProgressTitle() );
            fprintf(message)
        end

        function printMessage(obj, message)

            if ~isempty(obj.PreviousMessage) && obj.UpdateInplace
                % char(8) = backspace
                deletePrevStr = char(8*ones(1, length(obj.PreviousMessage)+1));
            else
                deletePrevStr = '';
            end
            % Print one new line to prevent messy output in case users
            % enter input on the command window.
            fprintf('%s\n%s', deletePrevStr, message);
            obj.PreviousMessage = message;
        end

        function updateProgressMessage(obj, message)
            message = obj.formatMessage(message);

            if obj.RemainingTime < seconds(inf)
                obj.RemainingTime.Format = "hh:mm:ss";
                remainingTimeStr = sprintf('Remaining time: %s', obj.RemainingTime);
                message = sprintf('%s. %s', message, remainingTimeStr);
            end

            obj.printMessage(message)
        end

        function message = formatMessage(obj, coreMessage)
            message = obj.indentMessage( coreMessage );

            if obj.ShowTimeStamp
                message = obj.prependTimestamp(message);
            end
        end

        function indentedMessage = indentMessage(obj, message)
            % indentMessage - Indent a message based on preferences
            indentation = repmat(' ', 1, obj.IndentSize);
            indentedMessage = sprintf('%s%s', indentation, message);
        end

        function message = prependTimestamp(obj, message)
            % prependTimestamp - Prepend timestamp to a message
            timeStampStr = datetime("now", "Format", obj.TimeStampFormat);
            message = sprintf('%s: %s', timeStampStr, message);
        end
    end
end