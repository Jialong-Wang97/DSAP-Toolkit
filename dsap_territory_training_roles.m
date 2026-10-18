function roles=dsap_territory_training_roles(entries,config)
% User-declared semantics for training only; never rewrite source annotations.
if nargin<2
 config=jsondecode(fileread(fullfile(fileparts(mfilename('fullpath')),'vascular_segmentation','timeslice_annotation_roles.json')));
end
n=numel(entries);role=repmat("Unknown",n,1);eligible=false(n,1);issues=strings(n,1);
for k=1:n
 e=entries(k);color=upper(strtrim(e.color));
 if strcmpi(color,config.MCA),role(k)="MCA";
 elseif strcmpi(color,config.AIF),role(k)="AIF";
 elseif strcmpi(color,config.PossibleVein),role(k)="PossibleVein";end
 if ~e.visible,issues(k)="HiddenROI";end
 if e.baseline&&role(k)~="AIF",issues(k)=issues(k)+";BaselineRoleConflict";end
 if ~e.baseline&&role(k)=="AIF",issues(k)=issues(k)+";AIFBaselineConflict";end
 inStack=strcmp({entries.stackId},e.stackId)&[entries.visible];
 if nnz(inStack)>config.expected_max_visible_rois_per_stack,issues(k)=issues(k)+";MoreThanThreeVisibleROIs";end
 if nnz(inStack&strcmpi({entries.color},config.MCA))>1,issues(k)=issues(k)+";MultipleMCAObjects";end
 eligible(k)=role(k)=="MCA"&&e.visible&&~e.baseline&&strlength(issues(k))==0;
end
roles=table(string({entries.roiId})',role,eligible,issues, ...
 'VariableNames',{'ROIId','Role','EligibleForExtentReview','ReviewIssues'});
end
