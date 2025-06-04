% File: +ndi/+test/+objects/HandleTestObject.m
classdef HandleTestObject < handle 
    properties
        Name = ''
        Timestamp
    end
    methods
        function obj = HandleTestObject(name)
            if nargin > 0
                obj.Name = name;
            else
                obj.Name = ['DefaultName_' char(randi([65,90],1,5))]; % Ensure some uniqueness for default
            end
            obj.Timestamp = now; 
        end

        function tf = isequalcontent(obj1, obj2) 
            if ~isa(obj1, 'ndi.test.objects.HandleTestObject') || ~isa(obj2, 'ndi.test.objects.HandleTestObject')
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
            obj1 = obj1(:);
            obj2 = obj2(:);
            tf = true;
            for i = 1:numel(obj1)
                if ~strcmp(obj1(i).Name, obj2(i).Name) 
                    tf = false;
                    return;
                end
            end
        end
    end
end