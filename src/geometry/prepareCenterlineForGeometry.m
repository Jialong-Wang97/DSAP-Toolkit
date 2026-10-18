function prepared=prepareCenterlineForGeometry(centerline,pixelSpacing,opts)
% Nx2 [column x, row y] in px, in caller-declared proximal -> distal order.
% DICOM spacing is [row spacing, column spacing], in mm/px. No sorting occurs.
if nargin<2,pixelSpacing=[];end
if nargin<3,opts=struct();end
opts=vesselGeometryOptions(opts,~isempty(pixelSpacing));
assert(isnumeric(centerline)&&isreal(centerline)&&ismatrix(centerline)&&size(centerline,2)==2&&size(centerline,1)>=2&&all(isfinite(centerline),'all'), ...
 'DSAP:GeometryCenterline','Provide one finite, ordered Nx2 centerline; unordered skeleton pixels are not accepted.');
assert(opts.OrderConfirmed,'DSAP:GeometryOrder','Proximal -> distal order must be confirmed by the caller.');
raw=double(centerline);keep=[true;vecnorm(diff(raw),2,2)>opts.DuplicateTolerance];clean=raw(keep,:);
assert(size(clean,1)>=2,'DSAP:GeometryDegenerate','Centerline has fewer than two distinct points.');
assert(size(unique(clean,'rows'),1)==size(clean,1),'DSAP:GeometryOrder','Nonconsecutive duplicate points: loop or unordered path.');
steps=vecnorm(diff(clean),2,2);
assert(max(steps)<=opts.MaxStepRatio*median(steps),'DSAP:GeometryOrder','Discontinuous point sequence: verify ordering or increase MaxStepRatio explicitly.');
turns=diff(clean);
if size(turns,1)>2
 cosTurn=sum(turns(1:end-1,:).*turns(2:end,:),2)./(steps(1:end-1).*steps(2:end));
 assert(mean(cosTurn<cosd(150))<.15,'DSAP:GeometryOrder','Frequent reversals suggest an unordered point cloud.');
end
scale=[1 1];unit='px';
if ~isempty(pixelSpacing)
 assert(isnumeric(pixelSpacing)&&isreal(pixelSpacing)&&ismember(numel(pixelSpacing),[1 2])&&all(isfinite(pixelSpacing(:)))&&all(pixelSpacing(:)>0), ...
  'DSAP:GeometrySpacing','PixelSpacing must be positive scalar or DICOM [row column] spacing.');
 if isscalar(pixelSpacing),pixelSpacing=[pixelSpacing pixelSpacing];end
 scale=double(pixelSpacing([2 1]));scale=reshape(scale,1,2);unit='mm';
end
active=clean.*scale;s=[0;cumsum(vecnorm(diff(active),2,2))];lengthTotal=s(end);
assert(lengthTotal>eps&&norm(active(end,:)-active(1,:))>max(eps,1e-8*lengthTotal),'DSAP:GeometryDegenerate','Zero-length or closed centerline has no valid vessel chord.');
count=max(5,ceil(lengthTotal/opts.ResampleSpacing)+1);
assert(count<=opts.MaxResampledPoints,'DSAP:GeometrySize','Too many resampled points; increase ResampleSpacing.');
grid=linspace(0,lengthTotal,count)';resampled=interp1(s,active,grid,'pchip');smoothed=resampled;
window=max(3,2*floor(opts.SmoothingStrength/(2*(grid(2)-grid(1))))+1);
window=min(window,count-mod(count+1,2));
if ~strcmp(opts.SmoothingMethod,'none')&&opts.SmoothingStrength>0
 smoothed=smoothdata(resampled,1,opts.SmoothingMethod,window);
 % Preserve the selected anatomical endpoints; distribute correction smoothly.
 u=grid/lengthTotal;smoothed=smoothed+(1-u).*(active(1,:)-smoothed(1,:))+u.*(active(end,:)-smoothed(end,:));
end
assert(all(vecnorm(diff(smoothed),2,2)>eps),'DSAP:GeometryDegenerate','Smoothing collapsed adjacent points.');
prepared=struct('centerlineRaw',raw,'centerlineClean',clean,'centerlineResampled',resampled./scale, ...
 'centerlineSmoothed',smoothed./scale,'ActiveCenterline',smoothed,'ArcLengthGrid',grid, ...
 'Units',unit,'ScaleXY',scale,'PixelSpacing',pixelSpacing,'Options',opts,'RemovedDuplicateCount',sum(~keep), ...
 'ActualResampleSpacing',grid(2)-grid(1),'SmoothingWindowPoints',window, ...
 'OrderEvidence','Caller-declared proximal -> distal; continuity/reversal/duplicate checks; no automatic anatomical ordering.');
end
