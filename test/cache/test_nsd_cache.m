function test_nsd_cache
% TEST_NSD_CACHE - test the NSD_CACHE object
%
% Adds several entries to NSD_CACHE objects to test the functions.
% 

disp(['Create an NSD_CACHE object that is small enough to test the memory functions.']);

cache = nsd_cache('maxMemory',1024,'replacement_rule','fifo');

