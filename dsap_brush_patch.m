function patch=dsap_brush_patch(patch,xy,radius)
% Same pixel-centre circular brush, limited to each circle's bounding box.
assert(islogical(patch)&&ismatrix(patch)&&isnumeric(xy)&&size(xy,2)==2&& ...
 all(isfinite(xy),'all')&&isscalar(radius)&&isfinite(radius)&&radius>0, ...
 'DSAP:BrushInput','Invalid brush coordinates or radius.');
[h,w]=size(patch);
for k=1:size(xy,1)
 x=xy(k,1);y=xy(k,2);
 cols=max(1,ceil(x-radius)):min(w,floor(x+radius));
 rows=max(1,ceil(y-radius)):min(h,floor(y+radius));
 if isempty(cols)||isempty(rows),continue;end
 disk=(rows'-y).^2+(cols-x).^2<=radius^2;
 patch(rows,cols)=patch(rows,cols)|disk;
end
end
