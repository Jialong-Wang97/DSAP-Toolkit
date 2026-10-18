function [scores,detail]=calculate_AIF_score(metrics)
% Cohort z scores; unavailable/nonvarying features are dropped and weights renormalized.
names={'MaxSlope','PeakIntensity','FWHM','ArrivalTime','AUC'};weights=[.30 .25 .20 .15 .10];signs=[1 1 -1 -1 1];
values=nan(numel(metrics),5);valid=true(numel(metrics),1);
for i=1:numel(metrics)
 if isfield(metrics,'Valid'),valid(i)=metrics(i).Valid;end
 for j=1:5,if isfield(metrics,names{j}),values(i,j)=metrics(i).(names{j})*signs(j);end,end
end
z=nan(size(values));
for j=1:5
 keep=isfinite(values(:,j))&valid;v=values(keep,j);
 if numel(v)>1&&std(v)>eps,z(keep,j)=(v-mean(v))/std(v);end
end
scores=-inf(numel(metrics),1);effective=zeros(size(values));
for i=find(valid)'
 keep=isfinite(z(i,:));w=weights.*keep;
 if sum(w)>0,w=w/sum(w);scores(i)=sum(w(keep).*z(i,keep));else,scores(i)=0;end
 effective(i,:)=w;
end
detail=struct('Features',{names},'Z',z,'EffectiveWeights',effective,'RawValues',values,'Interpretation','Relative z score, not probability');
end
