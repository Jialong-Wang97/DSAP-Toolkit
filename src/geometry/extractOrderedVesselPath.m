function [centerline,quality]=extractOrderedVesselPath(mask,startPoint,endPoint,pixelSpacing,opts,waypoints)
% Distance-to-boundary cost favors the center of an EXISTING vessel mask.
% Ordered guide points resolve projected overlaps; no dilation or gap filling.
if nargin<4,pixelSpacing=[];end
if nargin<5,opts=struct();end
if nargin<6,waypoints=zeros(0,2);end
opts=vesselGeometryOptions(opts,~isempty(pixelSpacing));
assert(islogical(mask)&&ismatrix(mask)&&any(mask,'all'),'DSAP:GeometryMask','Provide a nonempty logical 2D vessel mask.');
assert(isnumeric(startPoint)&&isnumeric(endPoint)&&numel(startPoint)==2&&numel(endPoint)==2&&all(isfinite([startPoint(:);endPoint(:)])), ...
 'DSAP:GeometryEndpoints','Endpoints must be finite [x y] pairs.');
assert(isnumeric(waypoints)&&isreal(waypoints)&&ismatrix(waypoints)&&size(waypoints,2)==2&&all(isfinite(waypoints),'all'), ...
 'DSAP:GeometryEndpoints','Waypoints must be an ordered Nx2 array.');
requested=[reshape(startPoint,1,2);waypoints;reshape(endPoint,1,2)];
scale=[1 1];
if ~isempty(pixelSpacing)
 assert(isnumeric(pixelSpacing)&&isreal(pixelSpacing)&&ismember(numel(pixelSpacing),[1 2])&&all(isfinite(pixelSpacing(:)))&&all(pixelSpacing(:)>0),'DSAP:GeometrySpacing','Invalid pixel spacing.');
 if isscalar(pixelSpacing),pixelSpacing=[pixelSpacing pixelSpacing];end
 scale=reshape(double(pixelSpacing([2 1])),1,2);
end
skel=bwskel(mask);[sr,sc]=find(skel);skeletonPoints=[sc sr];
assert(~isempty(sr),'DSAP:GeometrySkeleton','No usable skeleton in this vessel mask.');
% Outside tolerance is measured to the mask: a point already inside a wide
% lumen may move farther to its medial skeleton than MaxSnapDistance.
[mr,mc]=find(mask);maskPoints=[mc mr];labels=bwlabel(mask,8);
skeletonLabels=labels(sub2ind(size(mask),sr,sc));snapped=zeros(size(requested));snapDistance=zeros(size(requested,1),1);
for j=1:size(requested,1)
 [maskDistance,closest]=min(vecnorm(maskPoints-requested(j,:),2,2));
 assert(maskDistance<=opts.MaxSnapDistance,'DSAP:GeometrySnap','Point is outside this vessel mask; select the correct source or move the point.');
 label=labels(mr(closest),mc(closest));eligible=find(skeletonLabels==label);
 [snapDistance(j),index]=min(vecnorm(skeletonPoints(eligible,:)-requested(j,:),2,2));snapped(j,:)=skeletonPoints(eligible(index),:);
end
assert(size(unique(snapped,'rows'),1)==size(snapped,1),'DSAP:GeometryEndpoints','Two selected points snapped to the same vessel location.');
selectedLabels=labels(sub2ind(size(mask),snapped(:,2),snapped(:,1)));
assert(all(selectedLabels==selectedLabels(1)),'DSAP:GeometryDisconnected','Selected points are in disconnected vessel components. No artificial bridge was added.');
component=labels==selectedLabels(1);clear labels maskPoints;
radius=bwdist(~padarray(component,[1 1],false,'both'));radius=double(radius(2:end-1,2:end-1));
pixels=component;if strcmp(opts.PathMethod,'skeleton'),pixels=skel&component;end
[rows,cols]=find(pixels);count=numel(rows);
assert(count>=2&&count<=opts.MaxPathNodes,'DSAP:GeometrySkeleton','Vessel component exceeds the graph limit; select a smaller mask or use skeleton mode.');
ids=zeros(size(mask),'uint32');ids(pixels)=uint32(1:count);
selectedNodes=double(ids(sub2ind(size(mask),snapped(:,2),snapped(:,1))));
cost=ones(count,1);
if strcmp(opts.PathMethod,'center-weighted')
 [~,nearestMedial]=bwdist(skel&component);localRadius=radius(nearestMedial(pixels));
 cost=1+opts.PathCenterWeight*max(0,localRadius./max(radius(pixels),1)-1).^2;
end
from=zeros(count*4,1);to=from;weights=from;edgeCount=0;directions=[0 1;1 -1;1 0;1 1];
for j=1:4
 dr=directions(j,1);dc=directions(j,2);nr=rows+dr;nc=cols+dc;
 inside=nr>=1&nr<=size(mask,1)&nc>=1&nc<=size(mask,2);source=find(inside);target=double(ids(sub2ind(size(mask),nr(inside),nc(inside))));
 keep=target>0;source=source(keep);target=target(keep);
 if strcmp(opts.PathMethod,'skeleton')&&dr~=0&&dc~=0
  orthogonal=pixels(sub2ind(size(mask),rows(source)+dr,cols(source)))|pixels(sub2ind(size(mask),rows(source),cols(source)+dc));
  source=source(~orthogonal);target=target(~orthogonal);
 end
 n=numel(source);range=edgeCount+(1:n);from(range)=source;to(range)=target;
 weights(range)=hypot(dc*scale(1),dr*scale(2))*(cost(source)+cost(target))/2;edgeCount=edgeCount+n;
end
network=graph(from(1:edgeCount),to(1:edgeCount),weights(1:edgeCount),count);
route=[];weightedCost=0;
for j=1:numel(selectedNodes)-1
 [part,partCost]=shortestpath(network,selectedNodes(j),selectedNodes(j+1));
 assert(numel(part)>=2,'DSAP:GeometryDisconnected','No connected route between the selected points.');
 if j>1,part=part(2:end);end
 route=[route part];weightedCost=weightedCost+partCost; %#ok<AGROW>
end
assert(numel(unique(route))==numel(route),'DSAP:GeometryPathLoop','Waypoints produce a loop/backtracking route. Move guide points to the vessel in order.');
centerline=[cols(route) rows(route)];pathLength=sum(vecnorm(diff(centerline).*scale,2,2));
branchPoints=bwmorph(skel&component,'branchpoints');branchDistance=bwdist(branchPoints);
pathPixels=sub2ind(size(mask),centerline(:,2),centerline(:,1));junction=any(branchDistance(pathPixels)<=2);
quality=struct('SnappedStart',snapped(1,:),'SnappedEnd',snapped(end,:), ...
 'StartSnapDistance_px',snapDistance(1),'EndSnapDistance_px',snapDistance(end),'PathLength',pathLength, ...
 'RequestedPoints',requested,'SnappedPoints',snapped,'Waypoints',waypoints, ...
 'ContainsBranchJunction',junction,'Warning','','WeightedPathCost',weightedCost, ...
 'MinimumRadius_px',min(radius(pathPixels)),'MedianRadius_px',median(radius(pathPixels)), ...
 'PathInsideMask',all(mask(pathPixels)),'CenterWeight',opts.PathCenterWeight, ...
 'Method',['existing-vessel-mask-' opts.PathMethod '-ordered-waypoints']);
if junction,quality.Warning='Path passes vessel junctions/overlaps; inspect the overlay and add guide points if it follows the wrong branch.';end
end
