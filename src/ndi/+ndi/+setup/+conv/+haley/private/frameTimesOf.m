function t = frameTimesOf(R, i)
%FRAMETIMESOF The measured frame times of row I of a recordingList table.
%   T = frameTimesOf(R, I) returns a column of seconds from the start of the
%   file, one per frame (decision #87), or [] when the video was not decoded
%   ('ReadVideos' false), the row is not a video, or R has no such column.
t = [];
if ~ismember('frame_times', R.Properties.VariableNames), return; end
x = R.frame_times(i);
while iscell(x) && ~isempty(x)
    x = x{1};
end
if isnumeric(x)
    t = double(x(:));
end
end
