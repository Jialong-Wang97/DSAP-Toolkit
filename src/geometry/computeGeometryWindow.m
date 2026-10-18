function geometry=computeGeometryWindow(centerline,clotPoint,distance_mm,pixelSpacing,opts)
% Proximal ordered arc-length window ending at nearest clotPoint sample.
% This does not detect a clot. A calibrated spacing and chosen clot point are required.
if nargin<5,opts=struct();end
assert(~isempty(pixelSpacing),'DSAP:GeometryWindow','A mm window requires calibrated PixelSpacing.');
assert(isscalar(distance_mm)&&isfinite(distance_mm)&&distance_mm>0&&numel(clotPoint)==2&&all(isfinite(clotPoint(:))), ...
 'DSAP:GeometryWindow','Provide a finite clot point and positive distance in mm.');
p=prepareCenterlineForGeometry(centerline,pixelSpacing,opts);active=p.centerlineResampled.*p.ScaleXY;
[~,clotIndex]=min(vecnorm(active-reshape(clotPoint,1,2).*p.ScaleXY,2,2));s=[0;cumsum(vecnorm(diff(active),2,2))];
last=s(clotIndex);first=max(0,last-distance_mm);assert(last>first,'DSAP:GeometryWindow','No proximal vessel length before clot point.');
grid=[first;s(s>first&s<last);last];window=interp1(s,active,grid,'pchip')./p.ScaleXY;
geometry=computeVesselGeometry(window,pixelSpacing,opts);geometry.Window=struct('RequestedLength_mm',distance_mm, ...
 'AvailableLength_mm',last-first,'TruncatedAtProximalEndpoint',last<distance_mm,'ClotSampleIndex',clotIndex, ...
 'Definition','Proximal raw-resampled arc-length window; then standard preparation/smoothing.');
end
