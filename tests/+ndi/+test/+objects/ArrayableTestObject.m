% File: +ndi/+test/+objects/ArrayableTestObject.m
classdef ArrayableTestObject
    properties
        ID = []
        Value = NaN
    end
    methods
        function obj = ArrayableTestObject(id, value)
            if nargin == 0 % Handle default constructor for scalar object
                % Properties already have defaults (ID=[], Value=NaN)
                return;
            end

            % Handle array construction
            num = numel(id);
            if num == 0 % Input id is empty, create an empty object of this class
                obj = ndi.test.objects.ArrayableTestObject.empty(0,1); % Standard way to make typed empty
                return;
            end

            % Preallocate object array by creating the last element first via default constructor
            obj(num) = ndi.test.objects.ArrayableTestObject(); 
            for i = 1:num
                obj(i).ID = id(i);
                if nargin > 1
                    if isscalar(value) % Scalar expansion for value
                        obj(i).Value = value;
                    elseif numel(value) == num
                        obj(i).Value = value(i);
                    else
                        error('Value dimensions must match ID dimensions or be scalar.');
                    end
                else
                    obj(i).Value = NaN; % Default if only ID is given
                end
            end
        end

        function tf = isequal(obj1, obj2)
            if ~isa(obj1, 'ndi.test.objects.ArrayableTestObject') || ~isa(obj2, 'ndi.test.objects.ArrayableTestObject')
                tf = false;
                return;
            end
            if numel(obj1) ~= numel(obj2)
                tf = false;
                return;
            end
            if isempty(obj1) && isempty(obj2)
                tf = true;
                return;
            end
            if isempty(obj1) || isempty(obj2) 
                tf = false;
                return;
            end
            
            obj1 = obj1(:); % Ensure column vector for consistent iteration
            obj2 = obj2(:);

            tf = true;
            for i = 1:numel(obj1)
                % Check if both IDs are empty (e.g. from default constructor)
                id1_empty = isempty(obj1(i).ID);
                id2_empty = isempty(obj2(i).ID);
                
                if id1_empty && id2_empty % Both IDs are empty
                    % IDs are equal (both empty)
                elseif ~isequal(obj1(i).ID, obj2(i).ID) % IDs are not equal (and not both empty)
                    tf = false;
                    return;
                end
                
                % Check if both Values are NaN (e.g. from default constructor)
                val1_nan = isnan(obj1(i).Value);
                val2_nan = isnan(obj2(i).Value);

                if val1_nan && val2_nan % Both Values are NaN
                    % Values are equal (both NaN)
                elseif ~isequaln(obj1(i).Value, obj2(i).Value) % Values are not equal (and not both NaN)
                    tf = false;
                    return;
                end
            end
        end
    end
end