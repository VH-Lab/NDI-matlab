function mapped_channels = mappings(channels, mapping_name)
% MAPPINGS - Return channel mapping vector
%
%   MAPPED_CHANNELS = ndi.gui.app.pyraview.mappings(CHANNELS, MAPPING_NAME)
%
%   Inputs:
%       CHANNELS     - Vector of channel indices (1:N)
%       MAPPING_NAME - 'raw' or 'PlexonSV'
%
%   Outputs:
%       MAPPED_CHANNELS - Reordered channel indices
%

    arguments
        channels (1,:) double
        mapping_name (1,:) char {mustBeMember(mapping_name, {'raw', 'PlexonSV'})}
    end

    switch mapping_name
        case 'raw'
            mapped_channels = channels;
        case 'PlexonSV'
            if ~isequal(channels, 1:32)
                error('PlexonSV mapping requires exactly channels 1:32.');
            end
            mapped_channels = [25:32, 16:-1:1, 17:24];
    end
end
