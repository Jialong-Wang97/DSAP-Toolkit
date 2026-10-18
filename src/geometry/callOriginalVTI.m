function result=callOriginalVTI(centerline,directory)
% Original numerical path, is_show=0. No formula reimplementation or rotation.
result=struct('Value',NaN,'SDTheta',NaN,'MeanDM',NaN,'NumInflectionPoints',NaN, ...
 'NumCriticalPoints',NaN,'ArcLength',NaN,'ChordLength',NaN,'Valid',false,'Warning','');
if nargin<2||isempty(directory)
 root=fileparts(fileparts(fileparts(mfilename('fullpath'))));directory=fullfile(root,'third_party','vessel_tortuosity_vti');
end
files={'vessel_tortousity_index.m','arc_length.m','sd_theta.m','mean_distance_measure.m','num_critical_pts.m'};
if ~all(cellfun(@(x) isfile(fullfile(directory,x)),files))
 result.Warning='Third-party VTI module unavailable; see THIRD_PARTY.md. VTI is not computed.';return;
end
[~,attributes]=fileattrib(directory);directory=attributes.Name;
if any(abs(diff(centerline(:,1)))<1e-12*max(1,max(abs(centerline(:,1)))))
 result.Warning='Original VTI has undefined dy/dx on vertical steps; other geometry metrics remain valid.';return;
end
oldPath=path;cleanup=onCleanup(@() path(oldPath));addpath(directory,'-begin');
try
 % Verify resolution instead of calling a same-named external implementation.
 for j=1:numel(files)
  [~,name]=fileparts(files{j});assert(strcmp(which(name),fullfile(directory,files{j})),'DSAP:VTIResolution','VTI dependency path collision.');
 end
 [result.Value,result.SDTheta,result.MeanDM,result.NumInflectionPoints, ...
  result.NumCriticalPoints,result.ArcLength,result.ChordLength]=vessel_tortousity_index(centerline(:,1)',centerline(:,2)',0);
 result.Valid=all(isfinite([result.Value result.SDTheta result.MeanDM result.ArcLength result.ChordLength]));
 if ~result.Valid,result.Value=NaN;result.Warning='Original VTI returned nonfinite values; other geometry metrics remain valid.';end
catch e
 result.Value=NaN;result.Warning=['Third-party VTI failed: ' e.message];result.Exception=getReport(e,'extended','hyperlinks','off');
end
end
