function dsap_export_signal_quality(output_dir,reference,aif,limit_mask,limits,features,vessels,tissue,model)
    dsap_task_control('check');
    manual=isfield(model,'ManualPartition')&&model.ManualPartition;
    [rgb,labels,palette]=dsap_signal_quality_rgb(reference,features,limit_mask,vessels,aif,tissue);
    imwrite(rgb,fullfile(output_dir,'signal_quality_overlay.png'));
    imwrite(labels,fullfile(output_dir,'signal_quality_labels.png'));
    imwrite(ind2rgb(double(labels)+1,palette),fullfile(output_dir,'signal_quality_classification.png'));
    imwrite(tissue,fullfile(output_dir,'valid_enhancing_tissue_mask.png'));
    imwrite(features.UncertainMask,fullfile(output_dir,'uncertain_signal_mask.png'));
    imwrite(features.NoDetectableEnhancementMask,fullfile(output_dir,'no_detectable_enhancement_mask.png'));
    imwrite(features.ProjectionForegroundMask,fullfile(output_dir,'mip_foreground_mask.png'));
    imwrite(features.ProjectionBackgroundMask,fullfile(output_dir,'mip_background_mask.png'));
    names={'OutsideLimits';'NoDetectableEnhancement';'UncertainSignal'; ...
        'ValidEnhancingTissue';'LargeVessel';'AIF';'NumericallyUnreliable';'MIPDarkBackground'};
    descriptions={'上下限以外';'未检出增强，可能是背景或未显影组织';'弱信号或不稳定信号'; ...
        '参与参数和TIC统计的有效显影组织';'大血管排除';'手动AIF';'反卷积不可靠';'按最大增强投影明暗边界排除的背景'};
    if manual
        names{8}='OutsideManualPartition';descriptions{8}='手动外轮廓以外，不是自动判定背景';
        descriptions{4}='灌注参数有效像素；TIC 范围另见分区导出';
    end
    counts=arrayfun(@(k) nnz(labels==k),(0:7)');
    coverage=100*counts/max(nnz(limit_mask),1); coverage(1)=NaN;
    table_data=table((0:7)',names,descriptions,counts,coverage, ...
        'VariableNames',{'Label','Class','Description','Pixels','PercentWithinLimits'});
    writetable(table_data,fullfile(output_dir,'signal_quality_summary.csv'));
    save(fullfile(output_dir,'signal_quality_results.mat'),'labels','palette','features','model','limits','-v7');
    fig=figure('Visible','off','Color','w','Position',[80 80 1500 1050]);
    cleanup=onCleanup(@() dsap_safe_delete(fig));
    layout=tiledlayout(fig,2,3,'Padding','compact','TileSpacing','compact');
    ax=nexttile(layout); imshow(reference,[],'Parent',ax); title(ax,'原始最大增强投影（未按全脑轮廓裁剪）');
    hold(ax,'on'); yline(ax,limits.UpperRow,'c--'); yline(ax,limits.LowerRow,'c--');
    ax=nexttile(layout); imshow(rgb,'Parent',ax); title(ax,'绿：统计组织；红：大血管；青：AIF');
    ax=nexttile(layout); imshow(ind2rgb(double(labels)+1,palette),'Parent',ax);
    title(ax,{'黄：弱/不稳定；紫：计算不可靠','深灰：投影暗背景；浅灰：前景内未检出增强'});
    ax=nexttile(layout); imshow(reference,[],'Parent',ax);hold(ax,'on');
    visboundaries(ax,features.ProjectionForegroundMask,'Color',[1 0.85 0.05],'LineWidth',1.2);
    title(ax,sprintf('黄色边界：明亮前景外缘（阈值 %.3f）',model.SpatialBoundary.AppliedThreshold));
    if manual,title(ax,'黄色边界：人工确认的外轮廓，不按明暗阈值裁剪');end
    ax=nexttile(layout); retained=reference; retained(~tissue)=0; imshow(retained,[],'Parent',ax);
    title(ax,sprintf('有效显影组织：%d 像素（%.1f%%）',nnz(tissue),100*nnz(tissue)/max(nnz(limit_mask),1)));
    ax=nexttile(layout); imshow(reference,[],'Parent',ax); hold(ax,'on');
    uncertain=(labels==2 | labels==6); red=cat(3,ones(size(reference)),0.8*ones(size(reference)),zeros(size(reference)));
    h=imshow(red,'Parent',ax); h.AlphaData=0.5*single(uncertain); title(ax,'需重点检查：弱信号及计算不可靠区域');
    if contains(limits.Method,'unbounded')
        heading='全视野识别预览：旧结果没有上下限记录；不是全脑分割';
    else
        heading='上下限内的逐像素信号识别：不是解剖学全脑分割';
    end
    if manual,heading='人工分区内的质量参考：弱信号不缩小 ROI；分区和 TIC 范围见 partition_review.png';end
    sgtitle(layout,heading,'FontWeight','bold');
    dsap_task_control('check');
    exportgraphics(fig,fullfile(output_dir,'signal_quality_review.png'),'Resolution',130);
    clear cleanup;
    dsap_task_control('check');
    comparison=figure('Visible','off','Color','w','Position',[50 50 1200 780]);
    cleanup=onCleanup(@() dsap_safe_delete(comparison));
    panels=tiledlayout(comparison,1,2,'Padding','compact','TileSpacing','compact');
    ax=nexttile(panels); imshow(reference,[],'Parent',ax); axis(ax,'image');
    title(ax,'原始最大增强投影');
    ax=nexttile(panels); imshow(rgb,'Parent',ax); axis(ax,'image');
    title(ax,{'绿色：统计组织；红色：大血管；青色：AIF', ...
        '黄色：弱/不稳定；深灰：投影背景；紫色：计算不可靠'});
    sgtitle(panels,heading,'FontWeight','bold');
    exportgraphics(comparison,fullfile(output_dir,'signal_quality_comparison.png'),'Resolution',120);
    clear cleanup;
    dsap_task_control('check');
    boundary=figure('Visible','off','Color','w','Position',[50 50 1300 760]);
    cleanup=onCleanup(@() dsap_safe_delete(boundary));
    panels=tiledlayout(boundary,1,2,'Padding','compact','TileSpacing','compact');
    ax=nexttile(panels); imshow(reference,[],'Parent',ax);title(ax,'原始最大增强投影');
    ax=nexttile(panels); imshow(reference,[],'Parent',ax);hold(ax,'on');
    visboundaries(ax,features.ProjectionForegroundMask,'Color',[1 0.85 0.05],'LineWidth',1.2);
    title(ax,'黄色线：仅保留主体边界；独立区域已排除');
    if manual,title(ax,'黄色线：人工确认的外轮廓；不是自动显影边缘');end
    sgtitle(panels,heading,'FontWeight','bold');
    exportgraphics(boundary,fullfile(output_dir,'mip_boundary_comparison.png'),'Resolution',120);
    clear cleanup;
end
