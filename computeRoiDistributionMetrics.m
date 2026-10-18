function m=computeRoiDistributionMetrics(map,roiMask,options)
% Downstream only. roiMask must ALREADY encode the engine's validity policy.
if nargin<3,options=struct();end;o=dsap_distribution_options(options);
[x,valid,q,z,range]=dsap_distribution_pixels(map,roiMask,o);n=numel(x);
names={'Mean','Median','SD','TrimmedMean_05_95','P05','P10','P25','P50','P75','P90','P95', ...
 'IQR','CV','rIDR','Skewness','KurtosisPearson','HistEntropyBits','HistEntropyNorm', ...
 'GLCMContrast','GLCMCorrelation','GLCMEnergy','GLCMHomogeneity','GLCMEntropyBits','GLCMEntropyNorm', ...
 'LocalEntropyMean','LocalEntropyMedian','LocalEntropyP90'};
m=cell2struct(num2cell(nan(numel(names),1)),names,1);m.NValid=n;m.CVValid=false;m.rIDRValid=false;
m.RobustScaleLower=range(1);m.RobustScaleUpper=range(2);m.GLCMPairCounts=zeros(1,4);m.GLCMDirectionMetrics=nan(4,6);m.LocalEntropyNValid=0;
m.QCFlags=struct('LowValidPixelCount',n<o.LowValidPixelCount,'NonPositiveMean',false, ...
 'NonPositiveMedian',false,'DegenerateIntensityRange',false,'InsufficientGLCMPairs',false, ...
 'InsufficientLocalNeighbors',false,'UndefinedShapeMoments',false,'UndefinedGLCMCorrelation',false, ...
 'NoValidPixels',n==0,'NonfiniteInputExcluded',any(roiMask&~isfinite(map),'all'));
if n==0
 m.QCFlags.NonPositiveMean=true;m.QCFlags.NonPositiveMedian=true;m.QCFlags.InsufficientGLCMPairs=true;
 m.QCFlags.InsufficientLocalNeighbors=true;m.QCFlags.UndefinedShapeMoments=true;m.QCFlags.UndefinedGLCMCorrelation=true;return;
end
m.Mean=mean(x);m.Median=median(x);m.SD=std(x);p=dsap_distribution_percentile(x,[5 10 25 50 75 90 95]);
for k=1:7,m.(names{4+k})=p(k);end
trim=dsap_distribution_percentile(x,[o.TrimLowerPercentile o.TrimUpperPercentile]);m.TrimmedMean_05_95=mean(x(x>=trim(1)&x<=trim(2)));
m.IQR=m.P75-m.P25;m.CVValid=isfinite(m.Mean)&&m.Mean>eps;m.rIDRValid=isfinite(m.P50)&&m.P50>eps;
if m.CVValid,m.CV=m.SD/m.Mean;end
if m.rIDRValid,m.rIDR=(m.P90-m.P10)/m.P50;end
m.QCFlags.NonPositiveMean=~m.CVValid;m.QCFlags.NonPositiveMedian=~m.rIDRValid;
% Population standardized moments, equivalent to skewness(x,1), kurtosis(x,1).
% Pearson kurtosis (normal ~=3), NOT excess; constants are undefined.
scale=max(abs(x));if scale>0,y=x/scale;y=y-mean(y);v=mean(y.^2);else,v=0;end
if v>0,m.Skewness=mean(y.^3)/v^1.5;m.KurtosisPearson=mean(y.^4)/v^2;
else,m.QCFlags.UndefinedShapeMoments=true;end
m.QCFlags.DegenerateIntensityRange=range(1)==range(2);
labels=min(o.HistogramBins-1,floor(z*o.HistogramBins))+1;
counts=accumarray(labels,1,[o.HistogramBins 1]);m.HistEntropyBits=entropy_counts(counts);m.HistEntropyNorm=m.HistEntropyBits/log2(o.HistogramBins);
% Crop only for efficiency; validity mask retains holes and disconnected islands.
[rr,cc]=find(valid);rows=min(rr):max(rr);cols=min(cc):max(cc);valid=valid(rows,cols);q=double(q(rows,cols));
L=o.GLCMGrayLevels;[ii,jj]=ndgrid(1:L,1:L);directions=nan(4,6);
for k=1:4
 offset=o.GLCMOffsets(k,:)*o.GLCMDistancePixels;dr=offset(1);dc=offset(2);
 ar=max(1,1-dr):min(size(q,1),size(q,1)-dr);ac=max(1,1-dc):min(size(q,2),size(q,2)-dc);
 if isempty(ar)||isempty(ac),continue;end
 pair=valid(ar,ac)&valid(ar+dr,ac+dc);count=nnz(pair);m.GLCMPairCounts(k)=count;
 if count<o.MinGLCMPairs,continue;end
 a=q(ar,ac);b=q(ar+dr,ac+dc);a=a(pair);b=b(pair);c=accumarray([a(:) b(:)],1,[L L]);
 % Symmetric GLCM: count both directions, then normalize separately per offset.
 c=c+c';P=c/sum(c,'all');muI=sum(ii.*P,'all');muJ=sum(jj.*P,'all');
 vi=sum((ii-muI).^2.*P,'all');vj=sum((jj-muJ).^2.*P,'all');cor=NaN;
 if vi>0&&vj>0,cor=sum((ii-muI).*(jj-muJ).*P,'all')/sqrt(vi*vj);end
 h=entropy_counts(c(:));directions(k,:)=[sum((ii-jj).^2.*P,'all'),cor,sum(P.^2,'all'),sum(P./(1+abs(ii-jj)),'all'),h,h/log2(L^2)];
end
m.GLCMDirectionMetrics=directions;
gn={'GLCMContrast','GLCMCorrelation','GLCMEnergy','GLCMHomogeneity','GLCMEntropyBits','GLCMEntropyNorm'};
for k=1:6,vv=directions(:,k);vv=vv(isfinite(vv));if ~isempty(vv),m.(gn{k})=mean(vv);end,end
m.QCFlags.InsufficientGLCMPairs=any(m.GLCMPairCounts<o.MinGLCMPairs);
m.QCFlags.UndefinedGLCMCorrelation=any(~isfinite(directions(m.GLCMPairCounts>=o.MinGLCMPairs,2)))||all(m.GLCMPairCounts<o.MinGLCMPairs);
% H=log2(N)-sum(c*log2(c))/N. Count only valid neighbors, including center.
kernel=ones(o.LocalEntropyWindow);N=conv2(double(valid),kernel,'same');sumClogC=zeros(size(q));
for level=1:L
 c=conv2(double(valid&q==level),kernel,'same');nz=c>0;sumClogC(nz)=sumClogC(nz)+c(nz).*log2(c(nz));
end
eligible=valid&N>=o.MinLocalNeighbors;local=log2(N(eligible))-sumClogC(eligible)./N(eligible);local=max(0,local);
m.LocalEntropyNValid=numel(local);m.QCFlags.InsufficientLocalNeighbors=any(valid&~eligible,'all');
if ~isempty(local),m.LocalEntropyMean=mean(local);m.LocalEntropyMedian=median(local);m.LocalEntropyP90=dsap_distribution_percentile(local,90);end
end
function h=entropy_counts(c)
p=c(c>0)/sum(c);h=-sum(p.*log2(p));
end
