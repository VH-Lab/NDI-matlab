function s=NSD_experiment(reference)
% NSD - Create a new NSD experiment object
%
% S=NSD(REFERENCE) creates a new NSD object. The experiment has
% a unique reference REFERENCE. This class is an abstract class and
% typically an end user will open a specific subclass.
%
% NSD objects can access 0 or more NSD_devices.
%
%  

NSD_struct = struct('reference',reference,'devices',[]);

s = class(NSD_struct,'NSD_experiment');

