function [t_out, d_out] = downsampleTimeseries(t_in, d_in, LP)
%DOWNSAMPLETIMESERIES Downsamples a time series matrix after applying a low-pass filter.
%
%   [t_out, d_out] = DOWNSAMPLETIMESERIES(t_in, d_in, LP) downsamples the
%   input time series data d_in, after applying a Chebyshev Type I low-pass
%   filter to prevent aliasing, *if necessary*.
%
%   Inputs:
%       t_in  - A vector representing the time values.  This can be a
%               double vector (with units of seconds) or a MATLAB datetime object.
%               It is assumed samples are equally spaced in time.
%       d_in  - A matrix where each column represents a different channel of data.
%               The number of rows in d_in must match the length of t_in.
%       LP    - The low-pass frequency (in Hz).  Frequencies above this value
%               will be attenuated by the filter *if downsampling is required*.
%
%   Outputs:
%       t_out - The downsampled time vector.
%       d_out - The downsampled and filtered data matrix.  If no downsampling
%               is performed, the output data will be identical to the input data.
%
%   Details:
%       The function first determines the sampling frequency of the input data.
%       If the sampling frequency is greater than twice the specified low-pass
%       frequency (LP), a downsampling operation is performed.  A 4th order
%       Chebyshev Type I filter with 0.8 dB of passband ripple is used as an
%       anti-aliasing filter prior to downsampling. The data is then
%       downsampled to a sampling frequency of 2*LP.  If the original
%       sampling frequency is not greater than 2*LP, the original data is
%       returned *without filtering*.
%
%   Example:
%       % Generate a sample signal with two sine waves.
%       t = 0:0.001:1;  % 1 kHz sampling rate
%       d = sin(2*pi*5*t)' + 0.5*cos(2*pi*50*t)'; % 5 Hz and 50 Hz components
%
%       % Downsample to 20 Hz (LP = 10 Hz)
%       [t_down, d_down] = mlt.downsampleTimeseries(t, d, 10);
%
%       % Plot the original and downsampled signals.
%       figure;
%       subplot(2,1,1);
%       plot(t, d);
%       title('Original Signal');
%       xlabel('Time (s)');
%       ylabel('Amplitude');
%
%       subplot(2,1,2);
%       plot(t_down, d_down);
%       title('Downsampled Signal (LP = 10 Hz)');
%       xlabel('Time (s)');
%       ylabel('Amplitude');
%
%       % Example with no downsampling:
%       [t_no_down, d_no_down] = mlt.downsampleTimeseries(t, d, 600); % LP > fs/2
%       % t_no_down and d_no_down will be the same as t and d.
%
%   See also CHEBY1, FILTFILT, RESAMPLE.

    arguments
        t_in {mustBeVector, mustBeNumericOrDatetime}
        d_in (:,:) double {mustHaveCompatibleDimensions(d_in, t_in)}
        LP (1,1) double {mustBePositive}
    end

    % Determine the sampling frequency.
    if isa(t_in, 'datetime')
        dt = median(diff(t_in));  % Find the median time difference
        fs = 1 / seconds(dt);     % Compute the sampling frequency (handle datetime)
    else
        dt = median(diff(t_in));  % Find the median time difference
        fs = 1 / dt;            % Compute the sampling frequency
    end


    % Check if downsampling is necessary.
    if fs > 2 * LP
        % Design the Chebyshev Type I filter.
        [b, a] = cheby1(4, 0.8, LP / (fs/2), 'low');

        % Apply the filter using filtfilt (zero-phase filtering).
        d_filtered = filtfilt(b, a, d_in);

        % Calculate the new, downsampled, time vector
        if isa(t_in,'datetime')
           t_out = [t_in(1) : seconds(1/(2*LP)) : t_in(end)]';
        else
            t_out = [t_in(1) : 1/(2*LP) : t_in(end)]';
        end

        %Downsample by interpolation.
        d_out = interp1(t_in,d_filtered,t_out);

    else
        % No downsampling or filtering needed.
        d_out = d_in;
        t_out = t_in;
        warning('Sampling frequency is not greater than twice the low-pass frequency. No downsampling or filtering performed.');
    end

end

function mustHaveCompatibleDimensions(d, t)
    % Test for equal number of samples
    if size(d,1) ~= length(t)
       eid = 'Size:notEqual';
       msg = 'The number of rows in d_in must equal length of t_in.';
       throwAsCaller(MException(eid,msg))
    end
end

function mustBeNumericOrDatetime(t)
    if ~isnumeric(t) && ~isdatetime(t)
        eid = 'Type:Invalid';
        msg = 't_in must be a numeric vector or a datetime vector.';
        throwAsCaller(MException(eid, msg));
    end
end