classdef epochprobemap
    properties
    end % properties
    methods
        function obj = epochprobemap()
            % ndi.epoch.epochprobemap - Create a new ndi.epoch.epochprobemap object
            %
            % MYNDI_EPOCHPROBEMAP = ndi.epoch.epochprobemap()
            %
            % Creates a new ndi.epoch.epochprobemap object. This is an abstract
            % base class so it has no inputs.
            %
        end % creator

        function s = serialize(ndi_epochprobemap_obj)
            % SERIALIZE - Turn the ndi.epoch.epochprobemap object into a string
            %
            % S = SERIALIZE(NDI_EPOCHPROBEMAP_OBJ)
            %
            % Create a character array representation of an ndi.epoch.epochprobemap object
            %
            s = ''; % abstract class returns nothing
        end % serialize()

    end  % methods
    methods (Static)
        function st = decode(s)
            % DECODE - decode table information for an ndi.epoch.epochprobemap object from a serialized string
            %
            % ST = DECODE(S)
            %
            % Return a structure ST that contains decoded information to
            % build an ndi.epoch.epochprobemap object from a string
            %
            st = vlt.data.emptystruct('name','reference','type','devicestring','subjectstring');
            l = numel(find(s==sprintf('\n')));
            for i=2:l
                st=cat(1,st,vlt.data.tabstr2struct(vlt.string.line_n(s,i),fieldnames(st)));
            end
        end % decode()
    end
end
