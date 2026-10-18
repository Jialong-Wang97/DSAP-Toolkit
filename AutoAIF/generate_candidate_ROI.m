function candidates=generate_candidate_ROI(centerline,mask,spacing,fraction)
% One transverse thin elliptical ROI per 1 mm of physical centerline.
% Conservative inscribed radius works with anisotropic pixels; mask is never dilated.
if nargin<4,fraction=.65;end
assert(fraction>=.5&&fraction<=.8,'AutoAIF:Radius','Radius fraction must be 0.5-0.8.');
candidates=struct('ID',{},'Mask',{},'XY',{},'CenterlineXY',{},'VesselDiameter_mm',{},'Radius_mm',{},'NormalXY',{},'Vessel',{});
if size(centerline,1)<2,return;end
scale=reshape(spacing([2 1]),1,2);s=[0;cumsum(vecnorm(diff(centerline).*scale,2,2))];
p=interp1(s,centerline,(0:1:s(end))');
distance=bwdist(~padarray(logical(mask),[1 1],false));distance=distance(2:end-1,2:end-1)*min(spacing);
for k=1:size(p,1)
 tangent=(p(min(k+1,end),:)-p(max(k-1,1),:)).*scale;tangent=tangent/max(norm(tangent),eps);normal=[-tangent(2) tangent(1)];
 vesselRadius=interp2(distance,p(k,1),p(k,2),'linear',0);r=fraction*vesselRadius;
 if r<=0,continue;end
 xr=max(1,floor(p(k,1)-r/scale(1))):min(size(mask,2),ceil(p(k,1)+r/scale(1)));
 yr=max(1,floor(p(k,2)-r/scale(2))):min(size(mask,1),ceil(p(k,2)+r/scale(2)));
 [x,y]=meshgrid(xr,yr);dx=(x-p(k,1))*scale(1);dy=(y-p(k,2))*scale(2);
 along=dx*tangent(1)+dy*tangent(2);across=dx*normal(1)+dy*normal(2);
 roi=false(size(mask));roi(yr,xr)=(across/r).^2+(along/max(.35*r,.5*min(spacing))).^2<=1;
 roi=roi&mask;if nnz(roi)<3,continue;end
 candidates(end+1)=struct('ID',k,'Mask',roi,'XY',[x(roi(yr,xr)) y(roi(yr,xr))], ...
 'CenterlineXY',p(k,:),'VesselDiameter_mm',2*vesselRadius,'Radius_mm',r,'NormalXY',normal,'Vessel','ICA candidate'); %#ok<AGROW>
end
end
