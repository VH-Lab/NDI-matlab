classdef Electrode < ndi.database.metadata_app.class.Probe
    properties
        IntrinsicResistance
        IntrinsicResistanceUnit
    end
    
    methods
        function obj = Electrode(varargin)
            obj.ClassType = "Electrode";
            obj.IntrinsicResistanceUnit = 'not selected';
            obj.IntrinsicResistance = '';
        end

        function selected = intrinsicResistanceUnitSelected(obj)
            if strcmp(obj.IntrinsicResistanceUnit, 'not selected')
                selected = 0;
            else
                selected = 1;
            end
        end

        function openminds_obj = makeOpenMindsObj(obj)
            if isempty(obj.Name)
                error('Electrode name is required')
            end
            
            if isempty(obj.DeviceType)
                error('Electrode device type is required')
            end

            if ~obj.digitalIdentifierTypeSelected()
                digitalIdentifier = openminds.core.RRID('identifier', '');
            else
                command = sprintf("openminds.core.%s('identifier', '%s')", digitalIdentifierType, digitalIdentifierStr);
                digitalIdentifier = eval(command);
            end
            devType = openminds.controlledterms.DeviceType('name', obj.DeviceType, 'description', obj.Description);

            if obj.intrinsicResistanceUnitSelected()
                units = openminds.controlledterms.UnitOfMeasurement('name', obj.IntrinsicResistanceUnit); 
                rst = openminds.core.QuantitativeValue('value',  str2double(obj.IntrinsicResistance), 'unit', units);
            else
                units = openminds.controlledterms.UnitOfMeasurement('name', ''); 
                rst = openminds.core.QuantitativeValue('value', str2double(obj.IntrinsicResistance), 'unit', units);
            end
            ror = openminds.core.RORID('identifier', obj.Manufacturer.RORId);
            orgC = openminds.core.Organization('digitalIdentifier', ror, 'fullName', obj.Manufacturer.AffiliationName);
            
            openminds_obj = openminds.ephys.Electrode('name', obj.Name, 'description',obj.Description, 'deviceType', devType, 'digitalIdentifier', digitalIdentifier, 'intrinsicResistance', rst, 'manufacturer', orgC);
        end
    end

       
end

