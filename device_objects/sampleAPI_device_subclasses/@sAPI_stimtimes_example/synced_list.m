function [posteriorMatrix] = synced_list(device,priorMatrix)
%% this function returns a matrix network representing the synced status for all
%% device

checkVector = zeros(size(priorMatrix,1),1);

%%check if the new added device is syneced with other device
for i = 1:size(checkVector)
    %%NOTE:need to be able to retrieve the device for specific entrance
    if synced(device,deviceOf(priorMatrix(i,1))) == 1,
        checkVector(i) = 1;
    end
end

posteriorMatrix = [priorMatrix checkVector];

checkVector = [checkVector' 1];

posteriorMatrix = [posteriorMatrix;checkVector];








end 
