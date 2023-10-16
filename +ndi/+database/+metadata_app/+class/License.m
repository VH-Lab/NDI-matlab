classdef License < handle
%AuthorData A utility class for License.
    
    properties 
        FullName = 'Creative Commons Attribution 4.0 International';
        LegalCode = 'https://creativecommons.org/licenses/by/4.0/legalcode';
        ShortName = 'CC BY 4.0'
    end

    methods
        function obj = License(ShortName)
            if nargin > 0
                % Define the predefined license types and their details
                licenseTypes = {
                    'Creative Commons Attribution 4.0 International', 'https://creativecommons.org/licenses/by/4.0/legalcode', 'CC BY 4.0';
                    'Creative Commons Attribution-ShareAlike 4.0 International', 'https://creativecommons.org/licenses/by-sa/4.0/legalcode', 'CC BY-SA 4.0';
                    'Creative Commons Attribution-NonCommercial 4.0 International', 'https://creativecommons.org/licenses/by-nc/4.0/legalcode', 'CC BY-NC 4.0';
                    'Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International', 'https://creativecommons.org/licenses/by-nc-sa/4.0/legalcode', 'CC BY-NC-SA 4.0';
                    'Creative Commons Attribution-NoDerivatives 4.0 International', 'https://creativecommons.org/licenses/by-nd/4.0/legalcode', 'CC BY-ND 4.0';
                    'Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International', 'https://creativecommons.org/licenses/by-nc-nd/4.0/legalcode', 'CC BY-NC-ND 4.0';
                };
                
                % Find the corresponding license details based on fullName
                index = find(strcmp(ShortName, licenseTypes(:, 3)), 1);
                
                % Check if a valid fullName was provided
                if ~isempty(index)
                    obj.FullName = licenseTypes{index, 1};
                    obj.LegalCode = licenseTypes{index, 2};
                    obj.ShortName = ShortName;
                else
                    error('Invalid license type.');
                end
            end
        end

        function FullName = getFullName(obj)
            FullName = obj.FullName;
        end

        function LegalCode = getLegalCode(obj)
            LegalCode = obj.LegalCode;
        end

        function ShortName = getShortName(obj)
            ShortName = obj.ShortName;
        end
    end
end