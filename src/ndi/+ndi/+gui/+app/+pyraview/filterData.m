function [filtered_data, filterStruct] = filterData(data, sr, type)
    % FILTERDATA - Filter data for pyraview applications
    %
    %   [FILTERED_DATA, FILTERSTRUCT] = ndi.gui.app.pyraview.filterData(DATA, SR, TYPE)
    %
    %   Inputs:
    %       DATA - numeric matrix (Samples x Channels)
    %       SR   - Sampling rate (Hz)
    %       TYPE - 'low' or 'high'
    %
    %   Outputs:
    %       FILTERED_DATA - Filtered data
    %       FILTERSTRUCT  - Structure describing the filter parameters
    %

    arguments
        data (:,:) double
        sr (1,1) double
        type (1,:) char {mustBeMember(type, {'low', 'high'})}
    end

    % Define filter parameters
    filterStruct.type = type;
    filterStruct.label = type;
    filterStruct.algorithm = 'chebyshev_1';
    filterStruct.parameters = struct('sampleFrequency', sr, ...
        'order', 4, ...
        'filterFrequency', 300, ...
        'passBandRipple', 0.8, ...
        'stopbandAttentuation', NaN);

    % Check if Signal Processing Toolbox is available
    if exist('cheby1', 'file') || exist('cheby1', 'builtin')
        nyquist = 0.5 * sr;
        cutoff = 300 / nyquist;

        if cutoff >= 1
            warning('Filter cutoff frequency is >= Nyquist frequency. Adjusting to 0.99*Nyquist for stability.');
            cutoff = 0.99;
        end

        % cheby1(n, Rp, Wp, ftype)
        if strcmp(type, 'high')
             [b, a] = cheby1(4, 0.8, cutoff, 'high');
        else
             [b, a] = cheby1(4, 0.8, cutoff, 'low');
        end

        filtered_data = filter(b, a, data);
    else
        warning('Signal Processing Toolbox not found. Returning unfiltered data.');
        filtered_data = data;
    end
end
