classdef (abstract) AvailableClock
    %1 Summary of this class goes here
    % This class will created avaiable clocks for each device. 
    % The property will be the recording times of the device based on
    % various clock types and the field will includes the method how to
    % use the recording time for each clocktype
    
    %   Detailed explanation goes here
    % If the properties for certain clock type does not exist for this
    % specific device, then it will be null or not added.
    
    properties
        local_record;
        interval_relative_record;
        global_record;
    end
    
    methods (abstract)
        getLocal();
       
        getInterval();
        
        getGlobal();
    end
    
     
end

