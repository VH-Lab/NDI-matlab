classdef nsd_variable_struct < nsd_variable_file
    %UNTITLED Summary of this class goes here
    %   Detailed explanation goes here

    properties
    end

    methods
        function obj = nsd_variable_struct(parent, name, description, history)
            % NSD_VARIABLE_STRUCT - Create an NSD_VARIABLE_STRUCT object
            %
            %  OBJ = NSD_VARIABLE_FILE(PARENT, NAME, DESCRIPTION, HISTORY)
            %
            %  Creates a variable directory to be linked to an NSD_EXPERIMENT
            %  VARIABLE tree.
            %
            %  PARENT must be an NSD_DBLEAF_BRANCH object, usually the variable list
            %  associated with an NSD_EXPERIMENT or its children.
            %  NAME        - the name for the variable; may be any string
            %  DESCRIPTION - a human-readable string description of the variable's contents and purpose
            %  HISTORY     - a character string description of the variable's history (what function created it,
            %                 parameters, etc)
            %
            %  NSD_VARIABLE_STRUCT differs from its super parent class NSD_DBLEAF_BRANCH in that
            %  a) no NSD_DBLEAF objects may be added to it
            %  b) it has methods FILENAME and DIRNAME that return a full path filename or
            %     full path directory name where the user may store files
            %

		    inputs = {};

            if nargin > 0
                inputs{1} = parent;
            end

            if nargin > 1
                inputs{2} = name;
            end

            if nargin > 2
                inputs{3} = description;
            end

            if nargin > 3
                inputs{4} = history;
            end


            obj = obj@nsd_variable_file(inputs{:});

        end % nsd_variable_struct

        function writeStructArray(self, struct)
            %check if anything is written
            saveStructArray(self.filename(), struct, 1);
        end

        function loadedStruct = returnStructArray(self)
            %check if there is anything to read
            loadedStruct = loadStructArray(self.filename());
        end

        function addToStructArray(self, field, value)
            loadedStruct = returnStructArray(self);
            if isa(value, 'char')
                value = str2num(value);
            end
            %Add to struct
            eval(['loadedStruct.' field ' = value;']);
            %Write it to file
            writeStructArray(self, loadedStruct);
        end
    end

end
