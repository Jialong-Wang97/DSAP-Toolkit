function result=run_synthetic_example(outputDir)
% Partial portability workflow only; deliberately not a perfusion surrogate.
root=fileparts(fileparts(mfilename('fullpath')));
if nargin<1,outputDir=fullfile(root,'outputs','synthetic_example');end
addpath(fullfile(root,'src','geometry'));
example=make_synthetic_example(outputDir);
info=dicominfo(example.DICOM);pixels=dicomread(info);
assert(double(info.NumberOfFrames)==40&&size(pixels,4)==40,'Synthetic DICOM load failed.');
geometry=computeVesselGeometry(example.Centerline,[1 1],struct('UseVTI',false));
assert(geometry.Valid,'Original geometry module rejected synthetic centerline.');
metrics=table(geometry.Length_mm,geometry.ChordLength_mm,geometry.DistanceMetric, ...
 'VariableNames',{'Length_mm','ChordLength_mm','DistanceMetric'});
writetable(metrics,fullfile(outputDir,'geometry_metrics.csv'));
save(fullfile(outputDir,'synthetic_geometry.mat'),'geometry');
fig=figure('Visible','off');guard=onCleanup(@() delete(fig));
plot(example.Centerline(:,1),example.Centerline(:,2));axis equal;title('Synthetic centerline (not clinical data)');
exportgraphics(fig,fullfile(outputDir,'synthetic_centerline.png'));
result=struct('Example',example,'Geometry',geometry,'PerfusionCompleted',false);
fprintf('Synthetic DICOM loaded; geometry CSV/MAT/PNG exported. Perfusion NOT run.\n');
end
