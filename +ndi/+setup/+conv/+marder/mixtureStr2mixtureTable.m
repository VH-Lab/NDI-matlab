function t = mixtureString2mixtureTable(str,mixtureStruct)
% MIXTURESTRING2MIXTURETABLE - convert a mixture string to a mixture table
%
% T = MIXTURESTRING2MIXTURETABLE(STR, MIXTURESTRUCT)
%
% Converts a mixture string STR to a table of mixtures.
%
% STR is a string of the form "v1,v2,N*v3", etc. It indicates what
% mixtures, which are fields of the MIXTURESTRUCT, are present here.
%
% MIXTURESTRUCT is a structure with fields equal to the possibly mixture
% type values V. The entries of MIXTURESTRUCT.V are a structure array with the following
% values:
%    ontologyName :   Node name of the compound in an ontology
%            name :   The name of the compound (official name in the ontology)
%           value :   The value of the concentration of the mixture
%    ontologyUnit :   The unit of measure, usually 'OM:MolarVolumeUnit'
%        unitName :   The name of the unit, usually 'Molar'
%
% Example:  
%    str = 'normal_saline,10e-4 ptx';
%    marderFolder = fullfile(ndi.common.PathConstants.RootFolder,'+ndi','+setup','+conv','+marder');
%    mixtureStruct = jsondecode(fileread(fullfile(marderFolder,"marder_mixtures.json")));
%    t = ndi.setup.conv.marder.mixtureString2mixtureTable((str,mixtureStruct)
%    % a table of entries

t = vlt.data.emptytable("ontologyName","string","name","string","value",...
	"double","ontologyUnit","string","unitName","string");

f = fieldnames(mixtureStruct);

tokens = extractTokens(str);
for i=1:numel(tokens),
    coef = tokens{i}{1};
    name = tokens{i}{2};
    index = find(strcmp(name,f));
    assert(~isempty(index),["No name " + name + " found."]);
    v = getfield(mixtureStruct,f{index});
    for j=1:numel(v),
        v(j).value = coef * v(j).value;
        t(end+1,:) = struct2cell(v(j))';
    end;
end

function tokens = extractTokens(text)
  % Splits the text by commas
 % Example usage:
  %text = 'apple,3*banana,pear,3e-3*apple';
  %tokens = extractTokens(text); 
  %disp(tokens)
 parts = strsplit(text, ','); 
  tokens = {};
  
  for i = 1:length(parts)
    part = parts{i};
    % Extracts the numeric coefficient and the string part
    match = regexp(part, '(?<coeff>[\d\.\-\+eE]+)?\*?(?<str>\w+)', 'names'); 
    
    if isempty(match) 
        continue; 
    end
    
    coeff = str2double(match.coeff); 
    if isnan(coeff)
      coeff = 1;  % Default to 1 if no coefficient is found
    end
    
    tokens{end+1} = {coeff, match.str}; 
  end

