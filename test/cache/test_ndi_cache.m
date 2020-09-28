function test_ndi_cache
% TEST_NDI_CACHE - test the NDI_CACHE object
%
% Adds several entries to NDI.CACHE objects to test the functions.
% 

disp(['Create an NDI.CACHE object that is small enough to test the memory functions.']);

cache = ndi.cache('maxMemory',1024,'replacement_rule','fifo'); % 1K 

disp(['About to add elements to the cache']);

key = 'mykey';

for i=1:5,
	if i==1,
		priority = 1;
	else,
		priority = 0;
	end;
	cache.add(key,['type' int2str(i)],rand(25,1),priority);
end

disp(['About to read elements from the cache..']);

for i=1:5,
	t = cache.lookup(key,['type' int2str(i)]),
end;

disp(['About to add an element that will cause the cache to eject its lowest priority entry, which should be entry ''type 2'' ']);

cache.add(key,['type6'],rand(25,1));

disp(['Types left in the cache:']);

{cache.table.type},

