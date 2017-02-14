function s=sampleAPI(reference)
% SAMPLEAPI - Create a new SAMPLEAPI experiment object
%
% S=SAMPLEAPI(REFERENCE) creates a new sampleAPI object. The experiment has
% a unique reference REFERENCE. This class is an abstract class and
% typically an end user will open a specific subclass.
%
% SAMPLEAPI objects can access 0 or more sampleAPI_devices.
%
%  

sampleAPI_struct = struct('reference',reference,'devices');

s = class(sampleAPI_struct,'sampleAPI');

