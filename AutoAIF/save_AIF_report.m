function files=save_AIF_report(folder,AIF_report)
% Separate sidecar report; the existing ROI snapshot/save schema is unchanged.
if ~isfolder(folder),mkdir(folder);end
files=struct('MAT',fullfile(folder,'AIF_report.mat'),'CSV',fullfile(folder,'AIF_report.csv'));
save(files.MAT,'AIF_report','-v7');writetable(AIF_report.Ranking,files.CSV);
end
