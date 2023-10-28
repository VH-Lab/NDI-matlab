classdef Electrode < ndi.database.metadata_app.class.Probe
    properties
        IntrinsicResistance
        IntrinsicResistanceUnit
    end
    
    methods
        function obj = Electrode(varargin)
            obj.ClassType = "Electrode";
            obj.IntrinsicResistanceUnit = {};
        end

        function unit = getUnit(obj)
            if isempty(obj.IntrinsicResistanceUnit)
                unit = '';
            else
                unit = obj.IntrinsicResistanceUnit;
            end
        end

        function openminds_obj = makeOpenMindsObj(obj)
            if isempty(obj.Name)
                error('Electrode name is required')
            end
            
            if isempty(obj.DeviceType)
                error('Electrode device type is required')
            end
                
            if ~isempty(obj.DigitalIdentifier)
                rrid = openminds.core.RRID('identifier', obj.DigitalIdentifier);
            else
                rrid = '';
            end

            if ~isempty(obj.DeviceType) 
                devType = openminds.controlledterms.DeviceType('name', obj.DeviceType, 'description', obj.Description);
            else
                devType = '';
            end

            if (~isempty(obj.IntrinsicResistance)) && (~isempty(obj.IntrinsicResistanceUnit))
                %splite obj.IntrinsicResistance into value and unit by space
                rst = openminds.core.QuantitativeValue('value', obj.IntrinsicResistance, 'unit', obj.IntrinsicResistanceUnit);
            else
                rst = '';
            end
            
            doi = openminds.core.DOI('identifier', 'https://doi.org/10.1016/j.cub.2023.08.095'); %%'https://doi.org/' + DOI
            rrid = openminds.core.RRID('identifier', 'https://scicrunch.org/resolver/RRID:SCR_016109');
            devType = openminds.controlledterms.DeviceType('name', 'ndi probe type', 'description', 'user-defined description?');
            units = openminds.controlledterms.UnitOfMeasurement('name', 'megaohm'); % controlled instance
            rst = openminds.core.QuantitativeValue('value', 5, 'unit', units)
            
            ror = openminds.core.RORID('identifier', 'https://ror.org/03z5xhq25');
            orgC = openminds.core.Organization('digitalIdentifier', ror, 'fullName', 'FHC');

            electrode = openminds.ephys.Electrode('name', 'electrode001', 'description', 'catalogue number', 'deviceType', devType, 'digitalIdentifier', rrid, 'intrinsicResistance', rst, 'manufacturer', orgC);
                    openminds_obj = [];
        end
    end

       
end

