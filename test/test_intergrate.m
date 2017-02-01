%% the general intergrated test function for all sorts of device type
clear;
clc;



%% the test for intan device
dev = 'example_experiments/exp1_eg';
display = sprintf('run the example test for intan device: %s',dev);
disp(display);
test_intan_flat('example_experiments/exp1_eg');




%% the test for image processing device
clear;
dev = 'example_experiments/exp1_eg';
display = sprintf('run the example test for image processing device: %s',dev);
disp(display);
test_sAPI_image('example_experiments/exp1_eg');





