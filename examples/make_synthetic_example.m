function example=make_synthetic_example(outputDir)
% Entirely generated phantom; no patient image, header, mask or fitted data.
root=fileparts(fileparts(mfilename('fullpath')));
if nargin<1,outputDir=fullfile(root,'outputs','synthetic_example');end
if ~isfolder(outputDir),mkdir(outputDir);end
[x,y]=meshgrid(1:128);t=(0:39)'*.25;
head=((x-64)/51).^2+((y-64)/57).^2<1;
vessel=abs(x-(64+12*sin(y/25)))<2 & head;
tissue=exp(-((x-70).^2+(y-70).^2)/900).*head;
pixels=zeros(128,128,1,numel(t),'uint16');
for k=1:numel(t)
 arterial=max(t(k)-1,0)^3*exp(-max(t(k)-1,0)/.65);
 parenchymal=max(t(k)-2,0)^3*exp(-max(t(k)-2,0)/1.1);
 pixels(:,:,1,k)=uint16(3000-700*arterial*vessel-120*parenchymal*tissue);
end
file=fullfile(outputDir,'SYNTHETIC_DSA.dcm');
metadata=struct('PatientName','SYNTHETIC^PHANTOM','PatientID','SYNTHETIC-NOT-A-PATIENT', ...
 'StudyDescription','Generated software workflow phantom, not clinical evidence', ...
 'SeriesDescription','DSA-PI synthetic example','Modality','OT','FrameTime',250, ...
 'PixelSpacing',[1;1],'PhotometricInterpretation','MONOCHROME2');
dicomwrite(pixels,file,metadata,'CreateMode','Create');
row=(12:116)';centerline=[64+12*sin(row/25),row];
writematrix(centerline,fullfile(outputDir,'synthetic_centerline.csv'));
example=struct('DICOM',file,'Centerline',centerline,'OutputDirectory',outputDir);
end
