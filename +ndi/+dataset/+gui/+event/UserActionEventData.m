classdef UserActionEventData < event.EventData
    properties
        UserAction
    end
    
    methods
        function obj = UserActionEventData(userAction)
            obj.UserAction = userAction;
        end
    end
end
