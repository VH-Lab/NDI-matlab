function write_presentation_time_structure(filename, presentation_time)
fid = fopen(filename, 'wb','ieee-le');

% Write the header information
fprintf(fid, 'presentation_time structure\n');
num_entries = uint64(length(presentation_time));
fwrite(fid, num_entries, 'uint64');
curr = ftell(fid);
data = zeros(1, 512-curr, 'uint8');
fwrite(fid, data, 'uint8');
% fseek(fid, 512, 'cof'); % Skip to 512 bytes from the beginning of the file

% Write each entry
for i = 1:length(presentation_time)
    fprintf(fid, '%s\n', presentation_time(i).clocktype);
%     presentation_time(i).clocktype,
    fwrite(fid, presentation_time(i).stimopen, 'float64');
%     presentation_time(i).stimopen,
    fwrite(fid, presentation_time(i).onset, 'float64');
%     presentation_time(i).onset,
    fwrite(fid, presentation_time(i).offset, 'float64');
%     presentation_time(i).offset,
    fwrite(fid, presentation_time(i).stimclose, 'float64');
%     presentation_time(i).stimclose,
    
    num_events = uint32(size(presentation_time(i).stimevents, 1));
%     size(presentation_time(i).stimevents, 1),
    fwrite(fid, num_events, 'uint32');
% Reshape stimevents into a column vector and then write
    stimevents_data = reshape(presentation_time(i).stimevents', [], 1);
    fwrite(fid, stimevents_data, 'float64');
end

fclose(fid);
end

