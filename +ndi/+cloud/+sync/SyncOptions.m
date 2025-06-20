classdef SyncOptions < matlab.mixin.SetGet
% SyncOptions  Options class for controlling sync behavior
%
%   This class defines a set of configurable options used when performing
%   dataset synchronization tasks, i.e document synchronization.
%
%   This class is meant to be used in argument blocks of various sync
%   functions in order to provide a reusable set of sync options.
%
%   Available options:
%     SyncFiles (logical) - If true, files will be synced (default: false).
%     Verbose (logical) - If true, verbose output is printed (default: true).
%     DryRun (logical) - If true, actions are simulated but not performed (default: false).

    properties
        SyncFiles (1,1) logical = false  % Whether to sync file portion (binary data) of documents
        Verbose (1,1) logical = true    % Whether to print verbose output
        DryRun (1,1) logical = false    % Simulate actions without executing
    end

    methods
        function obj = SyncOptions(options)
            % SyncOptions Construct a new SyncOptions object
            %
            %   obj = SyncOptions() creates a SyncOptions object with default values.
            %
            %   obj = SyncOptions(options) initializes properties from the given struct.
            %   Each field in the struct must correspond to a property name.
            arguments
                options (1,1) struct = struct
            end
            obj.set(options)
        end

        function nvPairs = toCell(obj)
            % toCell Convert properties to name-value pairs
            %
            %   nvPairs = obj.toCell() returns a 1-by-2N cell array containing
            %   the property names and values of the object, suitable for use
            %   as name-value pair arguments in other functions.
            %
            %   Example:
            %     args = opts.toCell();
            %     someFunction(args{:});
            %
            propNames = properties(obj);
            propValues = obj.get(propNames);
            nvPairs = cell(1, numel(propNames)*2);
            [nvPairs(:)] = [propNames, propValues']';
        end
    end
end
