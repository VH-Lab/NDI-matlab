classdef epoch < handle & matlab.mixin.SetGet
    % EPOCH Class to represent an epoch, with the following properties:
    % 
    % 'epoch_number'            | The number of the epoch. The number may change as epochs are added and subtracted.
    % 'epoch_id'                | The epoch ID code (will never change once established, though it may be deleted.)
    %                           |   This epoch ID uniquely specifies the epoch.
    % 'epoch_session_id'           | The session ID that contains this epoch
    % 'epochprobemap'           | Any contents information for each epoch, usually of type ndi.epoch.epochprobemap or empty.
    % 'epoch_clock'             | A cell array of ndi.time.clocktype objects that describe the type of clocks available
    % 't0_t1'                   | A cell array of ordered pairs [t0 t1] that indicates the start and stop of the epoch for each
    %                           |   respective epoch_clock{}. The time units of t0_t1{i} match epoch_clock{i}.
    % 'object'                  | The ndi.epochset object that has the epoch
    % 'underlying_epochs'       | An array of the ndi.epoch objects that comprise this epochs.

			% note: will need to change underlying_epochs.underlying to underlying_epochs.object in all code

    properties (SetAccess = protected)
        epoch_number (1,1) uint64 {mustBeInteger} = 0;
        epoch_id (1,1) string = "" % Unique identifier for the epoch; could be any string 
        epoch_session_id (1,1) string {did.ido.isvalid(epoch_session_id)} = ndi.ido.unique_id % Identifier for the session containing this epoch
        epochprobemap (:,1) {mustBeA(epochprobemap,'ndi.epoch.epochprobemap')} =  ndi.epoch.epochprobemap
        epoch_clock cell = {} % A cell array of ndi.time.clocktype objects that describe the types of clocks available
        t0_t1 cell = {} % A cell array of ordered pairs [t0 t1] that indicates the start and stop time of the epoch in each clock
        epochset_object (:,1) {mustBeA(object,'ndi.epoch.epochset')} = ndi.epoch.epochset
        underlying_epochs (:,1) {ndi.epoch.mustBeEpochOrEmpty} = [] % An array of the ndi.epoch objects that underlie/comprise this epoch
    end

    methods
         function obj = epoch(varargin)
             % EPOCH - create an ndi.epoch object
             % 
             % OBJ = EPOCH(...)
             %
             % Create an ndi.epoch() object. The properties must be passed as name/value pairs.
             % 
             % 'epoch_number'            | The number of the epoch. The number may change as epochs are added and subtracted.
             % 'epoch_id'                | The epoch ID code (will never change once established, though it may be deleted.)
             %                           |   This epoch ID uniquely specifies the epoch.
             % 'epoch_session_id'        | The session ID that contains this epoch
             % 'epochprobemap'           | Any contents information for each epoch, usually of type ndi.epoch.epochprobemap or empty.
             % 'epoch_clock'             | A cell array of ndi.time.clocktype objects that describe the type of clocks available
             % 't0_t1'                   | A cell array of ordered pairs [t0 t1] that indicates the start and stop of the epoch
             %                           |   for each respective epoch_clock{}. The time units of t0_t1{i} match epoch_clock{i}.
             % 'object'                  | The ndi.epochset object that has the epoch
             % 'underlying_epochs'       | An array of the ndi.epoch objects that comprise this epochs.
                  try
                      for i=1:2:numel(varargin),
                          obj.set(varargin{i},varargin{i+1});
                      end
                  catch
                      error(['Error in creating ndi.epoch object: ' lasterr ]);
                  end

          end % epoch
    end % methods

    methods(Static) 
        function mustBeEpochOrEmpty(value)
            % mustBeEpochOrEmpty - validate that a value is either an ndi.epoch or is empty
            %
            % Syntax:
            %   ndi.epoch.mustBeEpochOrEmpty(value)
            % Inputs: <value>, an input
                assert( isa(value,'ndi.epoch') || isempty(value), 'Value must be an ndi.epoch or be empty.');
        end
    end % Static Methods
end
