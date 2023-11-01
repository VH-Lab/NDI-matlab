​
function openMindsInstance = instanceFactory(dataStruct, openMindsType)
​
    conversionFunctionMap = getConcreteConversionMap(openMindsType);
​
    openMindsInstance = feval( openMindsType );
    dataFields = fieldnames(dataStruct);
​
    for i = 1:numel(dataFields)
        [fieldName, propName] = deal( dataFields{i} );
        propName(1) = lower(propName(1));
​
        value = dataStruct.(fieldName);
        if isempty(value); continue; end % Skip conversion for empty values
​
        if isfield( conversionFunctionMap, propName )
               
            conversionFcn = conversionFunctionMap.(propName);
​
            if numel(value) > 1 % array conversion
                value = arrayfun(@(s) conversionFcn(s), value);
            else
                value = conversionFcn(value);
            end
        else
            % Insert value directly
        end
​
        try
            openMindsInstance.(propName) = value;
        catch ME
            warning(ME.message)
        end
    end
end
