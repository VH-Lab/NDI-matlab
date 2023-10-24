classdef (Abstract) Probe <  handle  %matlab.mixin.Heterogeneous
    properties
        Name
        DeviceType
        ProbeType
        ClassType
        Description
        DigitalIdentifier
        Manufacturer
        Complete
    end
    
    methods
       
        function updateProperty(obj, name, value)
            obj.(name)=value;
        end

        function property = getProperty(obj, name)
            property = obj.(name);
        end

        function checkAndAssign(obj, name, varargin)
            vlt.data.assign(varargin{:});
            if exist(name,'var') == 1
                obj.(name) = eval(name);
            end
        end

        % function complete = checkComplete(obj)
        %     if ~isempty(obj.Name) && ~isempty(obj.DeviceType)
        %         obj.Complete = true;
        %     else
        %         obj.Complete = false;
        %     end
        %     complete = obj.Complete;
        % end

        function s = toTableStruct(obj, probeType, probeIndex)
            s = struct();
            if isempty(obj.Name)
                s.ProbeName = sprintf("Probe%d", probeIndex);
            else
                s.ProbeName = obj.Name;
            end
            s.ProbeType = obj.ProbeType;
            if obj.Complete
                s.Status = 'Complete';
            else
                s.Status = 'Incomplete';
            end
        end
        
        function properties = getProperties(obj)
            properties = struct(...
                'Name', obj.Name, ...
                'DeviceType', obj.DeviceType ...
            );
        end
    end
end
