classdef epoch < handle & matlab.mixin.SetGet
    % EPOCH Class to represent an epoch, with the following properties:
    % 
    % 'epoch_number'            | The number of the epoch. The number may change as epochs are added and subtracted.
    %                           |   0 has a special meaning. It means that the epoch_number is unknown.
    % 'epoch_id'                | The epoch ID code (will never change once established, though it may be deleted.)
    %                           |   This epoch ID uniquely specifies the epoch.
    % 'epoch_session_id'        | The session ID that contains this epoch
    % 'epochprobemap'           | Any contents information for each epoch, usually of type ndi.epoch.epochprobemap or empty.
    % 'epoch_clock'             | An array of ndi.time.clocktype objects that describe the type of clocks available
    % 't0_t1'                   | A cell array of ordered pairs [t0 t1] that indicates the start and stop of the epoch for each
    %                           |   respective epoch_clock{}. The time units of t0_t1{i} match epoch_clock{i}.
    % 'epochset_object'         | The ndi.epochset object that has the epoch
    % 'underlying_epochs'       | An array of the ndi.epoch objects that comprise this epochs.
    % 'underlying_files'        | Special case. An ndi.file.navigator underlying epoch has files instead of an epochset_object.
    %                           |   These are a cell array of file names. These are empty for most epochset objects.

			% note: will need to change underlying_epochs.underlying to underlying_epochs.object in all code

    properties (SetAccess = private)
        epoch_number (1,1) uint64 {mustBeInteger} = 0;
        epoch_id (1,1) string = "" % Unique identifier for the epoch; could be any string 
        epoch_session_id (1,1) string {did.ido.isvalid(epoch_session_id)} = ndi.ido.unique_id % Identifier for the session containing this epoch
        epochprobemap (:,1) {mustBeA(epochprobemap,'ndi.epoch.epochprobemap')} =  ndi.epoch.epochprobemap
        epoch_clock  (:,1) ndi.time.clocktype = ndi.time.clocktype.empty % An array of ndi.time.clocktype objects that describe the types of clocks available
        t0_t1 cell = {} % A cell array of ordered pairs [t0 t1] that indicates the start and stop time of the epoch in each clock
        epochset_object (:,1) {mustBeA(epochset_object,'ndi.epoch.epochset')} = ndi.epoch.epochset()
        underlying_epochs (:,1) {ndi.epoch.mustBeEpochOrEmpty} = [] % An array of the ndi.epoch objects that underlie/comprise this epoch
        underlying_files (:,1) cell = {} % These are a cell array of file names. These are empty for most epochset objects other than ndi.file.navigator objects
    end

    methods
         function obj = epoch(varargin)
             % EPOCH - create an ndi.epoch object
             % 
             % OBJ = EPOCH(...)
             %
             % Create an ndi.epoch() object. The properties must be passed as name/value pairs. One may create
             % an empty epoch providing no inputs; otherwise, one must specify all of the property values.
             % 
             % 'epoch_number'            | The number of the epoch. The number may change as epochs are added and subtracted.
             %                           |   0 has a special meaning. It means that the epoch_number is unknown.
             % 'epoch_id'                | The epoch ID code (will never change once established, though it may be deleted.)
             %                           |   This epoch ID uniquely specifies the epoch.
             % 'epoch_session_id'        | The session ID that contains this epoch
             % 'epochprobemap'           | Any contents information for each epoch, usually of type ndi.epoch.epochprobemap or empty.
             % 'epoch_clock'             | An array of ndi.time.clocktype objects that describe the type of clocks available
             % 't0_t1'                   | A cell array of ordered pairs [t0 t1] that indicates the start and stop of the epoch
             %                           |   for each respective epoch_clock{}. The time units of t0_t1{i} match epoch_clock{i}.
             % 'epochset_object'         | The ndi.epochset object that has the epoch
             % 'underlying_epochs'       | An array of the ndi.epoch objects that comprise this epochs.
             % 'underlying_files'        | A file navigator object's underlying epoch objects is a file list as a cell array. Empty for most types.

                  assert( mod(nargin,2)==0 ,'Arguments must be presented in name/value pairs.');
                  propsSet = {};
                  propsList = properties(obj);

                  try
                      for i=1:2:numel(varargin)
                          obj.set(varargin{i},varargin{i+1});
                          propsSet{end+1} = char(varargin{i});
                      end
                      assert( (nargin==0) || isequal(sort(propsSet(:)),sort(propsList(:))), ...
                          'Either no parameters must be specified or all parameters must be specified');
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
