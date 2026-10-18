function report=select_best_AIF(sequence,mask,network,spacing,time,fitFunction)
% Independent Auto-AIF entry. No perfusion calculation or manual ROI mutation.
if nargin<6,fitFunction=[];end
[line,anatomy]=find_ICA_segment(mask,network,spacing);
report=struct('Version',1,'Available',false,'Reason',anatomy.Reason,'Anatomy',anatomy, ...
 'ICA_candidate_centerline',line,'PixelSpacing',spacing,'Time',time(:),'Candidates',[],'Ranking',table(),'SelectedIndex',[]);
if ~anatomy.Available,return;end
candidates=generate_candidate_ROI(line,mask,spacing);
for k=1:numel(candidates)
 [candidates(k).TDC,candidates(k).Metrics]=extract_TDC(sequence,candidates(k).Mask,time,fitFunction);
end
if isempty(candidates),report.Reason='No intravascular ROI with at least three pixels.';return;end
[scores,report.Scoring]=calculate_AIF_score([candidates.Metrics]);
for k=1:numel(candidates),candidates(k).Score=scores(k);end
[~,order]=sort(scores,'descend');report.Candidates=candidates;
report.Ranking=table((1:numel(order))',order(:),[candidates(order).ID]',scores(order),'VariableNames',{'Rank','CandidateIndex','ROIID','Score'});
report.Ranking.Vessel=string({candidates(order).Vessel})';
centers=vertcat(candidates(order).CenterlineXY);report.Ranking.CenterX_px=centers(:,1);report.Ranking.CenterY_px=centers(:,2);
report.Ranking.VesselDiameter_mm=[candidates(order).VesselDiameter_mm]';
metrics=[candidates(order).Metrics];names={'ArrivalTime','PeakIntensity','MaxSlope','TimeToPeak','FWHM','AUC','R2'};
for k=1:numel(names),report.Ranking.(names{k})=[metrics.(names{k})]';end
if ~isfinite(scores(order(1))),report.Reason='All candidate TDCs failed quality checks.';return;end
report.Available=true;report.SelectedIndex=order(1);report.Selected=candidates(order(1));report.Selection='Automatic';
end
