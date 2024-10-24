classdef ProgressUpdatedEventData < event.EventData
    properties
        ProgressPercentage % Percentage of progress
        CurrentStep % Current step
        TotalSteps % Total steps
    end

    methods
        function eventData = ProgressUpdatedEventData(progressPercentage, currentStep, totalSteps)
            % Constructor
            eventData.ProgressPercentage = progressPercentage;
            eventData.CurrentStep = currentStep;
            eventData.TotalSteps = totalSteps;
        end
    end
end
