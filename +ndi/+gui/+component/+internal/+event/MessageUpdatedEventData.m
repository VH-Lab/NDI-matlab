classdef MessageUpdatedEventData < event.EventData
    properties
        Message % Message to display
    end
    
    methods
        function eventData = MessageUpdatedEventData(message)
            % Constructor
            eventData.Message = message;
        end
    end
end