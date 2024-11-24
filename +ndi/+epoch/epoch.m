classdef epoch < handle & matlab.mixin.SetGet
    % EPOCH Class to represent an epoch with relevant properties and methods
    %
    % Properties:
    %
    % 'epoch_id'                | The epoch ID code (will never change once established, though it may be deleted.)
    %                           |   This epoch ID uniquely specifies the epoch.
    % 'epoch_session_id'        | The session ID that contains this epoch
    % 'epochprobemap'           | Any contents information for each epoch, usually of type ndi.epoch.epochprobemap or empty.
    % 'epoch_clock'             | A cell array of ndi.time.clocktype objects that describe the type of clocks available
    % 't0_t1'                   | A cell array of ordered pairs [t0 t1] that indicates, for each ndi.time.clocktype, the start and stop
    %                           |   time of this epoch. The time units of t0_t1{i} match epoch_clock{i}.
    % 'underlying_epochs'       | A structure array of the ndi.epoch.epochset objects that comprise these epochs.
    %                           |   It contains fields 'underlying', 'epoch_id', 'epochprobemap', and 'epoch_clock'

    properties (SetAccess = private)
        % epoch_id - Unique identifier for the epoch
        epoch_id (1,1) string 
        
        % epoch_session_id - Identifier for the session containing this epoch
        epoch_session_id (1,1) string
    end

    properties
        % epochprobemap - Information about the contents of the epoch, usually 
        % of type ndi.epoch.epochprobemap or empty.
        epochprobemap (1,1) ndi.epoch.epochprobemap         
        
        % epoch_clock - 
        epoch_clock (1,:) ndi.time.clocktype = ndi.time.clocktype('no_time')
        
        % t_start - start time of time interval corresponding to each clockype
        t0_t1 (1,:) cell = {NaN, NAN} % or datetime?
        
        % underlying_epochs - epochsets?
        underlying_epochs      % Structure array of ndi.epoch.epochset objects comprising these epochs
    end
    
    methods
        % Constructor
        function obj = epoch(propValues)

            arguments
                propValues.?ndi.epoch.epoch
                propValues.epoch_id (1,1) string
                propValues.epoch_session_id (1,1) string
            end
            
            obj.set(propValues)
        end
    end
end
