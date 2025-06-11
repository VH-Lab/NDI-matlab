classdef UIElement < ndi.util.StructSerializable & matlab.mixin.Heterogeneous
    % UIELEMENT A base class for describing a generic UI element.

    properties (constant)
        NotMatlabUIProps = {'UUid','IsContainer','creatorFcn','ParentTag','ParentUuid'};
        CallBackTypes = {'ButtonDownFcn','ValueChangedFcn','ValueChangingFcn'};
    end

    properties
        ParentTag (1,:) char = ''
        Visible (1,:) char {mustBeMember(Visible,{'on','off'})} = 'on'
        Tag (1,:) char = ''
        UserData
        ParentUuid (1,:) char = ''
    end

    properties (protected)
        Uuid (1,:) char = ''
    end

    properties (Dependent)
        IsContainer (1,1) logical
        creatorFcn (1,:) char
    end 

    methods
        function value = get.IsContainer(obj)
            % For the base UIElement class, IsContainer is always false.
            % Container subclasses will override this method.
            value = logical(isa(obj,'ndi.gui.component.internal.uie.mixin.UIContainer'));
        end
        
        function value = get.creatorFcn(obj)
            % Get the full class name of the current object instance
            fullClassName = class(obj);
            
            if strcmp(fullClassName, 'ndi.gui.component.internal.uie.UIElement')
                value = 'none';
            else
                parts = strsplit(fullClassName, '.');
                value = lower(parts{end});
            end
        end

        function h = createComponent(obj, app)
            % Create the MATLAB UI component for this object
            if isa(obj,'ndi.gui.component.internal.uie.UIFigure')
                % no parent
                obj.ParentTag = '';
                obj.ParentUuid = '';
                parentObj = NaN;
                argList = {};
            else
                parentObj = findall('tag',obj.parentTagFull());
                argList = {parentObj};
            end
            propList = setdiff(properties(obj),obj.NotMatlabUIProps);
            for i=1:numel(propList)
                % check for callback functions here
                if any(strcmp(CallBackTypes,'propList'))
                    % register the call back function
                end

                propValue = getfield(obj,propList{i});
                if ~isempty(propValue)
                    argList{end+1}=propList{i};
                    argList{end+1}=propValue;
                end
            end
            creatorFuncName = obj.creatorFcn();
            h = feval(creatorFuncName,argList{:});
        end

        function pt = parentTagFull(obj)
            pt = [obj.ParentTag '_' obj.Uuid];
        end

    end

    methods (Static, Sealed, Access = protected)
        function default_object = getDefaultScalarElement
            error('UIElement:NoDefaultObject', 'You cannot create a default UIElement object.');
        end
    end
end