function metrics=computeCurvatureMetrics(centerline,opts)
% Derivatives are with respect to cumulative smoothed arc length, not pixels.
if nargin<2,opts=struct();end
opts=vesselGeometryOptions(opts,false);p=double(centerline);s=[0;cumsum(vecnorm(diff(p),2,2))];
assert(size(p,1)>=5&&all(diff(s)>0),'DSAP:GeometryCurvature','Curvature requires at least five distinct ordered samples.');
dx=gradient(p(:,1),s);dy=gradient(p(:,2),s);ddx=gradient(dx,s);ddy=gradient(dy,s);
signed=(dx.*ddy-dy.*ddx)./max((dx.^2+dy.^2).^(3/2),eps);
% Second derivatives at endpoints have one-sided bias; extend the nearest
% valid interior estimate. This explicit policy also avoids artificial peaks.
signed(1:2)=signed(3);signed(end-1:end)=signed(end-2);kappa=abs(signed);
threshold=max(opts.InflectionAbsoluteTolerance,opts.InflectionRelativeTolerance*max(kappa));
usable=find(abs(signed)>threshold);inflections=[];
if ~isempty(usable)
 signs=sign(signed(usable));changes=[1;find(diff(signs)~=0)+1;numel(usable)+1];lastSign=0;lastIndex=0;
 for j=1:numel(changes)-1
  region=usable(changes(j):changes(j+1)-1);
  if s(region(end))-s(region(1))<opts.MinInflectionSpacing,continue;end
  currentSign=sign(signed(region(1)));
  if lastSign~=0&&currentSign~=lastSign
   between=lastIndex:region(1);[~,best]=min(abs(signed(between)));inflections(end+1,1)=between(best); %#ok<AGROW>
  end
  lastSign=currentSign;lastIndex=region(end);
 end
end
[maximum,index]=max(kappa);total=trapz(s,kappa);
metrics=struct('MeanCurvature',total/s(end),'MedianCurvature',median(kappa), ...
 'MaxCurvature',maximum,'RMSCurvature',sqrt(trapz(s,kappa.^2)/s(end)), ...
 'P90Curvature',percentile(kappa,.90),'P95Curvature',percentile(kappa,.95), ...
 'TotalAbsoluteCurvature',total,'CurvatureProfile',kappa,'SignedCurvatureProfile',signed, ...
 'ArcLengthPosition',s,'MaxCurvatureIndex',index,'MaxCurvaturePosition',s(index), ...
 'InflectionCount',numel(inflections),'InflectionIndices',inflections, ...
 'InflectionThreshold',threshold,'EndpointPolicy','nearest-interior-two-samples');
end
function value=percentile(data,fraction)
ordered=sort(data);position=1+(numel(data)-1)*fraction;lo=floor(position);hi=ceil(position);
value=ordered(lo)+(position-lo)*(ordered(hi)-ordered(lo));
end
