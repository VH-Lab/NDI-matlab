function [ standard_name ] = name_convert_to_standard( type, name )
%   STANDARD_NAME = NAME_CONVERT_TO_STANDARD(TYPE,NAME)
%       name_convert_to_standard() takes two inputs the standard type of 
%       the channel and the local channel name and convert the local 
%       channel name to the standard name 

typeList = strsplit(type,'_');

temp1 = typeList{1};        %%get the instrumental name

temp1 = temp1(1);


if ~strcmp('diagnostic', typeList{1}),
	temp2 = typeList{2};        %%get the instrumental name
	temp2 = temp2(1);
else,
	temp2 = '';
end;

nameList = strsplit(name,'-');   


if ~isnan(sscanf(nameList{end},'%f'))
    
    standard_name = strcat(temp1,temp2,num2str(sscanf(nameList{end},'%f')));

else 
    standard_name = strcat(temp1,temp2);
    nl = nameList{end};
    for i = 1:length(nl)
        s = nl(i);
        num=str2double(s);
        
        if ~isnan(num)
            standard_name = strcat(standard_name,s);
        end
        
    end
end




end

