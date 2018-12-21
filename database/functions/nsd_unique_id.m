function id = nsd_unique_id
% NSD_UNIQUE_ID - Generate a unique ID number for NSD projects
%
% ID = NSD_UNIQUE_ID
%
% Generates a unique ID character array based on the current time and a random
% number. It is a hexidecimal representation of the Matlab function NOW and
% RAND.
%
% ID = [NUM2HEX(NOW) '_' NUM2HEX(RAND)]
%
% See also: NUM2HEX, NOW, RAND
%

id = [num2hex(now) '_' num2hex(rand)];
