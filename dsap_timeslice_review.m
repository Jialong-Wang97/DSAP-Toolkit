function [imported,cancelled]=dsap_timeslice_review(entries,reference,provenance,select_role)
    if nargin<4,select_role=@listdlg;end
    imported=struct();cancelled=true;transposed=true;
    % Historical manual-review default. Dimensions alone do not prove orientation;
    % automatic migration must pass dsap_verify_timeslice_orientation first.
    first=squeeze(niftiread(entries(1).maskFile));
    if isequal(size(first.'),size(reference)),transposed=true;else,transposed=false;end
    masks=dsap_timeslice_load_masks(entries,size(reference),transposed);
    visible=[entries.visible];show_hidden=false;
    fig=figure('Name','确认 TIMESlice 当前 ROI','NumberTitle','off','Color','w');
    cleanup=onCleanup(@() dsap_safe_delete(fig)); %#ok<NASGU>
    while isgraphics(fig)
        selected=find(visible|show_hidden);
        ax=findobj(fig,'Type','axes');delete(ax);ax=axes(fig,'Position',[.03 .20 .94 .74]);
        imshow(reference,[],'Parent',ax);hold(ax,'on');colors=lines(numel(entries));
        for k=selected
            visboundaries(ax,masks{k},'Color',colors(k,:));
            [y,x]=find(masks{k});if ~isempty(x),text(ax,mean(x),mean(y),num2str(k),'Color',colors(k,:),'BackgroundColor','k');end
        end
        title(ax,sprintf('当前保存版本；转置=%d；隐藏 ROI=%d 个（默认不采用）',transposed,nnz(~visible)));
        action=dsap_wait_for_review_choice(fig,'逐一确认掩膜位置；不按颜色/时间合并。', ...
            {'对齐，选择角色','roles';'切换转置','transpose';'显示/隐藏隐藏ROI','hidden';'取消','cancel'});
        if strcmp(action,'transpose')
            candidate=cellfun(@transpose,masks,'UniformOutput',false);
            if ~isequal(size(candidate{1}),size(reference)),warndlg('转置后的尺寸与影像不符。');continue;end
            masks=candidate;transposed=~transposed;
        elseif strcmp(action,'hidden'),show_hidden=~show_hidden;
        elseif strcmp(action,'roles')
            if numel(selected)<2,warndlg('至少需要两个 ROI：一个 AIF 和一个组织区域。');continue;end
            labels=arrayfun(@(k) sprintf('%d | %s | %s | %d px | visible=%d',k, ...
                entries(k).name,entries(k).roiId,nnz(masks{k}),entries(k).visible),selected,'UniformOutput',false);
            [ai,ok]=select_role('Name','选择已绘制的 AIF','ListString',labels,'SelectionMode','single','ListSize',[650 300]);
            if ~ok||~isgraphics(fig),continue;end
            a=selected(ai);candidates=setdiff(selected,a,'stable');
            [ti,ok]=select_role('Name','选择组织 ROI（可多选）','ListString',labels(selected~=a), ...
                'SelectionMode','multiple','ListSize',[650 300]);
            if ~ok||isempty(ti)||~isgraphics(fig),continue;end
            tissue=candidates(ti);
            if nnz(masks{a})<3||any(cellfun(@nnz,masks(tissue))<3),warndlg('AIF 和组织 ROI 均需至少 3 个像素。');continue;end
            imported=struct('AIFMask',masks{a},'Masks',{masks(tissue)}, ...
                'Names',{arrayfun(@(k) sprintf('TIMESlice_%d_%s',k,entries(k).name),tissue,'UniformOutput',false)'}, ...
                'AIFEntry',entries(a),'Entries',entries(tissue),'Transposed',transposed, ...
                'Provenance',provenance,'Confirmed',true);
            cancelled=false;return;
        else,return;
        end
    end
end
