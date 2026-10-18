function data=dsap_roi_suggestion_data(sequence)
% Read already baseline-subtracted, polarity-resolved enhancement; no preprocessing.
if isstruct(sequence),data=sequence;return;end
assert(isnumeric(sequence)&&isreal(sequence)&&ndims(sequence)==3&&size(sequence,1)>=3, ...
 'DSAP:SuggestionInput','建议需要至少三帧已准备好的增强序列。');
shape=[size(sequence,2) size(sequence,3)];stride=max(1,ceil(max(shape)/192));
rows=1:stride:shape(1);columns=1:stride:shape(2);
traces=double(reshape(sequence(:,rows,columns),size(sequence,1),[]));
valid=all(isfinite(traces),1)&all(traces>=0,1);traces(:,~valid)=0;
curve=mean(traces,2);[peak,ttp]=max(traces,[],1);
noise=std(traces(1:min(3,size(traces,1)),:),0,1);
positive=peak(peak>0);floorNoise=eps;
if ~isempty(positive),floorNoise=max(eps,.01*median(positive));end
snr=peak./max(noise,floorNoise);rise=max(diff(traces,1,1),[],1);
crossing=traces>=max(.2*peak,3*noise);[arrived,arrival]=max(crossing,[],1);arrival(~arrived)=size(traces,1)+1;
earlyStrong=false(size(peak));
if ~isempty(positive),earlyStrong=peak>=prctile(positive,70)&ttp<=ceil(2*size(traces,1)/3)&snr>=3;end
effectiveCurve=curve;if nnz(earlyStrong)>=3,effectiveCurve=mean(traces(:,earlyStrong),2);end
data=struct('Shape',shape,'Stride',stride,'Rows',rows,'Columns',columns, ...
 'Traces',traces,'Curve',curve,'EffectiveCurve',effectiveCurve,'Peak',reshape(peak,numel(rows),numel(columns)), ...
 'TTP',reshape(ttp,numel(rows),numel(columns)), ...
 'SNR',reshape(snr,numel(rows),numel(columns)), ...
 'Rise',reshape(rise,numel(rows),numel(columns)),'Arrival',reshape(arrival,numel(rows),numel(columns)),'FiniteFraction',mean(valid), ...
 'FrameCount',size(sequence,1),'SampledShape',[numel(rows) numel(columns)]);
end
