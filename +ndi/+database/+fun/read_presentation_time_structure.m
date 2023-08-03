function [header, presentation_time] = read_presentation_time_structure(filename, N0, N1)
fid = fopen(filename, 'rb','ieee-le');

% Read the header information
header = fgetl(fid); % Read the first line as the header
num_entries = fread(fid, 1, 'uint64');

fseek(fid, 512, 'bof'); % Skip to 512 bytes from the beginning of the file

% Read all entries if N0 and N1 are not provided
if nargin < 2 || isempty(N0)
    N0 = 1;
    N1 = num_entries;
end

% Adjust N1 if it exceeds the number of entries
N1 = min(N1, num_entries);

% Read each entry within the specified range
presentation_time = struct('clocktype', {}, 'stimopen', {}, ...
    'onset', {}, 'offset', {}, 'stimclose', {}, 'stimevents', {});

for i = N0:N1
    presentation_time(i).clocktype = fgetl(fid);
    presentation_time(i).stimopen = fread(fid, 1, 'float64');
    presentation_time(i).onset = fread(fid, 1, 'float64');
    presentation_time(i).offset = fread(fid, 1, 'float64');
    presentation_time(i).stimclose = fread(fid, 1, 'float64');
    
    num_events = fread(fid, 1, 'uint32');
% Read stimevents as a column vector and reshape it to N x 2 matrix
    stimevents_data = fread(fid, [2, num_events], 'float64');
    presentation_time(i).stimevents = stimevents_data';
end
fclose(fid);

num_elements = numel(presentation_time);
presentation_time = reshape(presentation_time, num_elements, 1);
end
