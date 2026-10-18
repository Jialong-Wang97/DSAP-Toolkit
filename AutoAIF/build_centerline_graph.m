function network=build_centerline_graph(mask,spacing)
% Reuse an existing vessel mask; skeletonize without bridging disconnected vessels.
% Coordinates are [column row]; spacing is DICOM [row column] mm.
assert(numel(spacing)==2&&all(isfinite(spacing))&&all(spacing>0),'AutoAIF:Spacing','Calibrated PixelSpacing is required.');
skel=bwskel(logical(mask));[y,x]=find(skel);ids=zeros(size(mask));ids(skel)=1:numel(x);
s=[];t=[];w=[];
for d=[0 1;1 -1;1 0;1 1]'
 yy=y+d(1);xx=x+d(2);valid=yy>=1&yy<=size(mask,1)&xx>=1&xx<=size(mask,2);
 a=find(valid);b=ids(sub2ind(size(mask),yy(valid),xx(valid)));keep=b>0;a=a(keep);b=b(keep);
 if all(d~=0)
  corner=skel(sub2ind(size(mask),y(a)+d(1),x(a)))|skel(sub2ind(size(mask),y(a),x(a)+d(2)));
  a=a(~corner);b=b(~corner);
 end
 s=[s;a];t=[t;b];w=[w;repmat(hypot(d(1)*spacing(1),d(2)*spacing(2)),numel(a),1)]; %#ok<AGROW>
end
network=struct('Graph',graph(s,t,w,numel(x)),'XY',[x y],'Origin','existing-mask-skeleton');
end
