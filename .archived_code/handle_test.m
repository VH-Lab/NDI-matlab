sapi = NSD_device;
sapi.NSD_device_cons('1','2','3');

dap = NSD_multifunctionDAQ;
dap.NSD_multifunctionDAQ_cons('1','2','3','4');
dap2.exp = '11';
disp(['the corresponding exp in image and image2:']);
disp(['the exp of dap is:',dap.exp]);
disp(['the exp of dap2 is:',dap2.exp]);

image = NSD_image;
image.NSD_image_cons('1','2','3','4');
image2 = image;
image2.exp = '11';
disp(['the corresponding exp in image and image2:']);
disp(['the exp of image is:',image.exp]);
disp(['the exp of image2 is:',image2.exp]);
